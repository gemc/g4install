


This repository provides:

- module environment for geant4 and installation scripts
- geant4 docker containers registry for both `amd64` and `arm64` architectures.
- CVMFS distribution of Geant4

<br/>

> [!NOTE]
> Supported Geant4 Versions:
> - 11.4.0
> - 11.3.2

<hr/><br/>


## Built Images

Docker Containers Images are created by Continuous Integration and published to the
[GitHub registry](https://github.com/gemc/g4install/pkgs/container/g4install).

- The images are a stitch of both architectures, so `docker run` does not need additional platform directives or emulations:
the same command can be used on intel/silicon cpus.
- The images can be run in batch mode or with GUI (noVNC, using a browser or VNC client).

The images contain Geant4 and ROOT.
Geant4 libraries are distributed on CVMFS at `/cvmfs/jlab.opensciencegrid.org/geant4/g4install`


### Running Images in batch mode

Example:

```
docker run --rm -it ghcr.io/gemc/g4install:11.4.0-ubuntu-24.04 bash -li
```

### Running Images in graphical mode with VNC/noVNC

Use these convenience variables:

```
VPORTS=(-p 6080:6080 -p 5900:5900)
VNC_PASS=(-e X11VNC_PASSWORD=change-me)
VNC_BIND=(-e VNC_BIND=0.0.0.0)
GEO_FLAGS=(-e GEOMETRY=1920x1200)
```


Then run docker with:

```
docker run --rm -it $VPORTS $VNC_BIND $VNC_PASS $GEO_FLAGS ghcr.io/gemc/g4install:11.4.0-ubuntu-24.04
```

The supported images are listed below.

<br/>


### Geant4 11.4.0:
|        OS        |                        Pull Command                        | arm64 |  amd64   |
|:----------------:|:----------------------------------------------------------:|:-----:|:--------:|
| ubuntu 24.04    | docker pull ghcr.io/gemc/g4install:11.4.0-ubuntu24         | yes   | yes      |
| fedora 40       | docker pull ghcr.io/gemc/g4install:11.4.0-fedora40         | yes   | yes      |
| almalinux 9.4   | docker pull ghcr.io/gemc/g4install:11.4.0-almalinux9.4     | yes   | yes      |
| debian 12       | docker pull ghcr.io/gemc/g4install:11.4.0-debian-12        | yes   | yes      |
| archlinux latest | docker pull ghcr.io/gemc/g4install:11.4.0-archlinux-latest | no    | yes      |
<br/>

### Geant4 11.3.2:
|        OS        |                        Pull Command                        | arm64 |  amd64   |
|:----------------:|:----------------------------------------------------------:|:-----:|:--------:|
| ubuntu 24.04    | docker pull ghcr.io/gemc/g4install:11.3.2-ubuntu24         | yes   | yes      |
| fedora 40       | docker pull ghcr.io/gemc/g4install:11.3.2-fedora40         | yes   | yes      |
| almalinux 9.4   | docker pull ghcr.io/gemc/g4install:11.3.2-almalinux9.4     | yes   | yes      |
| debian 12       | docker pull ghcr.io/gemc/g4install:11.3.2-debian-12        | yes   | yes      |
| archlinux latest | docker pull ghcr.io/gemc/g4install:11.3.2-archlinux-latest | no    | yes      |
<br/>


## Status Badges:

[![Build Geant4 Images](https://github.com/gemc/g4install/actions/workflows/docker.yml/badge.svg)](https://github.com/gemc/g4install/actions/workflows/docker.yml)
