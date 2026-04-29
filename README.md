# g4install


Environment modules, installation scripts and [container images](https://github.com/gemc/g4install/pkgs/container/g4install), 
for **Geant4** — with **seamless coexistence of multiple Geant4 versions**.

This repository provides:

- **Environment Modules** + **installation scripts** for [Geant4](https://github.com/Geant4/geant4.git)
- **Multi-architecture Docker images** vi CI(`amd64`, `arm64`)

<br/>

## Why use g4install?

g4install is designed to let you:

- Install **multiple Geant4 versions side-by-side**
- Switch between versions quickly using `module load` / `module switch`
- Automatically install and load required dependencies (CLHEP, Xerces-C)
- Use an easy, consistent, shell independent environment

This is especially useful:

- one reliable command to install the latest or past Geant4 versions and its dependencies
- validating applications against different Geant4 releases (e.g. `11.3.x` vs `11.4.x`)

<br/>

## Local Installation

### Prerequisites

Install **Environment Modules**:

- **Linux**: install `environment-modules` using your package manager
- **macOS**: `brew install modules`

### 1. Clone and enable g4install modules

Here we use `/path/to/g4install` as an example. 

```shell
git clone https://github.com/gemc/g4install
module use /path/to/g4install
```

We recommend adding the `module use` command to your 
shell init script, like `.bashrc` or `.cshrc`. 


You can now list supported Geant4 versions:

```shell
module avail geant4
```

### 2. Install a Geant4 version (example: 11.4.1  )

```shell
module load sim_system
install_geant4 11.4.1
```

### 3. Load a Geant4 version

```shell
module load geant4/11.4.1
```


<br/>

## Seamless Multi-Version Switching

One of the main features of `g4install` is the ability to keep multiple versions installed and switch between them without conflicts.

```shell
module load geant4/11.3.2
# build/test project A

module switch geant4/11.4.1
# build/test project B
```

<br/>


## Docker Images

Images are built by CI and published to the
[G4Install GitHub Container Registry](https://github.com/gemc/g4install/pkgs/container/g4install).

### Highlights

* **Multi-arch tags** (same tag works on Intel and Apple Silicon)
* **Batch mode** and **GUI mode** (VNC / noVNC)
* Includes **Geant4** and **ROOT**

### Batch mode example

```shell
docker run --rm -it ghcr.io/gemc/g4install:11.4.0-ubuntu-24.04 bash -li
```

### GUI mode example (VNC / noVNC)

```shell
VPORTS=(-p 6080:6080 -p 5900:5900)
VNC_PASS=(-e X11VNC_PASSWORD=change-me)
VNC_BIND=(-e VNC_BIND=0.0.0.0)
GEO_FLAGS=(-e GEOMETRY=1920x1200)

docker run --rm -it $VPORTS $VNC_BIND $VNC_PASS $GEO_FLAGS ghcr.io/gemc/g4install:11.4.0-ubuntu-24.04
```

<br/>

## Supported Images (current examples)

### Latest Geant4 (11.4.1)

| OS               | Registry address                                  | arm64 | amd64 |
|:-----------------|:--------------------------------------------------| :---: | :---: |
| ubuntu 24.04     | `ghcr.io/gemc/g4install:11.4.1-ubuntu24         ` |   yes |   yes |
| fedora 42        | `ghcr.io/gemc/g4install:11.4.1-fedora42         ` |   yes |   yes |
| almalinux 9.4    | `ghcr.io/gemc/g4install:11.4.1-almalinux9.4     ` |   yes |   yes |
| debian 13        | `ghcr.io/gemc/g4install:11.4.1-debian-13        ` |   yes |   yes |
| archlinux latest | `ghcr.io/gemc/g4install:11.4.1-archlinux-latest ` |    no |   yes |

To list all suported version check 
the [github registry for g4install](https://github.com/gemc/g4install/pkgs/container/g4install/versions)



<br/>




## Troubleshooting

### `module: command not found`

Environment Modules is not installed or not initialized in the current shell.

* Install `environment-modules` (Linux) or `modules` (macOS/Homebrew)
* Start a login shell or source your shell initialization files

### `module avail geant4` shows nothing

Confirm the repository is added to the module search path:

```shell
module use /path/to/g4install
```

### The wrong Geant4 version is being picked up

Check current shell state:

```shell
module list
which geant4-config
geant4-config --version
```

If needed:

```shell
module purge
module use /path/to/g4install
module load geant4/<desired-version>
```




<br/>

## CI Status

[![Build Geant4 Images](https://github.com/gemc/g4install/actions/workflows/docker.yml/badge.svg)](https://github.com/gemc/g4install/actions/workflows/docker.yml)




