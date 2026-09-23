#!/usr/bin/env bash
set -euo pipefail

source "ci/env.sh"

image_suffix_for() {
    local os="$1"
    local version="$2"

    printf '%s-%s' "$os" "$version"
}

pretty_os_label() {
    local os="$1"
    local version="$2"

    case "$os" in
        ubuntu) printf 'Ubuntu %s' "$version" ;;
        fedora) printf 'Fedora %s' "$version" ;;
        almalinux) printf 'AlmaLinux %s' "$version" ;;
        debian) printf 'Debian %s' "$version" ;;
        archlinux) printf 'Arch Linux %s' "$version" ;;
        *) printf '%s %s' "$os" "$version" ;;
    esac
}

arch_support() {
    local os="$1"
    local architecture="$2"

    if [[ "$os" == "archlinux" && "$architecture" == "arm64" ]]; then
        printf 'no'
    else
        printf 'yes'
    fi
}

image_mode() {
    local os="$1"
    local version="$2"

    if [[ "$os" == "almalinux" && "$version" == 10* ]]; then
        printf 'batch'
    else
        printf 'batch + noVNC'
    fi
}

print_image_table() {
    local geant4_version="$1"

    cat <<'EOF'
| Base image | Registry tag | Modes | `amd64` | `arm64` |
| --- | --- | --- | :---: | :---: |
EOF

    local os_version os version label suffix mode amd64 arm64
    for os_version in "${OS_VERSIONS[@]}"; do
        os="${os_version%%=*}"
        version="${os_version#*=}"
        label="$(pretty_os_label "$os" "$version")"
        suffix="$(image_suffix_for "$os" "$version")"
        mode="$(image_mode "$os" "$version")"
        amd64="$(arch_support "$os" amd64)"
        arm64="$(arch_support "$os" arm64)"

        printf '| %s | `ghcr.io/gemc/g4install:%s-%s` | %s | %s | %s |\n' \
            "$label" "$geant4_version" "$suffix" "$mode" "$amd64" "$arm64"
    done
}

print_binary_packages() {
    local image="$1"
    local version="$2"
    local prefix="$3"
    local packages
    local -a package_array

    packages="$(python3 ci/binary_packages.py --image "$image" --tag "$version")"
    read -r -a package_array <<< "$packages"

    printf '%s' "$prefix"
    local index
    for index in "${!package_array[@]}"; do
        if (( index % 5 == 0 )); then
            printf ' \\\n  '
        else
            printf ' '
        fi
        printf '%s' "${package_array[$index]}"
    done
    printf '\n'
}

print_binary_prerequisites() {
    cat <<'EOF'
<details>
<summary>Fedora 44 and AlmaLinux 9.4/10</summary>

```shell
EOF
    print_binary_packages fedora 44 "sudo dnf install -y --allowerasing"
    cat <<'EOF'
```

</details>

<details>
<summary>Ubuntu 24.04/26.04</summary>

```shell
sudo apt-get update
EOF
    print_binary_packages ubuntu 24.04 \
        "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata"
    cat <<'EOF'
```

</details>

<details>
<summary>Debian 13</summary>

```shell
sudo apt-get update
EOF
    print_binary_packages debian 13 \
        "sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata"
    cat <<'EOF'
```

</details>

<details>
<summary>Arch Linux</summary>

```shell
sudo pacman-key --init && sudo pacman-key --populate
sudo pacman -Sy --noconfirm archlinux-keyring
EOF
    print_binary_packages archlinux latest "sudo pacman -Syu --noconfirm --needed"
    cat <<'EOF'
```

</details>

<details>
<summary>macOS (Apple Silicon)</summary>

```shell
brew install qt
brew install --cask xquartz
```

</details>
EOF
}

