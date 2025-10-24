#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/env.sh"

build_matrix() {
  local g4 root meson novnc
  g4="$(get_geant4_tag)"
  root="$(get_root_tag)"
  meson="$(get_meson_tag)"
  novnc="$(get_novnc_tag)"

  local body="" sep="" pair os ver baseimage img
  for pair in "${OS_VERSIONS[@]}"; do
    os="${pair%%=*}"
    ver="${pair#*=}"
    baseimage="${g4}-${os}-${ver}"
    img="${os}-${ver}" # don't use the name 'image' here to avoid clobbering caller vars
    body+=${sep}"{\"image\":\"${os}\",\"image_tag\":\"${ver}\",\"geant4_tag\":\"${g4}\",\"root_tag\":\"${root}\",\"meson_tag\":\"${meson}\",\"novnc_tag\":\"${novnc}\"}"
    sep=","
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
      echo "matrix<<$DELIM"
      build_matrix
      echo "$DELIM"
      echo "image=$image_ref"
    } >>"$GITHUB_OUTPUT"
  else
    # Local run: only print the matrix (no trailing image line)
    build_matrix
    echo
    echo "images located at: $image_ref"
  fi
}

main "$@"