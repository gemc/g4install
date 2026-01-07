#!/bin/zsh

# Sync $SIM_HOME to jlab /cvmfs out of GHCR images using Apptainer

set -euo pipefail

outdir=/scigroup/cvmfs/geant4/g4install
container_dir=/cvmfs/oasis.opensciencegrid.org/geant4/g4install

g4version="11.4.0"
registry_base_address="ghcr.io/gemc/g4install"

usage() {
	local prog="sync_to_cvmfs.sh"
	cat <<EOF
Usage:
  ${prog} [-h] [-K] [-b <base_image>] [-g <geant4_version>] [-r <ghcr_repo>]

Description:
  Pulls GHCR images with Apptainer (sandbox mode) and rsyncs the directory
  ${container_dir}/<osname>/ into:
  ${outdir}/<osname>/

Options:
  -h                  Show this help and exit.
  -K                  Keep existing Apptainer cache/tmp dirs (do NOT rm -rf them).
  -b <base_image>     Only process one base image (default: all).
                      Allowed: ubuntu | fedora | debian | almalinux | archlinux
  -g <geant4_version> Geant4 version tag (default: ${g4version})
  -r <ghcr_repo>      GHCR repo (default: ${registry_base_address})

Examples:
  ${prog} -g ${g4version}
  ${prog} -b fedora -g ${g4version}
EOF
}

# ---- option parsing ----
keep_apptainer_dirs=0
selected_base_image=""

# ---- option parsing ----
while getopts ":hKb:g:r:" opt; do
  case "$opt" in
    h) usage; exit 0 ;;
    K) keep_apptainer_dirs=1 ;;
    b) selected_base_image="$OPTARG" ;;
    g) g4version="$OPTARG" ;;
    r) registry_base_address="$OPTARG" ;;
    \?)
      print -u2 "ERROR: Unknown option: -$OPTARG"
      usage >&2
      exit 2
      ;;
    :)
      print -u2 "ERROR: Option -$OPTARG requires an argument."
      usage >&2
      exit 2
      ;;
  esac
done
shift $((OPTIND - 1))


if (($# != 0)); then
	print -u2 "ERROR: Unexpected positional arguments: $*"
	usage >&2
	exit 2
fi

typeset -a BASE_IMAGES=(
	ubuntu
	fedora
	debian
	almalinux
	archlinux
)

is_valid_base_image()  {
	local x="$1"
	for b in $=BASE_IMAGES; do
		[[ "$b" == "$x" ]] && return 0
	done
	return 1
}

# function that returns the version tag for a given base image
get_version_tag() {
	local base_image="$1"
	case "$base_image" in
		ubuntu) echo "24.04" ;;
		fedora) echo "40" ;;
		debian) echo "12" ;;
		almalinux) echo "9.4" ;;
		archlinux) echo "latest" ;;
		*)
			print "Unknown base image: $base_image" >&2
			exit                                    1
			;;
	esac
}

get_gcc_version() {
	local base_image="$1"
	case "$base_image" in
		ubuntu) echo "13" ;;
		fedora) echo "14" ;;
		debian) echo "12" ;;
		almalinux) echo "11" ;;
		archlinux) echo "15" ;;
		*)
			print "Unknown base image: $base_image" >&2
			exit                                    1
			;;
	esac
}

# Build the distro prefix as used in the image directories
# ubuntu:   24.04 -> ubuntu24
# fedora:   40    -> fedora40
# debian:   12    -> debian12
# almalinux:9.4   -> almalinux9
# archlinux:latest-> arch
distro_prefix() {
	local base_image="$1"
	local ver
	ver="$(get_version_tag "$base_image")"
	case "$base_image" in
		ubuntu) echo "ubuntu${ver%%.*}" ;;
		fedora) echo "fedora${ver}" ;;
		debian) echo "debian${ver}" ;;
		almalinux) echo "almalinux${ver%%.*}" ;;
		archlinux) echo "arch" ;;
	esac
}

get_osname() {
	local base_image="$1"
	local arch="$2"
	if [[ $arch == "amd64" ]]; then
		arch="x86_64"
	fi
	local gcc="$(get_gcc_version "$base_image")"
	local prefix="$(distro_prefix "$base_image")"
	# matches what you showed inside the image, e.g. ubuntu24-gcc13-x86_64
	echo "${prefix}-gcc${gcc}-${arch}"
}

typeset -a archs=(amd64 arm64)

copy_to_cvmfs() {
	local src_image="$1" # ghcr.io/...:11.3.2-ubuntu-24.04-amd64
	local osname="$2" # e.g., ubuntu24-gcc13-x86_64
	local arch="$3" # amd64 | arm64

	local dest_dir="$outdir/$osname"
	mkdir -p "$dest_dir"

	# Create a private temp parent; let 'build' create the actual sandbox dir.
	local tmp_parent sbox
	tmp_parent="$(mktemp -d "${APPTAINER_TMPDIR%/}/sbox.XXXXXX")"
	sbox="${tmp_parent}/rootfs"  # DOES NOT EXIST yet

	print "Pulling ${src_image} (arch=${arch}) -> sandbox: $sbox"

	# --force avoids any overwrite prompt if a partial exists (e.g., after aborted runs)
	if ! apptainer build --force --fix-perms --arch "${arch}" --sandbox "${sbox}" "docker://${src_image}"; then
		print -u2 "Skip: ${src_image} not available for ${arch}"
		rm -rf -- "${tmp_parent}"
		return 0
	fi

	# Inside the image, files are under $container_dir/<osname>/
	local src="${sbox}/$container_dir/${osname}"
	if [[ ! -d "$src" ]]; then
		print -u2 "ERROR: ${src} not found in image"
		rm -rf -- "${tmp_parent}"
		exit 1
	fi

	print "Syncing ${src}/ -> ${dest_dir}/"
	rsync -aHAX --human-readable "${src}/" "${dest_dir}/"

	rm -rf -- "${tmp_parent}"
}

if [[ -n "$selected_base_image" ]]; then
	if ! is_valid_base_image "$selected_base_image"; then
		print -u2 "ERROR: Invalid base image: $selected_base_image"
		print -u2 "Allowed: $BASE_IMAGES"
		exit 2
	fi
fi

# caches on /work
export APPTAINER_CACHEDIR=/work/clas12/ungaro/apptainer-cache
export APPTAINER_TMPDIR=/work/clas12/ungaro/apptainer-tmp   # optional but helpful
export APPTAINER_MESSAGELEVEL=info   # or 'quiet'

if ((keep_apptainer_dirs == 0)); then
	print "Removing Apptainer dirs: $APPTAINER_CACHEDIR $APPTAINER_TMPDIR"
	rm -rf -- "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"
else
	print "Keeping Apptainer dirs (no cleanup): $APPTAINER_CACHEDIR $APPTAINER_TMPDIR"
fi

mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"

typeset -a images_to_process
if [[ -n "$selected_base_image" ]]; then
	images_to_process=("$selected_base_image")
else
	images_to_process=($BASE_IMAGES)
fi

echo "Images to Process: ${images_to_process[@]}"

for image in $=images_to_process; do
	echo
	echo Processing image $image
	for arch in $=archs; do
		echo Processing arch $arch
		echo
		this_image="$registry_base_address":"$g4version"-"$image"-"$(get_version_tag "$image")"-"$arch"
		osname="$(get_osname "$image" "$arch")"
		# if archilinux, skip arm64 for now
		if [[ "$image" == *"archlinux"* && "$arch" == "arm64" ]]; then
			print "Skipping archlinux arm64"
			continue
		fi
		copy_to_cvmfs "$this_image" "$osname" "$arch"
	done
done
