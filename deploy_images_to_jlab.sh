#!/usr/bin/env bash

set -euo pipefail

readonly default_geant4_version="11.4.2"
readonly default_os_flavor="almalinux"
readonly default_os_version="9.4"
readonly default_image="ghcr.io/gemc/g4install"
readonly default_destination="/scigroup/cvmfs/geant4/g4install"
readonly default_podman_storage="/scratch/ungaro"
readonly image_install_root="/cvmfs/oasis.opensciencegrid.org/geant4/g4install"

geant4_version="$default_geant4_version"
os_flavor="$default_os_flavor"
os_version="$default_os_version"
image="$default_image"
destination="$default_destination"
podman_storage="$default_podman_storage"
container_id=""
stage=""
container_command=()

usage() {
	cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Pull the amd64 and arm64 Geant4 images and install their Geant4, CLHEP, and Xerces-C trees at the lab.

Options:
  -g, --geant4-version VERSION  Geant4 version (default: $default_geant4_version)
  -o, --os-flavor FLAVOR       Image OS flavor (default: $default_os_flavor)
  -v, --os-version VERSION     Image OS version (default: $default_os_version)
      --image IMAGE            Container image without a tag (default: $default_image)
  -d, --destination DIRECTORY  Installation root (default: $default_destination)
      --podman-storage DIR      Podman storage parent (default: $default_podman_storage)
  -h, --help                   Show this help

Examples:
  $(basename "$0")
  $(basename "$0") --geant4-version 11.4.2 --os-flavor almalinux --os-version 9.4
  $(basename "$0") -g 11.4.2 -o almalinux -v 9.4 -d /tmp/g4install

The AlmaLinux 9.4 images install as almalinux9-gcc11-arm64 and almalinux9-gcc11-x86_64.
Existing package-version directories are kept and reported; this script does not replace them.
EOF
}

die() {
	printf 'Error: %s\n' "$*" >&2
	exit 1
}

cleanup() {
	if [[ -n "$container_id" ]]; then
		"${container_command[@]}" rm -f "$container_id" >/dev/null 2>&1 || true
	fi
	if [[ -n "$stage" && -d "$stage" ]]; then
		rm -rf -- "$stage"
	fi
}

trap cleanup EXIT

while (( $# > 0 )); do
	case "$1" in
		-g|--geant4-version)
			(( $# >= 2 )) || die "$1 requires a value"
			geant4_version="$2"
			shift 2
			;;
		-o|--os-flavor)
			(( $# >= 2 )) || die "$1 requires a value"
			os_flavor="$2"
			shift 2
			;;
		-v|--os-version)
			(( $# >= 2 )) || die "$1 requires a value"
			os_version="$2"
			shift 2
			;;
		--image)
			(( $# >= 2 )) || die "$1 requires a value"
			image="$2"
			shift 2
			;;
		-d|--destination)
			(( $# >= 2 )) || die "$1 requires a value"
			destination="$2"
			shift 2
			;;
		--podman-storage)
			(( $# >= 2 )) || die "$1 requires a value"
			podman_storage="$2"
			shift 2
			;;
		-h|--help)
			usage
			exit 0
			;;
		*)
			die "unknown option: $1 (use --help for examples)"
			;;
	esac
done

[[ "$geant4_version" =~ ^[0-9]+([.][0-9]+)*$ ]] || die "invalid Geant4 version: $geant4_version"
[[ "$os_flavor" =~ ^[a-z0-9]+$ ]] || die "invalid OS flavor: $os_flavor"
[[ "$os_version" =~ ^[a-zA-Z0-9._-]+$ ]] || die "invalid OS version: $os_version"
[[ "$image" != *:* ]] || die "--image must not include a tag"
[[ "$destination" = /* ]] || die "--destination must be an absolute path"
[[ "$podman_storage" = /* ]] || die "--podman-storage must be an absolute path"

if command -v podman >/dev/null 2>&1; then
	podman_root="$podman_storage/podman-root"
	podman_runroot="$podman_storage/podman-runroot"
	mkdir -p "$podman_root" "$podman_runroot"
	container_command=(podman --root "$podman_root" --runroot "$podman_runroot")
	printf 'Using Podman storage under %s\n' "$podman_storage"
elif command -v docker >/dev/null 2>&1; then
	container_command=(docker)
else
	die "podman or docker is required"
fi

mkdir -p "$destination"
[[ -w "$destination" ]] || die "destination is not writable: $destination"
stage="$(mktemp -d /tmp/g4install-pack.XXXXXX)"

os_major="${os_version%%.*}"
platform_prefix="${os_flavor}${os_major}"

install_architecture() {
	local docker_arch="$1"
	local install_arch="$2"
	local image_ref="${image}:${geant4_version}-${os_flavor}-${os_version}-${docker_arch}"
	local arch_stage="${stage}/${docker_arch}"
	local source_platform target_platform package entry entry_name
	local -a platform_candidates package_entries

	printf '\nPulling %s\n' "$image_ref"
	"${container_command[@]}" pull --platform "linux/${docker_arch}" "$image_ref"
	container_id="$(
		"${container_command[@]}" create --platform "linux/${docker_arch}" "$image_ref" /bin/true
	)"
	mkdir -p "$arch_stage"
	"${container_command[@]}" cp "${container_id}:${image_install_root}/." "$arch_stage"
	"${container_command[@]}" rm -f "$container_id" >/dev/null
	container_id=""

	shopt -s nullglob
	platform_candidates=("$arch_stage/${platform_prefix}-"*"-${install_arch}")
	shopt -u nullglob
	(( ${#platform_candidates[@]} == 1 )) || {
		die "expected one ${platform_prefix}-*-${install_arch} directory in $image_ref; " \
			"found ${#platform_candidates[@]}"
	}

	source_platform="${platform_candidates[0]}"
	[[ -d "$source_platform/geant4/$geant4_version" ]] || {
		die "image does not contain geant4/$geant4_version under $(basename "$source_platform")"
	}
	target_platform="$destination/$(basename "$source_platform")"
	mkdir -p "$target_platform"

	for package in clhep xercesc geant4; do
		[[ -d "$source_platform/$package" ]] || die "image does not contain $package"
		mkdir -p "$target_platform/$package"
		shopt -s nullglob dotglob
		package_entries=("$source_platform/$package"/*)
		shopt -u nullglob dotglob
		(( ${#package_entries[@]} > 0 )) || die "image contains an empty $package directory"
		for entry in "${package_entries[@]}"; do
			entry_name="$(basename "$entry")"
			[[ -d "$entry" ]] || die "expected a version directory: $entry"
			if [[ -e "$target_platform/$package/$entry_name" ]]; then
				printf 'Keeping existing %s/%s/%s\n' "$(basename "$target_platform")" "$package" \
					"$entry_name"
			else
				printf 'Installing %s/%s/%s\n' "$(basename "$target_platform")" "$package" \
					"$entry_name"
				cp -a "$entry" "$target_platform/$package/"
			fi
			[[ -d "$target_platform/$package/$entry_name" ]] || {
				die "failed to install $package/$entry_name under $target_platform"
			}
		done
		printf 'Verified %s/%s\n' "$(basename "$target_platform")" "$package"
	done
}

install_architecture arm64 arm64
install_architecture amd64 x86_64

printf '\nInstalled and verified Geant4 %s, CLHEP, and Xerces-C under %s\n' \
	"$geant4_version" "$destination"
