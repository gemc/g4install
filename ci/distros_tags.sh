#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/env.sh"

build_matrix_build() {

	local g4_list arch_list
	g4_list="$(get_geant4_tags)"
	arch_list="$(get_cpu_architectures)"

	local -a g4_tags arch_tags
	read -r -a g4_tags <<<"$g4_list"
	read -r -a arch_tags <<<"$arch_list"

	local body="" sep="" pair os ver
	for g4v in "${g4_tags[@]}"; do
		for cpuv in "${arch_tags[@]}"; do

			local root meson novnc platform runner suffix logs_dir
			root="$(get_root_tag "$g4v")"
			meson="$(get_meson_tag "$g4v")"
			novnc="$(get_novnc_tag "$g4v")"
			platform="linux/$cpuv"
			runner="$(get_runner "$cpuv")"
			suffix="-$cpuv"
			logs_dir="logs-$cpuv"

			for pair in "${OS_VERSIONS[@]}"; do
				os="${pair%%=*}"
				ver="${pair#*=}"

				# archlinux is amd64-only
				if [[ "$os" == "archlinux" && "$cpuv" == "arm64" ]]; then
					continue
				fi

				body+="${sep}{"
				body+="\"image\":\"${os}\","
				body+="\"image_tag\":\"${ver}\","
				body+="\"geant4_tag\":\"${g4v}\","
				body+="\"root_tag\":\"${root}\","
				body+="\"meson_tag\":\"${meson}\","
				body+="\"novnc_tag\":\"${novnc}\","
				body+="\"arch\":\"${cpuv}\","
				body+="\"platform\":\"${platform}\","
				body+="\"runner\":\"${runner}\","
				body+="\"suffix\":\"${suffix}\","
				body+="\"logs_dir\":\"${logs_dir}\""
				body+="}"
				sep=","
			done
		done
	done

	local json="{\"include\":[${body}]}"
	if command -v jq >/dev/null 2>&1; then
		printf '%s' "$json" | jq -c .
	else
		printf '%s' "$json"
	fi
}

build_matrix_manifest() {

	local g4_list
	g4_list="$(get_geant4_tags)"

	local -a g4_tags
	read -r -a g4_tags <<<"$g4_list"

	local body="" sep="" pair os ver
	for g4v in "${g4_tags[@]}"; do
		local root meson novnc
		root="$(get_root_tag "$g4v")"
		meson="$(get_meson_tag "$g4v")"
		novnc="$(get_novnc_tag "$g4v")"

		for pair in "${OS_VERSIONS[@]}"; do
			os="${pair%%=*}"
			ver="${pair#*=}"

			body+="${sep}{"
			body+="\"image\":\"${os}\","
			body+="\"image_tag\":\"${ver}\","
			body+="\"geant4_tag\":\"${g4v}\","
			body+="\"root_tag\":\"${root}\","
			body+="\"meson_tag\":\"${meson}\","
			body+="\"novnc_tag\":\"${novnc}\""
			body+="}"
			sep=","
		done
	done

	local json="{\"include\":[${body}]}"
	if command -v jq >/dev/null 2>&1; then
		# De-duplicate by the fields that define one manifest
		printf '%s' "$json" | jq -c '{
      include: (
        .include
        | unique_by([.geant4_tag,.image,.image_tag,.root_tag,.meson_tag,.novnc_tag])
      )
    }'
	else
		# No jq available: emit as-is (may include duplicates)
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


# the separate matrices are needed so that manifest is not run twice
main() {
	local image_ref
	image_ref="$(build_image_ref)"

	if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
		local DELIM_BUILD="MATRIX_BUILD_$(date +%s%N)"
		local DELIM_MANIFEST="MATRIX_MANIFEST_$(date +%s%N)"
		{
			echo "matrix_build<<$DELIM_BUILD"
			build_matrix_build
			echo "$DELIM_BUILD"

			echo "matrix_manifest<<$DELIM_MANIFEST"
			build_matrix_manifest
			echo "$DELIM_MANIFEST"

			echo "image=$image_ref"
		} >>"$GITHUB_OUTPUT"
	else
		echo "== matrix_build =="
		build_matrix_build
		echo
		echo "== matrix_manifest =="
		build_matrix_manifest
		echo
		echo "images located at: $image_ref"
	fi

}

main "$@"
