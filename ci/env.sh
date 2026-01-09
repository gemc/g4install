#!/usr/bin/env bash

# portable lowercasing (works on old bash, dash, zsh)
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

get_geant4_tags() { echo "11.4.0 11.3.2"; } # space separated list.
get_cpu_architectures() { echo "arm64 amd64"; } # space separated list.
get_runner() {
	local arch=$1
	case "$arch" in
		"arm64") echo "ubuntu-24.04-arm" ;;
		"amd64") echo "ubuntu-latest" ;;
		*)
			echo   "ERROR: unsupported arch $arch" >&2
			return                                                  2
			;;
	esac
}

# These take the Geant4 tag as input and return a dictionary entry.
# Return format: JSON-style key/value pair (no surrounding braces).
get_root_tag() {
	local g4="${1:?missing geant4 tag}"
	case "$g4" in
		11.4.0 | 11.3.2) echo "v6-36-04" ;;
		*)
			echo   "ERROR: unsupported Geant4 tag: $g4" >&2
			return                                                  2
			;;
	esac
}

get_meson_tag() {
	local g4="${1:?missing geant4 tag}"
	case "$g4" in
		11.4.0 | 11.3.2) echo "1.9.0" ;;
		*)
			echo   "ERROR: unsupported Geant4 tag: $g4" >&2
			return                                                  2
			;;
	esac
}

get_novnc_tag() {
	local g4="${1:?missing geant4 tag}"
	case "$g4" in
		11.4.0 | 11.3.2) echo "v1.6.0" ;;
		*)
			echo   "ERROR: unsupported Geant4 tag: $g4" >&2
			return                                                  2
			;;
	esac
}

all_supported_geant4_versions() {
	# markdown list
	echo "> - 11.4.0"
	echo "> - 11.3.2"
}

# Single source of truth (order preserved)
OS_VERSIONS=(
	"ubuntu=24.04"
	"fedora=40"
	"almalinux=9.4"
	"debian=12"
	"archlinux=latest"
)
