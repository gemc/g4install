#!/usr/bin/env python3

valid_images = ["fedora", "ubuntu", "archlinux", "almalinux", "debian"]


def is_valid_image(image: str) -> bool:
	if image in valid_images:
		return True
	else :
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
	Build a portable curl command string.
	We attempt to use a site-specific CA if present; otherwise rely on system CAs.
	-k is kept for resilience, but you can remove it once CAs are squared away.
	"""
	ca = jlab_certificate()
	return f"bash -lc 'CA=\"{ca}\"; EXTRA=\"\"; [ -f \"$CA\" ] && EXTRA=\"--cacert $CA\"; curl -S --location --progress-bar --retry 4 $EXTRA -O {url}'"
