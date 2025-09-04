#!/usr/bin/env python3
import argparse

from functions import map_family, is_valid_image, unique_preserve_order

# Small debian adjustments are done in code below
pkg_sections = {
	"cxx_essentials": {
		"fedora":    ["git", "make", "cmake", "gcc-c++", "gdb", "valgrind"],
		"ubuntu":    ["git", "make", "cmake", "g++", "gdb", "valgrind"],
		"archlinux": ["git", "make", "cmake", "gcc", "gdb", "valgrind"],
	},
	"expat":          {
		"fedora":    ["expat-devel"],
		"ubuntu":    ["libexpat1-dev"],
		"archlinux": ["expat"],
	},
	"sql":            {
		"fedora":    ["mariadb-devel", "sqlite-devel"],
		"ubuntu":    ["libmysqlclient-dev", "libsqlite3-dev"],
		"archlinux": ["mariadb", "mariadb-libs", "sqlite"],
	},
	"python_ninja":   {
		"fedora":    ["python3-devel", "ninja-build"],
		"ubuntu":    ["python3-dev", "ninja-build"],
		"archlinux": ["python", "python-pip", "ninja"],
	},
	"x11_1":          {
		"fedora":    ["mesa-libGLU-devel", "libX11-devel", "libXpm-devel", "libXft-devel"],
		"ubuntu":    ["libglu1-mesa-dev", "libx11-dev", "libxpm-dev", "libxft-dev"],
		"archlinux": ["mesa", "glu", "libx11", "libxpm", "libxft"],
	},
	"x11_2":          {
		"fedora":    ["libXt-devel", "libXmu-devel", "libXrender-devel", "xorg-x11-server-Xvfb",
		              "xrandr"],
		"ubuntu":    ["libxt-dev", "libxmu-dev", "libxrender-dev", "xvfb",
		              "x11-xserver-utils"],
		"archlinux": ["libxt", "libxmu", "libxrender", "xorg-server-xvfb",
		              "xorg-xrandr"],

	},
	"utilities_1":    {
		"fedora":    ["bzip2", "wget", "curl", "nano", "bash", "tcsh", "zsh",
		              "hostname", "gedit", "environment-modules", "pv", "which"],
		"ubuntu":    ["bzip2", "wget", "curl", "nano", "bash", "tcsh", "zsh",
		              "hostname", "gedit", "environment-modules", "pv", "which", "ca-certificates"],
		"archlinux": ["bzip2", "wget", "curl", "nano", "bash", "tcsh", "zsh",
		              "inetutils", "gedit", "pv", "which"],

	},
	"utilities_2":    {
		"fedora":    ["psmisc", "procps", "mailcap", "net-tools", "rsync", "patch"],
		"ubuntu":    ["psmisc", "procps", "mailcap", "net-tools", "rsync", "patch"],
		"archlinux": ["psmisc", "procps", "mailcap", "net-tools", "rsync", "patch"],
	},
	# vnc: use tigervnc + python-websockify; we’ll fetch noVNC from GitHub
	"vnc":            {
		"fedora":    ["xterm", "x11vnc", "websockify"],
		"ubuntu":    ["xterm", "x11vnc", "websockify"],
		"archlinux": ["xterm", "tigervnc"],
	},
	"qt6":            {
		"fedora":    ["qt6-qtbase-devel"],
		"ubuntu":    ["qt6-base-dev", "libqt6opengl6t64", "libqt6openglwidgets6t64"],
		"archlinux": ["qt6-base"],
	},
	"root":           {
		"fedora":    ["root"],
		"ubuntu":    [],
		"archlinux": ["root"],
	},
	"sanitizers":     {
		"fedora":    ["liblsan", "libasan", "libubsan", "libtsan", "tbb"],
		"ubuntu":    ["liblsan0", "libasan8", "libubsan1", "libtsan2", "libtbb12"],
		"archlinux": ["gcc-libs", "tbb"],
	},
}


def debian_adjustments(pkgs: list[str]) -> list[str]:
	# replace Ubuntu’s t64 Qt libs with Debian names
	rep = {
		"libqt6opengl6t64":        "libqt6opengl6",
		"libqt6openglwidgets6t64": "libqt6openglwidgets6",
		"libmysqlclient-dev":      "libmariadb-dev"
	}
	out = []
	for p in pkgs:
		out.append(rep.get(p, p))
	return out


def packages_to_be_installed(image: str) -> str:
	family = map_family(image)  # e.g., 'ubuntu' (for debian), 'fedora', 'arch'

	pkgs = []
	for section in pkg_sections.values():
		pkgs.extend(section.get(family, []))

	# Debian needs Qt6 name tweaks (only when the actual base is debian)
	if image == "debian":
		pkgs = debian_adjustments(pkgs)

	# De-dupe but KEEP section order
	pkgs = unique_preserve_order(pkgs)
	return ' '.join(pkgs)


def packages_install_command(image: str) -> str:
	family = map_family(image)
	packages = packages_to_be_installed(image)
	command = ""

	if family == "fedora":
		command += f"RUN dnf install -y --allowerasing {packages}"

	elif family == "ubuntu":
		command += (
				"RUN ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime \\\n"
				" && apt-get update \\\n"
				"    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata "
				+ packages
		)

	elif family == "archlinux":
		command += f"RUN pacman -Syu --noconfirm --needed {packages}"

	return command


def main():
	parser = argparse.ArgumentParser(
		description="Return list of packages or install commands for a given base image",
		epilog="Example: ./packages.py -i fedora"
	)
	parser.add_argument(
		"-i", "--image", required=True,
		help="Target base os (e.g., fedora, almalinux, ubuntu, debian,  archlinux"
	)

	args = parser.parse_args()
	is_valid_image(args.image)

	print(packages_install_command(args.image))


if __name__ == "__main__":
	main()
