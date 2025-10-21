#!/bin/zsh

# Sync $SIM_HOME to jlab /cvmfs out of GHCR images using Apptainer

set -euo pipefail
outdir=/scigroup/cvmfs/geant4/g4install

typeset -a IMAGES=(
	ghcr.io/gemc/g4install:11.3.2-ubuntu-24.04
	ghcr.io/gemc/g4install:11.3.2-fedora-40
	ghcr.io/gemc/g4install:11.3.2-debian-12
	ghcr.io/gemc/g4install:11.3.2-almalinux-9.4
	ghcr.io/gemc/g4install:11.3.2-archlinux-latest
)

# caches on /work
export APPTAINER_CACHEDIR=/work/clas12/ungaro/apptainer-cache
export APPTAINER_TMPDIR=/work/clas12/ungaro/apptainer-tmp   # optional but helpful
export APPTAINER_MESSAGELEVEL=error   # or 'quiet'
mkdir -p "$APPTAINER_CACHEDIR" "$APPTAINER_TMPDIR"

[[ -x "$(command -v apptainer)" ]] || { print -u2 "apptainer not found"; exit 1; }

copy_rsync_bind() {
	local image="$1"
	outdir="$2"

	apptainer exec --bind "$outdir:/mnt" "docker://${image}" bash -lc '
    set -eu
    : "${SIM_HOME:?SIM_HOME not set in the image}"
    osname=$($SIM_HOME/../modules/util/osrelease.py)
    mkdir -p /mnt/$osname
    orig_dir="$SIM_HOME"/../"$osname"
	echo "Syncing from $orig_dir"
    rsync -aHAX --human-readable --info="name1,stats1,progress2"  "orig_dir" /mnt
  '
}

for image in $=IMAGES; do
	print "> ${image}"
	copy_rsync_bind "$image" "$outdir"
done