print_source_prerequisites() {
    cat <<'EOF'
<details>
<summary>Fedora 44</summary>

```shell
sudo dnf install -y git make cmake gcc-c++ zsh environment-modules \
  expat-devel zlib-devel qt6-qtbase-devel \
  mesa-libGL-devel mesa-libGLU-devel libX11-devel libXpm-devel libXft-devel \
  libXt-devel libXmu-devel libXrender-devel
```

</details>

<details>
<summary>AlmaLinux 9.4</summary>

```shell
sudo dnf install -y 'dnf-command(config-manager)'
sudo dnf config-manager --set-enabled crb
sudo dnf install -y almalinux-release-synergy
sudo dnf install -y git make cmake gcc-c++ zsh environment-modules \
  expat-devel zlib-devel qt6-qtbase-devel \
  mesa-libGL-devel mesa-libGLU-devel libX11-devel libXpm-devel libXft-devel \
  libXt-devel libXmu-devel libXrender-devel
```

</details>

<details>
<summary>AlmaLinux 10</summary>

```shell
sudo dnf install -y 'dnf-command(config-manager)'
sudo dnf config-manager --set-enabled crb
sudo dnf install -y git make cmake gcc-c++ zsh environment-modules \
  expat-devel zlib-devel qt6-qtbase-devel \
  mesa-libGL-devel mesa-libGLU-devel libX11-devel libXpm-devel libXft-devel \
  libXt-devel libXmu-devel libXrender-devel
```

</details>

<details>
<summary>Ubuntu 24.04/26.04</summary>

```shell
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  git make cmake g++ zsh environment-modules libexpat1-dev zlib1g-dev \
  qt6-base-dev libqt6opengl6 libqt6openglwidgets6 qt6-base-dev-tools \
  libgl1-mesa-dev libglu1-mesa-dev libx11-dev libxpm-dev libxft-dev \
  libxt-dev libxmu-dev libxrender-dev
```

</details>

<details>
<summary>Debian 13</summary>

```shell
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  git make cmake g++ zsh environment-modules libexpat1-dev zlib1g-dev \
  qt6-base-dev libqt6opengl6-dev libqt6openglwidgets6 qt6-base-dev-tools \
  libgl1-mesa-dev libglu1-mesa-dev libx11-dev libxpm-dev libxft-dev \
  libxt-dev libxmu-dev libxrender-dev
```

</details>

<details>
<summary>macOS 26 (Apple Silicon)</summary>

Install the Xcode Command Line Tools first, then install the remaining dependencies with Homebrew:

```shell
xcode-select --install
brew install qt cmake modules
brew install --cask xquartz
export MODULESHOME="$(brew --prefix modules)"
source "$MODULESHOME/init/zsh"
```

</details>
EOF
}

render_template() {
    local geant4_version="$1"
    local image_suffix="$2"
    local line

    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line//@GEANT4_VERSION@/$geant4_version}"
        line="${line//@IMAGE_SUFFIX@/$image_suffix}"
        printf '%s\n' "$line"
    done
}

