#!/usr/bin/env python3
import argparse

from functions import map_family, is_valid_image, local_setup_filename, remote_setup_filename
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
	"ubuntu":    (
		" \\\n && apt-get -y autoremove"
		" \\\n && apt-get -y autoclean"
		" \\\n && rm -rf /var/lib/apt/lists/* \n"
	),
	"archlinux": (
		" \\\n && pacman -Scc --noconfirm"
		" \\\n && rm -rf /var/cache/pacman/pkg/* \n"
	),
}


def docker_header(image: str, tag: str) -> str:
	return f"""FROM {image}:{tag}
LABEL maintainer="Maurizio Ungaro <ungaro@jlab.org>"

# run shell instead of sh
SHELL ["/bin/bash", "-c"]
CMD ["bash", "-l"]
ENV AUTOBUILD=1
"""


def copy_setup_file() -> str:
	local_setup_file = local_setup_filename()
	remote_setup_file = remote_setup_filename()
	return f"""
# Copy local setup file
COPY {local_setup_file} {remote_setup_file}
"""

def install_jlab_ca(image: str) -> str:
	family = map_family(image)

	commands = "\n# Install JLab CA\n"

	if family == "fedora":
		commands += "ADD https://pki.jlab.org/JLabCA.crt /etc/pki/ca-trust/source/anchors/JLabCA.crt\n"
		commands += "RUN update-ca-trust\n\n"
	elif family == "ubuntu":
		commands += "ADD https://pki.jlab.org/JLabCA.crt /usr/local/share/ca-certificates/JLabCA.crt\n"
		commands += "RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates && update-ca-certificates\n\n"
	elif family == "archlinux":
		commands += "ADD https://pki.jlab.org/JLabCA.crt /etc/ca-certificates/trust-source/anchors/JLabCA.crt\n"
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

	elif family == "ubuntu":
		commands += ""

	elif family == "archlinux":
		commands += "RUN pacman -Sy --noconfirm archlinux-keyring\n\n"

	return commands



def create_dockerfile(image: str, base: str, root_version: str, meson_version: str, novnc_version: str) -> str:
	commands = ""

	commands += docker_header(image, base)
	commands += copy_setup_file()
	commands += install_jlab_ca(image)
	commands += additional_preamble(image)
	commands += packages_install_command(image)
	commands += cleanup_string_by_family[map_family(image)]
	commands += install_additional_libraries(image, root_version, meson_version, novnc_version)

	return commands


# ------------------------------------------------------------------------------
def main():
	parser = argparse.ArgumentParser(
		description="Print a dockerfile with install commands for a given base image, image tag and variouse packages versions",
		epilog="Example: ./dockerfile_creator.py -i fedora:40 "
	)
	parser.add_argument(
		"-i", "--image", required=True,
		help="Target base os (e.g., fedora, almalinux, ubuntu, debian,  archlinux"
	)
	parser.add_argument(
		"-t", "--tag", required=True,
		help="Base image tags (e.g., 40 for fedora, 24.04 for ubuntu, etc)"
	)
	parser.add_argument(
		"--root-version", default="6.36.04",
		help="Version of ROOT to install (default: 6.36.04)"
	)
	parser.add_argument(
		"--meson-version", default="1.9.0",
		help="Version of Meson to install (default: 1.9.0)"
	)
	parser.add_argument(
		"--novnc-version", default="v1.6.0",
		help="Version of noVNC to install (default: v1.6.0)"
	)

	args = parser.parse_args()
	is_valid_image(args.image)

	dockerfile = create_dockerfile(args.image, args.tag, args.root_version, args.meson_version, args.novnc_version)
	print(dockerfile)

# ------------------------------------------------------------------------------
if __name__ == "__main__":
	main()
