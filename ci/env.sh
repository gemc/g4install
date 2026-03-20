#!/usr/bin/env bash

# portable lowercasing (works on old bash, dash, zsh)
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Single source of truth for supported Geant4 versions (space-separated)
supported_g4_versions="11.4.1"
root_version="v6-38-04"
meson_version="1.10.2"
novnc_version="v1.6.0"

# Returns success if $1 is in $supported_g4_versions
is_supported_g4_version() {
	local v="${1:?missing geant4 tag}"
	case " $supported_g4_versions " in
		*" $v "*) return 0 ;;
		*)    return 1 ;;
	esac
}

all_supported_geant4_versions() {
	# markdown list
	local v
	for v in $supported_g4_versions; do
		echo "> - $v"
	done
}

get_geant4_tags() { echo "$supported_g4_versions"; } # space separated list.
get_cpu_architectures() { echo "arm64 amd64"; } # space separated list.
get_runner() {
	local arch=$1
	case "$arch" in
		"arm64") echo "ubuntu-24.04-arm" ;;
		"amd64") echo "ubuntu-latest" ;;
		*)
			echo "ERROR: unsupported arch $arch" >&2
			return                                              2
			;;
	esac
}

# These take the Geant4 tag as input and return a dictionary entry.
# Return format: JSON-style key/value pair (no surrounding braces).
get_root_tag() {
	local g4="${1:?missing geant4 tag}"
	if is_supported_g4_version "$g4"; then
		echo $root_version
	else
		echo "ERROR: unsupported Geant4 tag: $g4" >&2
		return 2
	fi
}

get_meson_tag() {
	local g4="${1:?missing geant4 tag}"
	if is_supported_g4_version "$g4"; then
		echo $meson_version
	else
		echo "ERROR: unsupported Geant4 tag: $g4" >&2
		return 2
	fi
}

# https://github.com/novnc/novnc
get_novnc_tag() {
	local g4="${1:?missing geant4 tag}"
	if is_supported_g4_version "$g4"; then
		echo $novnc_version
	else
		echo "ERROR: unsupported Geant4 tag: $g4" >&2
		return 2
	fi
}

# Single source of truth (order preserved)
OS_VERSIONS=(
	"ubuntu=24.04"
	"fedora=42"
	"almalinux=9.4"
	"debian=13"
	"archlinux=latest"
)
