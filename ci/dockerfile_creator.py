#!/usr/bin/env python3
import argparse

DISTROS = ["fedora", "ubuntu", "archlinux", "almalinux", "debian"]

# ------------------------------------------------------------------------------
# Package groups by purpose
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
		"fedora":    ["xterm", "x11vnc", "novnc"],
		"ubuntu":    ["xterm", "x11vnc", "novnc"],
		"archlinux": ["xterm", "tigervnc", "websockify"],
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


def base_name(name: str) -> str:
	"""Normalize a distro string like 'ubuntu' or 'debian' (you said you pass plain distro)."""
	return name.lower().strip()


def map_family(platform: str) -> str:
	p = base_name(platform)
	if p in ("almalinux", "centos"):
		return "fedora"
	if p == "debian":
		return "ubuntu"
	return p


def unique_preserve_order(items):
	seen = set()
	out = []
	for it in items:
		if it not in seen:
			seen.add(it)
			out.append(it)
	return out


cleanup_string_by_family = {
	"fedora":    (
		" \\\n && dnf -y update"
		" \\\n && dnf -y check-update"
		" \\\n && dnf clean packages"
		" \\\n && dnf clean all"
		" \\\n && rm -rf /var/cache/dnf \n"
	),
	"ubuntu":    (
		" \\\n && apt-get -y update"
		" \\\n && apt-get -y autoclean"
		" \\\n && rm -rf /var/lib/apt/lists/* \n"
	),
	"archlinux": (
		" \\\n && pacman -Syu --noconfirm"
		" \\\n && pacman -Scc --noconfirm"
		" \\\n && rm -rf /var/cache/pacman/pkg/* \n"
	),
}


# ------------------------------------------------------------------------------
# Helpers

def novnc_launch_commands(distro: str) -> str:
	if distro.lower().strip() == "archlinux":
		# Use Xvfb + tigervnc's x0vncserver + our /opt/novnc install
		return """
# Setup environment and launch noVNC + x0vncserver + Xvfb (Arch)
ENV DISPLAY=:1
ENV GEOMETRY=1280x800

CMD ["/bin/bash", "-c", "\
Xvfb :1 -screen 0 ${GEOMETRY}x24 & \\
x0vncserver -display :1 -rfbport 5900 -SecurityTypes None -NeverShared=1 -AlwaysShared=0 -verbose=0 -localhost & \\
novnc_proxy --vnc localhost:5900 --listen 6080"]
"""
	else:
		# Other distros keep x11vnc and packaged /usr/share/novnc
		return """
# Setup environment and launch noVNC + x11vnc + Xvfb
ENV DISPLAY=:1
ENV GEOMETRY=1280x800

CMD ["/bin/bash", "-c", "\
Xvfb :1 -screen 0 ${GEOMETRY}x24 & \\
x11vnc -display :1 -nopw -forever -bg -quiet && \\
/usr/share/novnc/utils/novnc_proxy --vnc localhost:5900 --listen 6080"]
"""


def local_setup_filename():
	return '/etc/profile.d/localSetup.sh'


def docker_header(image: str) -> str:
	return f"""FROM {image}
LABEL maintainer="Maurizio Ungaro <ungaro@jlab.org>"

# run shell instead of sh
SHELL ["/bin/bash", "-c"]
ENV AUTOBUILD=1
"""


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


def packages_to_be_installed(distro: str) -> str:
	base = base_name(distro)  # e.g., 'ubuntu', 'debian', 'fedora'
	family = map_family(base)  # e.g., 'ubuntu' (for debian), 'fedora', 'arch'

	pkgs = []
	for section in pkg_sections.values():
		pkgs.extend(section.get(family, []))

	# Debian needs Qt6 name tweaks (only when the actual base is debian)
	if base == "debian":
		pkgs = debian_adjustments(pkgs)

	# De-dupe but KEEP section order
	pkgs = unique_preserve_order(pkgs)
	return ' '.join(pkgs)


def install_root_tarball(base: str, local_setup_file: str) -> str:
	root_version = "6.36.04"
	# ubuntu
	os_name = "ubuntu24.04-x86_64-gcc13.3"
	if base == "debian":
		os_name = "debian12-x86_64-gcc12.2"  # adjust to an actual ROOT build name if available
	root_file = f'root_v{root_version}.Linux-{os_name}.tar.gz'
	root_remote_file = f'https://root.cern/download/{root_file}'
	root_install_dir = '/usr/local'
	commands = '\n\n'
	commands += '# root installation using tarball\n'
	commands += f'RUN cd {root_install_dir} \\\n'
	commands += f'    && {curl_command(root_remote_file)}  \\\n'
	commands += f'    && tar -xzf {root_file} \\\n'
	commands += f'    && rm {root_file} \\\n'
	commands += f'    && echo "cd {root_install_dir}/root/bin ; source thisroot.sh ; cd -" >> {local_setup_file}\n'
	return commands


