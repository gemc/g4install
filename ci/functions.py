#!/usr/bin/env python3

from urllib.parse import urlparse

valid_images = ["fedora", "ubuntu", "archlinux", "almalinux", "debian"]


def is_valid_image(image: str) -> bool:
	if image in valid_images:
		return True
	else:
		print(f"Error: invalid image '{image}'")
		print(f"Valid images: {available_images()}")
		exit(1)


def available_images() -> str:
	return ', '.join(sorted(valid_images))


def map_family(image: str) -> str:
	if image in ("almalinux", "centos"):
		return "fedora"
	if image == "ubuntu":
		return "debian"
	return image


def unique_preserve_order(items):
	seen = set()
	out = []
	for it in items:
		if it not in seen:
			seen.add(it)
			out.append(it)
	return out


def remote_startup_dir() -> str:
	return '/usr/local/bin'


def local_entrypoint():
	return 'ci/docker-entrypoint.sh'


def remote_entrypoint():
	return f'{remote_startup_dir()}/docker-entrypoint.sh'


def local_entrypoint_addon():
	return 'ci/additional-entrycommands.sh'


def remote_entrypoint_addon():
	return f'{remote_startup_dir()}/additional-entrycommands.sh'


def local_novnc_startup_script() -> str:
	return 'ci/novnc/start-novnc.sh'


def remote_novnc_startup_script() -> str:
	return f'{remote_startup_dir()}/start-novnc.sh'


def jlab_certificate() -> str:
	return "/etc/pki/ca-trust/source/anchors/JLabCA.crt"


def sim_home(is_cvfms: bool) -> str:
	if is_cvfms:
		return "/cvmfs/oasis.opensciencegrid.org/geant4/g4install"
	else:
		return "/opt/software/"


def curl_command(url: str) -> str:
	"""
	Build a curl command string.
	Use the JLab CA override only for JLab-hosted URLs; otherwise trust system CAs.
	"""
	host = (urlparse(url).hostname or "").lower()
	use_site_ca = host.endswith(".jlab.org") or host.endswith(".jlab.gov")
	extra = f"--cacert {jlab_certificate()}" if use_site_ca else ""
	# no -k; we want proper verification
	# no --location-trusted; plain --location is enough
	return f"curl -S --fail-with-body --location --progress-bar --retry 4 {extra} -O {url}"
