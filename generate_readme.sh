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
    local g4tag=$1

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
    local g4tags latest_g4tag

    g4tags="$(get_geant4_tags)"              # space-separated list
    latest_g4tag="${g4tags%% *}"             # first token is treated as "latest"

    {
        cat <<EOF



This repository provides:

- module environment for geant4 and installation scripts
- geant4 docker containers registry for both \`amd64\` and \`arm64\` architectures.
- CVMFS distribution of Geant4

<br/>

> [!NOTE]
> Supported Geant4 Versions:
$(all_supported_geant4_versions)

<hr/><br/>


## Built Images

Docker Containers Images are created by Continuous Integration and published to the
[GitHub registry](https://github.com/gemc/g4install/pkgs/container/g4install).

- The images are a stitch of both architectures, so \`docker run\` does not need additional platform directives or emulations:
the same command can be used on intel/silicon cpus.
- The images can be run in batch mode or with GUI (noVNC, using a browser or VNC client).

The images contain Geant4 and ROOT.
Geant4 libraries are distributed on CVMFS at \`/cvmfs/jlab.opensciencegrid.org/geant4/g4install\`


### Running Images in batch mode

Example:

\`\`\`
docker run --rm -it ghcr.io/gemc/g4install:11.4.0-ubuntu-24.04 bash -li
\`\`\`

### Running Images in graphical mode with VNC/noVNC

Use these convenience variables:

\`\`\`
VPORTS=(-p 6080:6080 -p 5900:5900)
VNC_PASS=(-e X11VNC_PASSWORD=change-me)
VNC_BIND=(-e VNC_BIND=0.0.0.0)
GEO_FLAGS=(-e GEOMETRY=1920x1200)
\`\`\`


Then run docker with:

\`\`\`
docker run --rm -it \$VPORTS \$VNC_BIND \$VNC_PASS \$GEO_FLAGS ghcr.io/gemc/g4install:11.4.0-ubuntu-24.04
\`\`\`

The supported images are listed below.

<br/>


EOF

        # Insert a table for each Geant4 version from get_geant4_tags()
        for g4tag in $g4tags; do
        	echo "### Geant4 $g4tag:"
            print_table "$g4tag"
            echo "<br/>"
            echo    # blank line between tables (Markdown readability)
        done

        cat <<EOF

## Status Badges:

[![Build Geant4 Images](https://github.com/gemc/g4install/actions/workflows/docker.yml/badge.svg)](https://github.com/gemc/g4install/actions/workflows/docker.yml)
EOF
    } > README.md
}

# actually run it if this script is executed directly
generate_readme
