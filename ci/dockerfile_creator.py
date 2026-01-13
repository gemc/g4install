#!/usr/bin/env python3

from functions import map_family, is_valid_image, local_entrypoint, remote_entrypoint, \
	remote_novnc_startup_script, local_novnc_startup_script, remote_startup_dir
from packages import packages_install_command
from additional_libraries import install_additional_libraries

cleanup_string_by_family = {
	"fedora":    (
		" \\\n && dnf -y update"
		" \\\n && dnf -y check-update"
		" \\\n && dnf clean packages"
		" \\\n && dnf clean all"
		" \\\n && rm -rf /var/cache/dnf \n"
	),
	"debian":    (
		" \\\n && apt-get -y autoremove"
		" \\\n && apt-get -y autoclean"
		" \\\n && rm -rf /var/lib/apt/lists/* \n"
	),
	"archlinux": (
		" \\\n && pacman -Scc --noconfirm"
		" \\\n && rm -rf /var/cache/pacman/pkg/* \n"
	),
}


def copy_setup_file(image: str) -> str:
	commands = "\n"
	commands += "# Create and set permissions to remote startup files\n"
	commands += f"COPY {local_entrypoint()} {remote_entrypoint()} \n"
	commands += f"COPY {local_novnc_startup_script()} {remote_novnc_startup_script()}\n"
	commands += f'RUN chmod 0755 {remote_entrypoint()} \n'
	commands += f'RUN chmod 0755 {remote_novnc_startup_script()} \n'
	commands += "\n# Create start-novnc.d directory and install functions\n"
	commands += f'RUN install -d -m 0755 {remote_startup_dir()}/start-novnc.d \n'

	family = map_family(image)
	if family == "fedora":
		commands += f"COPY ci/novnc/fedora.sh {remote_startup_dir()}/start-novnc.d/fedora.sh\n"
	elif family == "debian":
		commands += f"COPY ci/novnc/debian.sh {remote_startup_dir()}/start-novnc.d/debian.sh\n"
	elif family == "archlinux":
		commands += f"COPY ci/novnc/arch.sh {remote_startup_dir()}/start-novnc.d/arch.sh\n"


	return commands


def docker_header(image: str, tag: str) -> str:
	commands = f"FROM {image}:{tag}\n"
	commands += f"LABEL maintainer=\"Maurizio Ungaro <ungaro@jlab.org>\"\n\n"
	commands += f"# run bash instead of sh\n"
	commands += f"SHELL [\"/bin/bash\", \"-c\"]\n\n"
	commands += f"# Make browser UI the default; users can override with \"docker run ... bash -il\"\n"
	commands += f"# - Entrypoint is always executed\"\n"
	commands += f"# - CMD provides the default arguments\"\n"
	commands += f"ENTRYPOINT [\"{remote_entrypoint()}\"]\n\n"
	commands += f"CMD [\"{remote_novnc_startup_script()}\"]\n\n"
	commands += f"ENV AUTOBUILD=1\n"
	return commands


def install_jlab_ca(image: str) -> str:
	family = map_family(image)

	commands = "\n# Install JLab CA\n"
	# notice: refresh the JLab CA certs in ci/assets/JLabCA.crt
	# from https://pki.jlab.org/JLabCA.crt in case of expiration
	if family == "fedora":
		commands += "COPY ci/assets/JLabCA.crt /etc/pki/ca-trust/source/anchors/JLabCA.crt\n"
		commands += "RUN update-ca-trust\n\n"
	elif family == "debian":
		commands += "COPY ci/assets/JLabCA.crt /usr/local/share/ca-certificates/JLabCA.crt\n"
		commands += "RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && update-ca-certificates\n\n"
	elif family == "archlinux":
		commands += "COPY ci/assets/JLabCA.crt /etc/ca-certificates/trust-source/anchors/JLabCA.crt\n"
		commands += "RUN trust extract-compat\n\n"

	return commands


def additional_preamble(image: str) -> str:
	family = map_family(image)
	is_alma = "almalinux" in image.lower()
	commands = "\n"
	if family == "fedora":
		if is_alma:
			commands += (
				"# AlmaLinux synergy \\\n"
				"RUN dnf install -y 'dnf-command(config-manager)' \\\n"
				"    && dnf config-manager --set-enabled crb \\\n"
				"    && dnf install -y almalinux-release-synergy \n\n"
			)

	elif family == "debian":
		commands += ""

	elif family == "archlinux":
		commands += "RUN pacman-key --init && pacman-key --populate\\\n"
		commands += "    && pacman -Sy --noconfirm archlinux-keyring\n\n"

	return commands


def create_dockerfile(image: str, tag: str, geant4_version: str, root_version: str,
                      meson_version: str,
                      novnc_version: str) -> str:
	commands = ""
	commands += docker_header(image, tag)
	commands += copy_setup_file(image)
	commands += install_jlab_ca(image)
	commands += additional_preamble(image)
	commands += packages_install_command(image)
	commands += cleanup_string_by_family[map_family(image)]
	commands += install_additional_libraries(image,
	                                         geant4_version,
	                                         root_version,
	                                         meson_version,
	                                         novnc_version)

	return commands


import argparse
import sys


def main():
	parser = argparse.ArgumentParser(
		description="Print a dockerfile with install commands for a given base image, image tag and various package versions",
		epilog="Example: python3 ./ci/dockerfile_creator.py -i fedora -t 40",
		add_help=True,
	)

	# Required *conceptually*, but we want: if missing, show usage (not a long error)
	parser.add_argument(
		"-i", "--image",
		help="Target base os (e.g., fedora, almalinux, ubuntu, debian, archlinux)"
	)
	parser.add_argument(
		"-t", "--tag",
		help="Base image tag (e.g., 40 for fedora, 24.04 for ubuntu, etc.)"
	)

	# Defaults used if flags are omitted; if user provides the flag with no value,
	# argparse will error unless you set nargs/const (not requested here).
	parser.add_argument(
		"--root-version", default="v6-36-04",
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

	# 1) If -i/--image or -t/--tag are not given, print usage and exit
	if not args.image or not args.tag:
		parser.print_usage(sys.stderr)
		sys.exit(2)

	is_valid_image(args.image)

	dockerfile = create_dockerfile(
		args.image,
		args.tag,
		args.geant4_version,
		args.root_version,
		args.meson_version,
		args.novnc_version,
	)
	print(dockerfile)


# ------------------------------------------------------------------------------
if __name__ == "__main__":
	main()
