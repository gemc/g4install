

Environment modules, installation scripts, container images, and CVMFS distribution for **Geant4** — with **seamless coexistence of multiple Geant4 versions**.

This repository provides:

- **Environment Modules** + **installation scripts** for [Geant4](https://github.com/Geant4/geant4.git)
- **Multi-architecture Docker images** (`amd64`, `arm64`)
- **CVMFS distribution** of Geant4 builds

## Why use g4install?

`g4install` is designed to let you:

- Install **multiple Geant4 versions side-by-side**
- Switch between versions quickly using `module load` / `module switch`
- Automatically load required dependencies (CLHEP, Xerces-C)
- Use consistent environments across local systems, Docker, and CVMFS

This is especially useful when validating applications against different Geant4 releases (e.g. `11.3.x` vs `11.4.x`).

---

## Quick Start (Local Installation)

### Prerequisites

Install **Environment Modules**:

- **Linux**: install `environment-modules` using your package manager
- **macOS**: `brew install modules`

### Clone and enable modules

```shell
git clone https://github.com/gemc/g4install
module use /path/to/g4install
```

### List available Geant4 versions

```shell
module avail geant4
```

### Install a Geant4 version (example: 11.4.0)

```shell
module load sim_system
install_geant4 11.4.0
```

### Load a Geant4 version

```shell
module load geant4/11.4.0
```

Notice, this also loads:

* [CLHEP](https://gitlab.cern.ch/CLHEP/CLHEP)
* [Xerces-C](https://github.com/apache/xerces-c.git)

### Verify active version

```shell
geant4-config --version
which geant4-config
```

---

## Seamless Multi-Version Switching

One of the main features of `g4install` is the ability to keep multiple versions installed and switch between them without conflicts.

```shell
module load geant4/11.3.2
# build/test project A

module switch geant4/11.3.2 geant4/11.4.0
# build/test project B
```

---

## Docker Images

Images are built by CI and published to the
[GitHub Container Registry](https://github.com/gemc/g4install/pkgs/container/g4install).

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


---

## Supported Images (current examples)

### Geant4 11.4.0

| OS               | Pull Command                                                 | arm64 | amd64 |
| :--------------- | :----------------------------------------------------------- | :---: | :---: |
| ubuntu 24.04     | `docker pull ghcr.io/gemc/g4install:11.4.0-ubuntu24`         |  yes  |  yes  |
| fedora 40        | `docker pull ghcr.io/gemc/g4install:11.4.0-fedora40`         |  yes  |  yes  |
| almalinux 9.4    | `docker pull ghcr.io/gemc/g4install:11.4.0-almalinux9.4`     |  yes  |  yes  |
| debian 12        | `docker pull ghcr.io/gemc/g4install:11.4.0-debian-12`        |  yes  |  yes  |
| archlinux latest | `docker pull ghcr.io/gemc/g4install:11.4.0-archlinux-latest` |   no  |  yes  |

### Geant4 11.3.2

| OS               | Pull Command                                                 | arm64 | amd64 |
| :--------------- | :----------------------------------------------------------- | :---: | :---: |
| ubuntu 24.04     | `docker pull ghcr.io/gemc/g4install:11.3.2-ubuntu24`         |  yes  |  yes  |
| fedora 40        | `docker pull ghcr.io/gemc/g4install:11.3.2-fedora40`         |  yes  |  yes  |
| almalinux 9.4    | `docker pull ghcr.io/gemc/g4install:11.3.2-almalinux9.4`     |  yes  |  yes  |
| debian 12        | `docker pull ghcr.io/gemc/g4install:11.3.2-debian-12`        |  yes  |  yes  |
| archlinux latest | `docker pull ghcr.io/gemc/g4install:11.3.2-archlinux-latest` |   no  |  yes  |

---


## CVMFS Distribution

Geant4 libraries are distributed via CVMFS at:

```shell
/cvmfs/jlab.opensciencegrid.org/geant4/g4install
```
---

## Detailed Documentation

* **Multi-version workflow / switching guide**: `multi-version-workflow.md`

---

## CI Status

[![Build Geant4 Images](https://github.com/gemc/g4install/actions/workflows/docker.yml/badge.svg)](https://github.com/gemc/g4install/actions/workflows/docker.yml)

