#!/usr/bin/env bash
set -euo pipefail

# ------------------------
# your existing env pieces
# ------------------------

source "ci/env.sh"

# helper to build one image tag suffix from os+ver
image_suffix_for() {
    local os="$1"
    local ver="$2"

    # major of "24.04" -> "24", "9.4" -> "9", "latest" -> "latest"
    local maj="${ver%%.*}"

    case "$os" in
        ubuntu)
            # ubuntu24
            printf '%s%s' "$os" "$maj"
            ;;
        fedora|almalinux)
            # fedora40 , almalinux9.4
            printf '%s%s' "$os" "$ver"
            ;;
        debian)
            # debian-12
            printf '%s-%s' "$os" "$ver"
            ;;
        archlinux)
            # archlinux-latest
            printf '%s-%s' "$os" "$ver"
            ;;
        *)
            printf '%s%s' "$os" "$ver"
            ;;
    esac
}

# arch matrix helper
arch_support() {
    local os="$1"
    local which="$2"  # "arm64" or "amd64"
    if [ "$os" = "archlinux" ] && [ "$which" = "arm64" ]; then
        printf 'no'
    else
        printf 'yes'
    fi
}

# this prints ONLY the Markdown table body (header + rows)
print_table() {
    local g4tag
    g4tag="$(get_geant4_tag)"

    # header
    cat <<'EOF'
|        OS        |                        Pull Command                        | arm64 |  amd64   |
|:----------------:|:----------------------------------------------------------:|:-----:|:--------:|
EOF

    # rows
    for osv in "${OS_VERSIONS[@]}"; do
        local os="${osv%%=*}"
        local ver="${osv#*=}"

        local pretty_os="${os} ${ver}"
        local suffix
        suffix="$(image_suffix_for "$os" "$ver")"

        local pull_cmd="docker pull ghcr.io/gemc/g4install:${g4tag}-${suffix}"
        local arm64="$(arch_support "$os" arm64)"
        local amd64="$(arch_support "$os" amd64)"

        # Format columns to look nice. Widths chosen to roughly match your example.
        printf '| %-15s | %-58s | %-5s | %-8s |\n' \
            "$pretty_os" \
            "$pull_cmd" \
            "$arm64" \
            "$amd64"
    done
}

# ------------------------
# README generator
# ------------------------

generate_readme() {
    local g4tag root_tag meson_tag novnc_tag
    g4tag="$(get_geant4_tag)"
    root_tag="$(get_root_tag)"
    meson_tag="$(get_meson_tag)"
    novnc_tag="$(get_novnc_tag)"

    {
        cat <<EOF
# g4install

## Geant4 Version: ${g4tag}

This repository provides:

- module environment for geant4 and installation scripts
- docker containers with Geant4 for both \`amd64\` and \`arm64\` architectures.
- cvmfs distribution of Geant4 on \`/cvmfs/jlab.opensciencegrid.org/geant4/g4install\`

## Built Images

Docker Containers Images are created by CI and published to GitHub registry.

- The images are a stitch of both architectures, so docker run does not need additional platform directives or emulations:
the same command can be used on intel/silicon cpus.
- The images can be run in batch mode or with GUI (noVNC, using a browser or VNC client).

The images contain, in addition to Geant4 ${g4tag}, the following software:

 - Geant4: ${g4tag}
 - ROOT: ${root_tag}
 - Meson: ${meson_tag}
 - noVNC: ${novnc_tag}

EOF

        # insert the table generated from OS_VERSIONS + g4tag
        print_table
        echo

        cat <<EOF

## Distribution

The container libraries are organized in subdirs of \`/cvmfs/jlab.opensciencegrid.org/geant4/g4install\` with names matching the docker tags above.

The following previous versions of Geant4 are also distributed on CVMFS:

 - $(geant4_versions_present_on_cvmfs)

## Status Badges:

[![Build Geant4 Images](https://github.com/gemc/g4install/actions/workflows/docker.yml/badge.svg)](https://github.com/gemc/g4install/actions/workflows/docker.yml)
EOF
    } > README.md
}

# actually run it if this script is executed directly
generate_readme
