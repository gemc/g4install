#!/usr/bin/env python3

from functions import remote_setup_filename, curl_command, map_family, is_valid_image, sim_home


def install_root_from_source(image: str, root_version: str) -> str:
	# on fedora lines, we would install from dnf
	family = map_family(image)
	if family == "fedora" or family == "archlinux":
		return ""

	root_install_dir = '/usr/local'
	root_github = 'https://github.com/root-project/root.git'
	features_to_skip = ['arrow', 'davix', 'cefweb', 'cocoa', 'cuda', 'fortran', 'pythia8', 'r',
	                    'shadowpw', 'tmva', 'vecgeom', 'xrootd']
	root_skip = ''
	for feature in features_to_skip:
		root_skip += f' -D{feature}=OFF'

	commands = '\n\n'
	commands += '# root installation from source tarball\n'
	commands += f'RUN cd {root_install_dir} \\\n'
	commands += f'    && git clone -c advice.detachedHead=false --single-branch --depth=1 -b {root_version} {root_github} root_src  \\\n'
	commands += f'    && mkdir root_build root && cd root_build \\\n'
	commands += f'    && cmake {root_skip} -Dminimal=ON -DCMAKE_INSTALL_PREFIX=../root ../root_src \\\n'
	commands += f'    && cmake --build . -- install  -j"$(nproc)" \\\n'
	commands += f'    && echo "cd {root_install_dir}/root/bin ; source thisroot.sh ; cd -" >> {remote_setup_filename()}\n'
	return commands


def install_meson(meson_version: str) -> str:
	meson_location = f'https://github.com/mesonbuild/meson/releases/download/{meson_version}'
	meson_file = f'meson-{meson_version}.tar.gz'
	meson_remote_file = f'{meson_location}/{meson_file}'
	meson_install_dir = '/usr/local'
	commands = '\n'
	commands += '# meson installation using tarball\n'
	commands += f'RUN cd {meson_install_dir} \\\n'
	commands += f'    && {curl_command(meson_remote_file)}  \\\n'
	commands += f'    && tar -xzf {meson_file} \\\n'
	commands += f'    && rm {meson_file} \\\n'
	commands += f'    && ln -s {meson_install_dir}/meson-{meson_version}/meson.py /usr/bin/meson\n'
	return commands


def install_novnc(novnc_ver: str) -> str:
	url = f"https://github.com/novnc/noVNC/archive/refs/tags/{novnc_ver}.tar.gz"
	websockify_url = "https://github.com/novnc/websockify"

	return (
		"\n# Install noVNC\n"
		"RUN mkdir -p /opt && cd /opt \\\n"
		f"    && {curl_command(url)} \\\n"
		f"    && tar -xzf {novnc_ver}.tar.gz \\\n"
		f"    && rm {novnc_ver}.tar.gz \\\n"
		f"    && mv noVNC-{novnc_ver.lstrip('v')} /opt/novnc \\\n"
		f"    && ln -sf /opt/novnc/vnc.html /opt/novnc/index.html \\\n"
		f"    && ln -sf /opt/novnc/utils/novnc_proxy /usr/local/bin/novnc_proxy \\\n"
		f"    && git clone --depth=1 {websockify_url} /opt/novnc/utils/websockify\n"
	)


# not used
def install_lmod_on_arch() -> str:
	return r"""
# Install Lmod on Arch Linux
RUN pacman -Syu --noconfirm \
    && pacman -S --noconfirm --needed base-devel git sudo zsh \
    && useradd -m -G wheel -s /bin/bash build \
    && echo "build ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-build \
    && chmod 440 /etc/sudoers.d/99-build \
    && su - build -c 'git clone https://aur.archlinux.org/lmod.git && cd lmod && makepkg -si --noconfirm --needed' 
""".lstrip()


