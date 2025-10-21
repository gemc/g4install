#!/bin/zsh

# Sync $SIM_HOME to jlab /cvmfs out of GHCR images using Apptainer

set -euo pipefail
outdir=/scigroup/cvmfs/geant4/g4install
container_dir=

g4version="11.3.2"
registry_base_address="ghcr.io/gemc/g4install"

typeset -a BASE_IMAGES=(
	ubuntu
	fedora
	debian
	almalinux
	archlinux
)

# function that returns the version tag for a given base image
get_version_tag() {
	local base_image="$1"
	case "$base_image" in
		ubuntu) echo "24.04" ;;
		fedora) echo "40" ;;
		debian) echo "12" ;;
		almalinux) echo "9.4" ;;
		archlinux) echo "latest" ;;
		*) print "Unknown base image: $base_image" >&2; exit 1 ;;
	esac
}

get_gcc_version() {
	local base_image="$1"
	case "$base_image" in
		ubuntu) echo "12" ;;
		fedora) echo "13" ;;
		debian) echo "12" ;;
		almalinux) echo "11" ;;
		archlinux) echo "latest" ;;
		*) print "Unknown base image: $base_image" >&2; exit 1 ;;
	esac
}

get_osname() {
	local base_image="$1"
	local arch=$2
	local gcc="$(get_gcc_version "$base_image")"
	echo $base_image-gcc${gcc}-${arch}

}

typeset -a archs=(amd64 arm64)

copy_to_cvmfs() {
	local src_image="$1"
	local dest_dir="$2"
	print "Copying from $src_image to $dest_dir"

	# create dest dir if it doesn't exist
	mkdir -p "$dest_dir"

	# use apptainer to pull the image and save it to dest dir
	apptainer pull --force --name "$dest_dir/image.sif" "docker://$src_image"

}

# caches on /work
export APPTAINER_CACHEDIR=/work/clas12/ungaro/apptainer-cache
export APPTAINER_TMPDIR=/work/clas12/ungaro/apptainer-tmp   # optional but helpful
export APPTAINER_MESSAGELEVEL=error   # or 'quiet'
#mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"

for image in $=BASE_IMAGES; do
	for arch in $=archs; do
		this_image="$registry_base_address":"$g4version"-"$image"-"$(get_version_tag "$image")"-"$arch"
		# if archilinux, skip arm64 for now
		if [[ "$image" == *"archlinux"* && "$arch" == "arm64" ]]; then
			print "Skipping archlinux arm64"
			continue
		fi
		print "Syncing image ${this_image}"

	done
done