generate_readme() {
    local geant4_versions latest_geant4_version first_os_version first_os first_version first_suffix
    geant4_versions="$(get_geant4_tags)"
    latest_geant4_version="${geant4_versions%% *}"
    first_os_version="${OS_VERSIONS[0]}"
    first_os="${first_os_version%%=*}"
    first_version="${first_os_version#*=}"
    first_suffix="$(image_suffix_for "$first_os" "$first_version")"

    {
        cat <<'EOF' | render_template "$latest_geant4_version" "$first_suffix"
# g4install

[![Deploy images][deploy-badge]][deploy]
[![Linux tarballs][binary-tarballs-badge]][binary-tarballs]
[![macOS tarball][macos-tarball-badge]][macos-tarball]
[![Nightly release][nightly-badge]][nightly]
[![Registry cleanup][cleanup-badge]][cleanup]

`g4install` builds and manages [Geant4][geant4] with versioned [Environment Modules][modules]. It supports
side-by-side Geant4 installations, relocatable binary tarballs, and multi-architecture container images.

<br/>

## Highlights

- Install and switch between Geant4 versions without changing global system paths.
- Build matched CLHEP and Xerces-C dependencies automatically.
- Use the same module layout on Linux and macOS.
- Pull CI-built Linux images for `amd64` and `arm64`.
- Download relocatable Linux and Apple Silicon tarballs from the rolling development release.

<br/>

## Installation from source

Building locally requires a C++ compiler, CMake, Git, Z shell, Environment Modules, Qt 6, X11/OpenGL headers,
expat, and zlib. Copy-and-paste commands for each tested platform are in the
[source-build prerequisites](#source-build-prerequisites) appendix.

### 1. Install the prerequisites

Run the command for your operating system from the appendix, then start a new login shell so that the
`module` command is initialized.

### 2. Clone and register the modulefiles

The commands below install the repository in `$HOME/g4install`. Choose another absolute path if preferred.

```shell
git clone https://github.com/gemc/g4install.git "$HOME/g4install"
module use "$HOME/g4install/modules"
module avail geant4
```

Add the `module use` line to `.bashrc` or `.zshrc` to make the modulefiles available in future shells.

### 3. Build Geant4 @GEANT4_VERSION@

```shell
module load sim_system
install_geant4 @GEANT4_VERSION@
```

The installer builds CLHEP and Xerces-C when needed, downloads the Geant4 datasets, and installs everything
under `$HOME/g4install/<platform>/`. The build can take a while and requires several gigabytes of disk space.

### 4. Load and verify the installation

```shell
module load geant4/@GEANT4_VERSION@
geant4-config --version
command -v geant4-config
```

<br/>

## Compile a Geant4 example

With the Geant4 module loaded, compile the bundled B5 example in a separate build directory:

```shell
mkdir build_B5
cd build_B5
cmake $G4INSTALL/data/Geant4/examples/basic/B5
make -j4
```

<br/>

## Switching Geant4 versions

Installed versions coexist in separate directories. Use an explicit old and new module name when switching:

```shell
module load geant4/11.3.2
# Build or test against Geant4 11.3.2.

module switch geant4/11.3.2 geant4/@GEANT4_VERSION@
# Build or test against Geant4 @GEANT4_VERSION@.
```

<br/>

## Binary tarballs

CI publishes relocatable tarballs to the rolling [development release][dev-release]. Choose the archive matching
your OS and CPU architecture, extract it into an empty directory, install the Geant4 datasets, and source the
generated environment file:

```shell
mkdir -p "$HOME/geant4-@GEANT4_VERSION@"
tar -xzf geant4-@GEANT4_VERSION@-ubuntu-24.04-amd64.tar.gz \
  -C "$HOME/geant4-@GEANT4_VERSION@" --strip-components=1
cd "$HOME/geant4-@GEANT4_VERSION@"
./install_geant4_data.sh
source ./geant4.env
geant4-config --version
```

Install the small set of shared-library dependencies from the
[binary-tarball prerequisites](#binary-tarball-prerequisites) appendix before using a tarball. Dataset
installation downloads several gigabytes; set `GEANT4_DATA_BASE_URL` only when using an approved mirror.

<br/>

## Container images

Images include Geant4 and ROOT and are published in the [GitHub Container Registry][registry]. All listed tags
support batch operation. AlmaLinux 10 is headless; the other images also provide VNC/noVNC visualization.

Run an interactive login shell:

```shell
docker run --rm -it ghcr.io/gemc/g4install:@GEANT4_VERSION@-@IMAGE_SUFFIX@ bash -li
```

Start the default noVNC desktop, then open <http://localhost:6080>:

```shell
docker run --rm -it \
  -p 6080:6080 -p 5900:5900 \
  -e X11VNC_PASSWORD=change-me \
  -e VNC_BIND=0.0.0.0 \
  -e GEOMETRY=1920x1200 \
  ghcr.io/gemc/g4install:@GEANT4_VERSION@-@IMAGE_SUFFIX@
```

> [!NOTE]
> Change the VNC password before exposing either port beyond your local machine.

### Supported images

EOF

        local geant4_version
        for geant4_version in $geant4_versions; do
            printf '#### Geant4 %s\n\n' "$geant4_version"
            print_image_table "$geant4_version"
            printf '\n'
            cat <<'EOF' | render_template "$geant4_version" "$first_suffix"
##### Special debug image

`ghcr.io/gemc/g4install:@GEANT4_VERSION@-ubuntu-26.04-debug` is a special image for debugging and profiling.
Geant4 and CLHEP are built with debug symbols using `RelWithDebInfo`, which keeps optimization enabled.
It supports batch and VNC/noVNC operation, is available for `amd64` only, and has no binary tarball.
On `arm64` hosts, use `--platform=linux/amd64` with emulation:

```shell
docker run --rm -it --platform=linux/amd64 ghcr.io/gemc/g4install:@GEANT4_VERSION@-ubuntu-26.04-debug bash -li
```

EOF
        done

        cat <<'EOF'
<br/>

## Troubleshooting

### `module: command not found`

Start a new login shell after installing Environment Modules. If the command is still unavailable, initialize
the package explicitly using the path supplied by your distribution or Homebrew.

### `module avail geant4` shows nothing

Register the repository's `modules` directory, not the repository root:

```shell
module use "$HOME/g4install/modules"
module avail geant4
```

### The wrong Geant4 version is active

Reset the module environment and load the desired version:

```shell
module purge
module use "$HOME/g4install/modules"
module load geant4/<version>
module list
geant4-config --version
```

<br/>

## Appendix: prerequisites

The source-build lists match the libraries enabled by `install_geant4`. The binary lists are generated from
`ci/binary_packages.py`, the runtime-package source of truth used by CI. Run package-manager commands with an
account that has administrative privileges.

### Source-build prerequisites

EOF

        print_source_prerequisites

        cat <<'EOF'

### Binary-tarball prerequisites

EOF

        print_binary_prerequisites

        cat <<'EOF'

[binary-tarballs]: https://github.com/gemc/g4install/actions/workflows/binary_tarballs.yml
[binary-tarballs-badge]: https://github.com/gemc/g4install/actions/workflows/binary_tarballs.yml/badge.svg
[cleanup]: https://github.com/gemc/g4install/actions/workflows/cleanup.yml
[cleanup-badge]: https://github.com/gemc/g4install/actions/workflows/cleanup.yml/badge.svg
[deploy]: https://github.com/gemc/g4install/actions/workflows/deploy.yml
[deploy-badge]: https://github.com/gemc/g4install/actions/workflows/deploy.yml/badge.svg
[dev-release]: https://github.com/gemc/g4install/releases/tag/dev
[geant4]: https://geant4.web.cern.ch
[macos-tarball]: https://github.com/gemc/g4install/actions/workflows/macos_tarball.yml
[macos-tarball-badge]: https://github.com/gemc/g4install/actions/workflows/macos_tarball.yml/badge.svg
[modules]: https://modules.readthedocs.io
[nightly]: https://github.com/gemc/g4install/actions/workflows/dev_release.yml
[nightly-badge]: https://github.com/gemc/g4install/actions/workflows/dev_release.yml/badge.svg
[registry]: https://github.com/gemc/g4install/pkgs/container/g4install
EOF
    } > README.md
}

generate_readme