def install_envmod_on_arch() -> str:
	return r"""
# Install env-modules on Arch Linux
RUN pacman -Syu --noconfirm \
    && pacman -S --needed --noconfirm base-devel git sudo fakeroot tcl procps pacman-contrib \
    && useradd -m -G wheel -s /bin/bash build \
    && echo "build ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/99-build \
    && chmod 440 /etc/sudoers.d/99-build \
    && su - build -c 'git clone https://aur.archlinux.org/env-modules.git && cd env-modules && updpkgsums && makepkg -si --noconfirm --needed' \
    && pacman -U --noconfirm /home/build/env-modules/*.pkg.tar.zst
""".lstrip()


# adding UPSTREAM_REV (which changes with every commit to g4install) so that this
# function is never cached by docker
def install_g4install(is_cvfms: bool, geant4_version: str) -> str:
	g4install = sim_home(is_cvfms)
	commands = ''
	commands += '\n# Clone g4install\n'
	commands += 'ARG UPSTREAM_REV=unknown\n'
	commands += f'RUN mkdir -p {g4install} \\\n'
	commands += f'    && cd {g4install} \\\n'
	commands += f'    && git clone --depth=1 https://github.com/gemc/g4install . \\\n'
	commands += f'    && echo "module use {g4install}/modules" >> {remote_setup_filename()} \\\n'
	commands += f'    && echo "module load geant4/{geant4_version}" >> {remote_setup_filename()}\n'
	return commands


def install_clhep(version: str) -> str:
	commands = f"\n# Install CLHEP {version}\n"
	commands += f'RUN source {remote_setup_filename()} \\\n'
	commands += f'    && install_clhep {version}\n'
	return commands


def install_xercesc(version: str) -> str:
	commands = f"\n# Install XERCESC {version}\n"
	commands += f'RUN source {remote_setup_filename()} \\\n'
	commands += f'    && install_xercesc {version}\n'
	return commands


def install_geant4(version: str) -> str:
	commands = f"\n# Install Geant4 {version}\n"
	commands += f'RUN source {remote_setup_filename()} \\\n'
	commands += f'    && install_geant4 {version}\n'
	return commands


def install_additional_libraries(image: str, geant4_version: str, root_version: str,
                                 meson_version: str,
                                 novnc_version: str) -> str:
	commands = '\n'
	if image == "archlinux":
		commands += install_envmod_on_arch()

	commands += '\n# Install additional libraries\n'
	commands += f'# ROOT version: {root_version}\n'
	commands += f'# Meson version: {meson_version}\n'
	commands += f'# noVNC version: {novnc_version}\n'
	commands += install_root_from_source(image, root_version)
	commands += install_meson(meson_version)
	commands += install_novnc(novnc_version)
	commands += install_g4install(True, geant4_version)
	commands += install_geant4(geant4_version)

	return commands


import argparse
import sys


def main():
	parser = argparse.ArgumentParser(
		description="Return list of packages or install commands for a given base image",
		epilog="Example: python3 ./ci/additional_libraries.py -i fedora",
		add_help=True,
	)

	# Required conceptually; if missing, we print usage and exit (instead of argparse error text)
	parser.add_argument(
		"-i", "--image",
		help="Target base os (e.g., fedora, almalinux, ubuntu, debian, archlinux)"
	)

	# Defaults used when flags are omitted
	parser.add_argument(
		"--root-version", default="6.36.04",
		help="Version of ROOT to install (default: %(default)s)"
	)
	parser.add_argument(
		"--meson-version", default="1.9.0",
		help="Version of Meson to install (default: %(default)s)"
	)
	parser.add_argument(
		"--novnc-version", default="v1.6.0",
		help="Version of noVNC to install (default: %(default)s)"
	)
	parser.add_argument(
		"--geant4-version", default="11.4.0",
		help="Version of Geant4 to install (default: %(default)s)"
	)

	args = parser.parse_args()

	# If -i/--image is not given, print usage and exit
	if not args.image:
		parser.print_usage(sys.stderr)
		sys.exit(2)

	is_valid_image(args.image)

	commands = install_additional_libraries(
		args.image,
		args.geant4_version,
		args.root_version,
		args.meson_version,
		args.novnc_version,
	)
	print(commands)


# ------------------------------------------------------------------------------
if __name__ == "__main__":
	main()
