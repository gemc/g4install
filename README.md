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

### 3. Build Geant4 11.4.2

```shell
module load sim_system
install_geant4 11.4.2
```

The installer builds CLHEP and Xerces-C when needed, downloads the Geant4 datasets, and installs everything
under `$HOME/g4install/<platform>/`. The build can take a while and requires several gigabytes of disk space.

### 4. Load and verify the installation

```shell
module load geant4/11.4.2
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

module switch geant4/11.3.2 geant4/11.4.2
# Build or test against Geant4 11.4.2.
```

<br/>

## Binary tarballs

CI publishes relocatable tarballs to the rolling [development release][dev-release]. Choose the archive matching
your OS and CPU architecture, extract it into an empty directory, install the Geant4 datasets, and source the
generated environment file:

```shell
mkdir -p "$HOME/geant4-11.4.2"
tar -xzf geant4-11.4.2-ubuntu-24.04-amd64.tar.gz \
  -C "$HOME/geant4-11.4.2" --strip-components=1
cd "$HOME/geant4-11.4.2"
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
docker run --rm -it ghcr.io/gemc/g4install:11.4.2-ubuntu-24.04 bash -li
```

Start the default noVNC desktop, then open <http://localhost:6080>:

```shell
docker run --rm -it \
  -p 6080:6080 -p 5900:5900 \
  -e X11VNC_PASSWORD=change-me \
  -e VNC_BIND=0.0.0.0 \
  -e GEOMETRY=1920x1200 \
  ghcr.io/gemc/g4install:11.4.2-ubuntu-24.04
```

> [!NOTE]
> Change the VNC password before exposing either port beyond your local machine.

### Supported images

#### Geant4 11.4.2

| Base image | Registry tag | Modes | `amd64` | `arm64` |
| --- | --- | --- | :---: | :---: |
| Ubuntu 24.04 | `ghcr.io/gemc/g4install:11.4.2-ubuntu-24.04` | batch + noVNC | yes | yes |
| Ubuntu 26.04 | `ghcr.io/gemc/g4install:11.4.2-ubuntu-26.04` | batch + noVNC | yes | yes |
| Fedora 44 | `ghcr.io/gemc/g4install:11.4.2-fedora-44` | batch + noVNC | yes | yes |
| AlmaLinux 9.4 | `ghcr.io/gemc/g4install:11.4.2-almalinux-9.4` | batch + noVNC | yes | yes |
| AlmaLinux 10 | `ghcr.io/gemc/g4install:11.4.2-almalinux-10` | batch | yes | yes |
| Debian 13 | `ghcr.io/gemc/g4install:11.4.2-debian-13` | batch + noVNC | yes | yes |
| Arch Linux latest | `ghcr.io/gemc/g4install:11.4.2-archlinux-latest` | batch + noVNC | yes | no |

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

### Binary-tarball prerequisites

<details>
<summary>Fedora 44 and AlmaLinux 9.4/10</summary>

```shell
sudo dnf install -y --allowerasing \
  ca-certificates curl gzip tar expat \
  sqlite-libs zlib libX11 libXext libXmu \
  libXt mesa-libEGL mesa-libGL qt6-qtbase qt6-qtsvg \
  tbb
```

</details>

<details>
<summary>Ubuntu 24.04/26.04</summary>

```shell
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata \
  ca-certificates curl gzip tar libexpat1 \
  libsqlite3-0 zlib1g libegl1 libgl1 libx11-6 \
  libxext6 libxmu6 libxt6 libqt6core6t64 libqt6gui6 \
  libqt6widgets6 libqt6opengl6 libqt6openglwidgets6 libqt6svg6 libtbb12
```

</details>

<details>
<summary>Debian 13</summary>

```shell
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends tzdata \
  ca-certificates curl gzip tar libexpat1 \
  libsqlite3-0 zlib1g libegl1 libgl1 libx11-6 \
  libxext6 libxmu6 libxt6 libqt6core6t64 libqt6gui6 \
  libqt6widgets6 libqt6opengl6 libqt6openglwidgets6 libqt6svg6 libtbb12
```

</details>

<details>
<summary>Arch Linux</summary>

```shell
sudo pacman-key --init && sudo pacman-key --populate
sudo pacman -Sy --noconfirm archlinux-keyring
sudo pacman -Syu --noconfirm --needed \
  ca-certificates curl gzip tar expat \
  sqlite zlib libx11 libxext libxmu \
  libxt mesa qt6-base qt6-svg tbb
```

</details>

<details>
<summary>macOS (Apple Silicon)</summary>

```shell
brew install qt
brew install --cask xquartz
```

</details>

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
