#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/env.sh"

build_matrix() {

	# g4 is now a space-separated list (e.g. "11.3.2 11.4.0 dev")
	local g4_list
	g4_list="$(get_geant4_tags)"

	# Split into a bash array on whitespace
	local -a g4_tags
	read -r -a g4_tags <<<"$g4_list"

	local body="" sep="" pair os ver g4
	for g4 in "${g4_tags[@]}"; do

		local  root meson novnc
		root="$(get_root_tag $g4)"
		meson="$(get_meson_tag $g4)"
		novnc="$(get_novnc_tag $g4)"

		for pair in "${OS_VERSIONS[@]}"; do
			os="${pair%%=*}"
			ver="${pair#*=}"

			body+=${sep}"{\"image\":\"${os}\",\"image_tag\":\"${ver}\",\"geant4_tag\":\"${g4}\",\"root_tag\":\"${root}\",\"meson_tag\":\"${meson}\",\"novnc_tag\":\"${novnc}\"}"
			sep=","
		done
	done

	local json="{\"include\":[${body}]}"
	if command -v jq >/dev/null 2>&1; then
		printf '%s' "$json" | jq .
	else
		printf '%s' "$json"
	fi
}

# Build a clean GHCR image ref: ghcr.io/<owner>/<repo>
build_image_ref() {
	# Owner from env (Actions sets this). Fallback for local runs.
	local owner="${GITHUB_REPOSITORY_OWNER:-gemc}"

	# Repo name = LAST segment of GITHUB_REPOSITORY (strip any "owner/" prefix).
	# Fallback to a default if env is missing during local runs.
	local repo_full="${GITHUB_REPOSITORY:-gemc/g4install}"
	local repo="${repo_full##*/}" # strip anything up to and including the last slash

	# Lowercase both parts (GHCR requires lowercase)
	printf 'ghcr.io/%s/%s' "$(lc "$owner")" "$(lc "$repo")"
}

main() {
	local image_ref
	image_ref="$(build_image_ref)"

	if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
		local DELIM="MATRIX_$(date +%s%N)"
		{
			echo  "matrix<<$DELIM"
			build_matrix
			echo  "$DELIM"
			echo  "image=$image_ref"
		} >>"$GITHUB_OUTPUT"
	else
		# Local run: only print the matrix (no trailing image line)
		build_matrix
		echo
		echo "images located at: $image_ref"
	fi
}

main "$@"