def install_meson() -> str:
	meson_version = '1.9.0'
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


def install_novnc_for_arch() -> str:
	novnc_ver = "v1.6.0"  # pick a known-good tag
	url = f"https://github.com/novnc/noVNC/archive/refs/tags/{novnc_ver}.tar.gz"
	return (
		"\n# Install noVNC from upstream (Arch fallback)\n"
		"RUN mkdir -p /opt && cd /opt \\\n"
		f"    && {curl_command(url)} \\\n"
		f"    && tar -xzf {novnc_ver}.tar.gz \\\n"
		f"    && rm {novnc_ver}.tar.gz \\\n"
		f"    && mv noVNC-{novnc_ver.lstrip('v')} /opt/novnc \\\n"
		"    && ln -sf /opt/novnc/utils/novnc_proxy /usr/local/bin/novnc_proxy\n"
	)


def jlab_certificate() -> str:
	return "/etc/pki/ca-trust/source/anchors/JLabCA.crt"


def curl_command(url: str) -> str:
	"""
	Build a portable curl command string.
	We attempt to use a site-specific CA if present; otherwise rely on system CAs.
	-k is kept for resilience, but you can remove it once CAs are squared away.
	"""
	ca = jlab_certificate()
	return f"bash -lc 'CA=\"{ca}\"; EXTRA=\"\"; [ -f \"$CA\" ] && EXTRA=\"--cacert $CA\"; curl -S --location-trusted --progress-bar --retry 4 $EXTRA -k -O {url}'"


def packages_install_commands(image: str, base: str) -> str:
	family = map_family(image)
	packages = packages_to_be_installed(image)
	cleanup = cleanup_string_by_family.get(family, "")
	local_setup_file = local_setup_filename()
	commands = ""
	commands += docker_header(base)

	is_alma = "almalinux" in image.lower()

	if family == "fedora":
		commands += "RUN update-ca-trust\n\n"
		if is_alma:
			commands += (
				"# AlmaLinux synergy' \\\n"
				"RUN dnf install -y 'dnf-command(config-manager)' \\\n"
				"    && dnf config-manager --set-enabled crb \\\n"
				"    && dnf install -y almalinux-release-synergy \n\n"
			)
		commands += "# Install Packages\n"
		commands += f"RUN dnf install -y --allowerasing {packages}{cleanup}"

	elif family == "ubuntu":
		commands += "RUN apt-get update\n\n"
		commands += "# Install CA tools\n"
		commands += "RUN apt-get install -y ca-certificates\n"
		commands += "RUN update-ca-certificates\n\n"
		commands += "# Install Packages\n"
		commands += (
				"RUN ln -fs /usr/share/zoneinfo/America/New_York /etc/localtime \\\n"
				"    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata "
				+ packages + cleanup
		)
		commands += install_root_tarball(image, local_setup_file)

	elif family == "archlinux":
		commands += f"RUN pacman -Sy --noconfirm archlinux-keyring\n\n"
		commands += "# Install Packages\n"
		commands += f"RUN pacman -Syu --noconfirm --needed {packages}{cleanup}"
		# Install noVNC from upstream for Arch
		commands += install_novnc_for_arch()

	commands += install_meson()
	commands += novnc_launch_commands(image)
	return commands


# ------------------------------------------------------------------------------
def main():
	parser = argparse.ArgumentParser(
		description="Return list of packages or install commands for Geant4 + novnc environments",
		epilog="Example: ./g4pkglist.py -p fedora:40 --install"
	)
	parser.add_argument(
		"-p", "--platform", required=True,
		help="Target base os (e.g., fedora, almalinux, ubuntu, debian,  rchlinux"
	)
	parser.add_argument(
		"-f", "--base", required=True,
		help="Target base image version (e.g., fedora:40 / almalinux:9  / ubuntu:24.04 / debian:13 / archlinux:latest)"
	)
	parser.add_argument(
		"--install", action="store_true",
		help="Print full Dockerfile (header + install commands)"
	)

	args = parser.parse_args()
	if args.install:
		print(packages_install_commands(args.platform, args.base))
	else:
		print(packages_to_be_installed(args.platform))


# ------------------------------------------------------------------------------
if __name__ == "__main__":
	main()
