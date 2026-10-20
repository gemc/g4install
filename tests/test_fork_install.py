"""Offline installer checks using real modulefiles and mocked Git/CMake/Make.

Run with: python3 -m unittest discover -s tests -v
Requires zsh and Environment Modules' modulecmd on PATH.
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
MODULECMD = shutil.which("modulecmd")
ZSH = shutil.which("zsh")
URL = "ssh://git@github.com:7999/hello/hello-dev.git"
MOCK_TOOL = '''#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys

tool = Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ["TEST_LOG"], "a") as log:
    log.write(json.dumps([tool, args]) + "\\n")
if os.environ.get("TEST_FAIL") == tool or (
    os.environ.get("TEST_FAIL") == "install" and tool == "make" and args == ["install"]
):
    sys.exit(1)
if tool == "git":
    Path(args[-1]).mkdir(parents=True)
elif tool == "cmake":
    prefix = next(arg.split("=", 1)[1] for arg in args if arg.startswith("-DCMAKE_INSTALL_PREFIX="))
    Path("mock-prefix").write_text(prefix)
elif tool == "make" and args == ["install"]:
    prefix = Path(Path("mock-prefix").read_text())
    (prefix / "bin").mkdir()
    (prefix / "lib").mkdir()
'''
INSTALL_HARNESS = '''
readlink() {
    if [[ "$1" == -f && "$2" == "$TEST_INSTALLER" ]]; then
        print -r -- "$TEST_ROOT/install/install_geant4"
    else
        command readlink "$@"
    fi
}
module() { eval "$("$TEST_MODULECMD" zsh "$@")"; }
source "$TEST_INSTALLER" "$@"
'''
MODULE_HARNESS = '''
module() { eval "$("$TEST_MODULECMD" zsh "$@")"; }
module load sim_system
module load "$1" || exit 1
print -r -- "PREFIX=$G4INSTALL"
print -r -- "LIB=$G4LIB"
print -r -- "VERSION=$G4_VERSION"
print -r -- "PATH=$PATH"
module test "$1" || exit 1
module switch "$1" geant4/11.4.3 || exit 1
print -r -- "SWITCH=$G4INSTALL"
module unload geant4/11.4.3 || exit 1
[[ -z ${G4INSTALL+x} ]] || exit 1
'''


@unittest.skipUnless(MODULECMD and ZSH, "zsh and Environment Modules modulecmd are required")
class ForkInstallTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="g4-fork-test-")
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name).resolve()
        self.modules = self.root / "modules"
        # Point at repository-owned code; no installed or copied source is edited.
        for source in (REPO / "modules").rglob("*"):
            target = self.modules / source.relative_to(REPO / "modules")
            if source.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.symlink_to(source)
        install = self.root / "install"
        install.mkdir()
        (install / "functions.zsh").symlink_to(REPO / "install/functions.zsh")
        self.platform = self.root / "test-platform"
        for directory in ("clhep/2.4.7.2/include/CLHEP", "clhep/2.4.7.2/lib",
                          "xercesc/3.3.0/include/xercesc", "xercesc/3.3.0/lib"):
            (self.platform / directory).mkdir(parents=True)
        mock_bin = self.root / "mock-bin"
        mock_bin.mkdir()
        helper = mock_bin / "mock-tool"
        helper.write_text(MOCK_TOOL)
        helper.chmod(0o755)
        for tool in ("git", "cmake", "make", "qmake6"):
            (mock_bin / tool).symlink_to(helper)
        self.log = self.root / "commands.jsonl"
        self.env = os.environ.copy()
        for key in list(self.env):
            if key in ("LOADEDMODULES", "_LMFILES_") or key.startswith("__MODULES_"):
                self.env.pop(key)
        self.env.update(PATH=f"{mock_bin}:{self.env['PATH']}", MODULEPATH=str(self.modules),
                        OSRELEASE="test-platform", TERM="dumb", TEST_ROOT=str(self.root),
                        TEST_INSTALLER=str(REPO / "install/install_geant4"),
                        TEST_MODULECMD=MODULECMD, TEST_LOG=str(self.log), MODULES_AUTO_HANDLING="1")
        self.env.pop("TEST_FAIL", None)

    def install(self, *args, fail=None):
        env = self.env.copy()
        if fail:
            env["TEST_FAIL"] = fail
        return subprocess.run([ZSH, "-f", "-c", INSTALL_HARNESS, "installer-test", *args],
                              env=env, capture_output=True, text=True)

    def calls(self, tool):
        if not self.log.exists():
            return []
        return [args for name, args in map(json.loads, self.log.read_text().splitlines()) if name == tool]

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_default_branch_and_module_lifecycle(self):
        self.assert_success(self.install(URL, "hello-dev"))
        prefix = self.platform / "geant4/hello-dev"
        clone = self.calls("git")[0]
        self.assertEqual(clone[-2:], [URL, str(prefix / "source")])
        self.assertNotIn("--branch", clone)
        self.assertFalse((prefix / "source").exists())
        result = subprocess.run([ZSH, "-f", "-c", MODULE_HARNESS, "module-test", "geant4/hello-dev"],
                                env=self.env, capture_output=True, text=True)
        self.assert_success(result)
        self.assertIn(f"PREFIX={prefix}\n", result.stdout)
        self.assertIn(f"LIB={prefix}/lib\n", result.stdout)
        self.assertIn("VERSION=hello-dev\n", result.stdout)
        self.assertIn(f"PATH={prefix}/bin:", result.stdout)
        self.assertIn(f"SWITCH={self.platform}/geant4/11.4.3\n", result.stdout)

    def test_explicit_ref_and_special_prefix(self):
        prefix = self.root / 'custom path $literal [literal] "quote" \\backslash'
        self.assert_success(self.install(URL, "custom", "--ref", "dev", "--prefix", str(prefix)))
        clone = self.calls("git")[0]
        self.assertEqual(clone[clone.index("--branch") + 1], "dev")
        self.assertIn(f"-DCMAKE_INSTALL_PREFIX={prefix}", self.calls("cmake")[0])
        result = subprocess.run([ZSH, "-f", "-c", MODULE_HARNESS, "module-test", "geant4/custom"],
                                env=self.env, capture_output=True, text=True)
        self.assert_success(result)
        self.assertIn(f"PREFIX={prefix}\n", result.stdout)

    def test_official_version_and_dev(self):
        self.assert_success(self.install("11.4.3"))
        clone = self.calls("git")[0]
        self.assertEqual(clone[clone.index("--branch") + 1], "v11.4.3")
        self.assertEqual(clone[-2], "https://github.com/Geant4/geant4.git")
        self.assert_success(self.install("dev"))
        self.assertNotIn("--branch", self.calls("git")[-1])

    def test_repository_url_formats(self):
        for index, url in enumerate(("https://example.invalid/geant4.git",
                                     "git@example.invalid:team/geant4.git", "file:///unused/geant4.git")):
            with self.subTest(url=url):
                self.assert_success(self.install(url, f"url-{index}"))
                self.assertEqual(self.calls("git")[-1][-2], url)

    def test_invalid_arguments_never_clone(self):
        cases = [(), (URL,), (URL, "../escape"), (URL, "dev"), (URL, "fork", "--ref"),
                 (URL, "fork", "--prefix", "relative"), (URL, "fork", "--unknown"),
                 ("11.4.3", "extra"), ("not-a-version",)]
        for args in cases:
            with self.subTest(args=args):
                self.assertNotEqual(self.install(*args).returncode, 0)
        self.assertFalse(self.calls("git"))

    def test_existing_destination_and_module_are_preserved(self):
        prefix = self.platform / "geant4/existing"
        prefix.mkdir(parents=True)
        marker = prefix / ".keep"
        marker.write_text("keep")
        self.assertNotEqual(self.install(URL, "existing").returncode, 0)
        self.assertEqual(marker.read_text(), "keep")
        self.assert_success(self.install(URL, "new-fork"))
        module = self.modules / "geant4/new-fork"
        before = module.read_text()
        self.assertNotEqual(self.install(URL, "new-fork").returncode, 0)
        self.assertEqual(module.read_text(), before)
        self.assertEqual(len(self.calls("git")), 1)

    def test_failures_do_not_publish_modules(self):
        for failure in ("git", "cmake", "make", "install"):
            with self.subTest(failure=failure):
                name = f"failed-{failure}"
                result = self.install(URL, name, fail=failure)
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assertFalse((self.modules / "geant4" / name).exists())
        self.assertEqual(len(self.calls("cmake")), 3)


if __name__ == "__main__":
    unittest.main()
