#!/usr/bin/env bash

# portable lowercasing (works on old bash, dash, zsh)
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

get_geant4_tag()       { echo "11.3.2"; }
get_root_tag()         { echo "v6-36-04"; }
get_meson_tag()        { echo "1.9.0"; }
get_novnc_tag()        { echo "v1.6.0"; }

all_supported_geant4_versions() {
  # space-separated list
  echo "-11.4.0-11.3.2";
  echo "-11.4.0-11.3.2";
}

# Single source of truth (order preserved)
OS_VERSIONS=(
  "ubuntu=24.04"
  "fedora=40"
  "almalinux=9.4"
  "debian=12"
  "archlinux=latest"
)