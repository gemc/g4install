#!/usr/bin/env python3

valid_images = ["fedora", "ubuntu", "archlinux", "almalinux", "debian"]
from urllib.parse import urlparse


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
	if image == "debian":
		return "ubuntu"
	return image


def unique_preserve_order(items):
	seen = set()
	out = []
	for it in items:
		if it not in seen:
			seen.add(it)
			out.append(it)
	return out


def local_setup_filename():
	return 'local_g4setup.sh'


def remote_setup_filename():
	return '/etc/profile.d/local_g4setup.sh'


def jlab_certificate() -> str:
	return "/etc/pki/ca-trust/source/anchors/JLabCA.crt"


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
