#!/usr/bin/env bash
set -euo pipefail

get_ubuntu_lts()       { echo "24.04"; }
get_fedora_latest()    { echo "40"; }
get_archlinux_latest() { echo "latest"; }
get_almalinux_latest() { echo "9.4"; }
get_debian_latest()    { echo "12"; }
get_geant4_tag()       { echo "11.3.2"; }

# Pretty-print with jq if available, otherwise emit compact JSON
build_matrix() {
	local json
	json=$(
		cat    <<EOF
{"include":[
  {"distro":"ubuntu","docker_from":"ubuntu:$(get_ubuntu_lts)","geant4_tag":"$(get_geant4_tag)"},
  {"distro":"fedora","docker_from":"fedora:$(get_fedora_latest)","geant4_tag":"$(get_geant4_tag)"},
  {"distro":"archlinux","docker_from":"archlinux:$(get_archlinux_latest)","geant4_tag":"$(get_geant4_tag)"},
  {"distro":"almalinux","docker_from":"almalinux:$(get_almalinux_latest)","geant4_tag":"$(get_geant4_tag)"},
  {"distro":"debian","docker_from":"debian:$(get_debian_latest)","geant4_tag":"$(get_geant4_tag)"}
]}
EOF
	)
	if command -v jq >/dev/null 2>&1; then
		printf '%s' "$json" | jq .
	else
		printf '%s' "$json"
	fi
}

# portable lowercasing (works on old bash, dash, zsh)
lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# Build a clean GHCR image ref: ghcr.io/<owner>/<repo>
build_image_ref() {
	# Owner from env (Actions sets this). Fallback for local runs.
	local owner="${GITHUB_REPOSITORY_OWNER:-gemc}"

	# Repo name = LAST segment of GITHUB_REPOSITORY (strip any "owner/" prefix).
	# Fallback to a default if env is missing during local runs.
	local repo_full="${GITHUB_REPOSITORY:-gemc/g4install}"
	local repo="${repo_full##*/}"

	# Lowercase both parts (GHCR requires lowercase)
	printf 'ghcr.io/%s/%s' "$(lc "$owner")" "$(lc "$repo")"
}

main() {
	# Resolve owner/repo and force lowercase (portable)
	local owner repo owner_lc repo_lc image
	owner="${GITHUB_REPOSITORY_OWNER:-JeffersonLab}"
	repo="${GITHUB_REPOSITORY##*/}"
	: "${repo:=geant4}"

	owner_lc="$(printf '%s' "$owner" | tr '[:upper:]' '[:lower:]')"
	repo_lc="$(printf '%s' "$repo" | tr '[:upper:]' '[:lower:]')"
	image="$(build_image_ref)"

	if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
		DELIM="MATRIX_$(date +%s%N)"
		{
			echo "matrix<<$DELIM"
			build_matrix
			echo "$DELIM"
			echo "image=$image"
		} >>"$GITHUB_OUTPUT"
	else
		build_matrix
		echo "# image=$image" >&2
	fi
}

main "$@"
