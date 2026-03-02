#!/usr/bin/env bash
set -euo pipefail

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

# pretty OS label for README tables
pretty_os_label() {
    local os="$1"
    local ver="$2"

    case "$os" in
        ubuntu)
            printf 'ubuntu %s' "$ver"
            ;;
        fedora)
            printf 'fedora %s' "$ver"
            ;;
        almalinux)
            printf 'almalinux %s' "$ver"
            ;;
        debian)
            printf 'debian %s' "$ver"
            ;;
        archlinux)
            printf 'archlinux %s' "$ver"
            ;;
        *)
            printf '%s %s' "$os" "$ver"
            ;;
    esac
}

# prints one markdown table for a Geant4 tag
print_table() {
    local g4tag="$1"

    cat <<'EOF'
| OS               | Pull Command                                                 | arm64 | amd64 |
| :--------------- | :----------------------------------------------------------- | :---: | :---: |
EOF

    for osv in "${OS_VERSIONS[@]}"; do
        local os="${osv%%=*}"
        local ver="${osv#*=}"

        local pretty_os
        pretty_os="$(pretty_os_label "$os" "$ver")"

        local suffix
        suffix="$(image_suffix_for "$os" "$ver")"

        local pull_cmd="docker pull ghcr.io/gemc/g4install:${g4tag}-${suffix}"
        local arm64
        arm64="$(arch_support "$os" arm64)"
        local amd64
        amd64="$(arch_support "$os" amd64)"

        printf '| %-16s | `%-59s` | %5s | %5s |\n' \
            "$pretty_os" \
            "$pull_cmd" \
            "$arm64" \
            "$amd64"
    done
}

generate_readme() {
    local g4tags latest_g4tag
    g4tags="$(get_geant4_tags)"
    latest_g4tag="${g4tags%% *}"

    {
        cat <<EOF
# g4install

Environment modules, installation scripts, container images, and CVMFS distribution for **Geant4** — with **seamless coexistence of multiple Geant4 versions**.

This repository provides:

- **Environment Modules** + **installation scripts** for [Geant4](https://github.com/Geant4/geant4.git)
- **Multi-architecture Docker images** (\`amd64\`, \`arm64\`)
- **CVMFS distribution** of Geant4 builds

<br/>

## Why use g4install?

\`g4install\` is designed to let you:

- Install **multiple Geant4 versions side-by-side**
- Switch between versions quickly using \`module load\` / \`module switch\`
- Automatically load required dependencies (CLHEP, Xerces-C)
- Use consistent environments across local systems, Docker, and CVMFS

This is especially useful:

- one reliable command to install the latest or past Geant4 versions and its dependencies
- validating applications against different Geant4 releases (e.g. \`11.3.x\` vs \`11.4.x\`)

<br/>

## Quick Start (Local Installation)

### Prerequisites

Install **Environment Modules**:

- **Linux**: install \`environment-modules\` using your package manager
- **macOS**: \`brew install modules\`

### Clone and enable g4install modules

\`\`\`shell
git clone https://github.com/gemc/g4install
module use /path/to/g4install
\`\`\`

### List available Geant4 versions

\`\`\`shell
module avail geant4
\`\`\`

### Install a Geant4 version (example: ${latest_g4tag})

\`\`\`shell
module load sim_system
install_geant4 ${latest_g4tag}
\`\`\`

### Load a Geant4 version

\`\`\`shell
module load geant4/${latest_g4tag}
\`\`\`

### Verify active version

\`\`\`shell
geant4-config --version
which geant4-config
\`\`\`

<br/>

## Seamless Multi-Version Switching

One of the main features of \`g4install\` is the ability to keep multiple versions installed and switch between them without conflicts.

\`\`\`shell
module load geant4/11.3.2
# build/test project A

module switch geant4/11.3.2 geant4/11.4.0
# build/test project B
\`\`\`

<br/>

---

<br/>

## Docker Images

Images are built by CI and published to the
[G4Install GitHub Container Registry](https://github.com/gemc/g4install/pkgs/container/g4install).

### Highlights

* **Multi-arch tags** (same tag works on Intel and Apple Silicon)
* **Batch mode** and **GUI mode** (VNC / noVNC)
* Includes **Geant4** and **ROOT**

### Batch mode example

\`\`\`shell
docker run --rm -it ghcr.io/gemc/g4install:${latest_g4tag}-ubuntu-24.04 bash -li
\`\`\`

### GUI mode example (VNC / noVNC)

\`\`\`shell
VPORTS=(-p 6080:6080 -p 5900:5900)
VNC_PASS=(-e X11VNC_PASSWORD=change-me)
VNC_BIND=(-e VNC_BIND=0.0.0.0)
GEO_FLAGS=(-e GEOMETRY=1920x1200)

docker run --rm -it \$VPORTS \$VNC_BIND \$VNC_PASS \$GEO_FLAGS ghcr.io/gemc/g4install:${latest_g4tag}-ubuntu-24.04
\`\`\`

---

## Supported Images (current examples)

EOF

        for g4tag in $g4tags; do
            printf '### Geant4 %s\n\n' "$g4tag"
            print_table "$g4tag"
            printf '\n'
        done

        cat <<'EOF'
<br/>

---

<br/>

## CVMFS Distribution

Geant4 libraries are distributed via CVMFS at:

```shell
/cvmfs/jlab.opensciencegrid.org/geant4/g4install
````

---

## Detailed Documentation

* **Multi-version workflow / switching guide**: `multi-version-workflow.md`

<br/>

---

<br/>

## CI Status

[![Build Geant4 Images](https://github.com/gemc/g4install/actions/workflows/docker.yml/badge.svg)](https://github.com/gemc/g4install/actions/workflows/docker.yml)
EOF
} > README.md
}

generate_readme