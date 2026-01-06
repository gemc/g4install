# g4install

## Geant4 Version: 11.3.2

This repository provides:

- module environment for geant4 and installation scripts
- docker containers with Geant4 for both `amd64` and `arm64` architectures.
- cvmfs distribution of Geant4 on `/cvmfs/jlab.opensciencegrid.org/geant4/g4install`

## Built Images

Docker Containers Images are created by CI and published to GitHub registry.

- The images are a stitch of both architectures, so docker run does not need additional platform directives or emulations:
the same command can be used on intel/silicon cpus.
- The images can be run in batch mode or with GUI (noVNC, using a browser or VNC client).

The images contain, in addition to Geant4 11.3.2, the following software:

 - Geant4: 11.3.2
 - ROOT: v6-36-04
 - Meson: 1.9.0
 - noVNC: v1.6.0

|        OS        |                        Pull Command                        | arm64 |  amd64   |
|:----------------:|:----------------------------------------------------------:|:-----:|:--------:|
| ubuntu 24.04    | docker pull ghcr.io/gemc/g4install:11.3.2-ubuntu24         | yes   | yes      |
| fedora 40       | docker pull ghcr.io/gemc/g4install:11.3.2-fedora40         | yes   | yes      |
| almalinux 9.4   | docker pull ghcr.io/gemc/g4install:11.3.2-almalinux9.4     | yes   | yes      |
| debian 12       | docker pull ghcr.io/gemc/g4install:11.3.2-debian-12        | yes   | yes      |
| archlinux latest | docker pull ghcr.io/gemc/g4install:11.3.2-archlinux-latest | no    | yes      |


## Distribution

The container libraries are organized in subdirs of `/cvmfs/jlab.opensciencegrid.org/geant4/g4install` with names matching the docker tags above.

The following previous versions of Geant4 are also distributed on CVMFS:

 - -11.4.0\n-11.3.2

## Status Badges:

[![Build Geant4 Images](https://github.com/gemc/g4install/actions/workflows/docker.yml/badge.svg)](https://github.com/gemc/g4install/actions/workflows/docker.yml)
