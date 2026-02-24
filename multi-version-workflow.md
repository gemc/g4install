# Multi-Version Geant4 Workflow with g4install

This guide explains how `g4install` enables **seamless installation and use of multiple Geant4 versions** on the same machine.


---

## Overview

With `g4install`, each Geant4 version is exposed as a separate **environment module** (for example, `geant4/11.3.2`, `geant4/11.4.0`).

This provides:

- **Side-by-side installs** (no overwrite)
- **Version-specific environments**
- **Fast switching** via `module load` / `module switch`
- **Automatic dependency loading** (CLHEP, Xerces-C)
- **Cleaner shell state** than manual environment-variable editing

---

## Why modules instead of manual environment variables?

Without modules, switching Geant4 versions usually means manually updating:

- `PATH`
- `LD_LIBRARY_PATH` / `DYLD_LIBRARY_PATH`
- `CMAKE_PREFIX_PATH`
- Geant4-specific environment variables
- dependency paths (CLHEP / Xerces-C / data)

That is error-prone and easy to mix across versions.

Using modules avoids this by making the active Geant4 version explicit and reversible.

---

## Prerequisites

Install **Environment Modules**:

- **Linux**: install `environment-modules` using your package manager
- **macOS**: `brew install modules`


Clone the repository and add it to your module search path:

```shell
git clone https://github.com/gemc/g4install
module use /path/to/g4install
```

---

## Discover available versions

List available Geant4 modulefiles:

```shell
module avail geant4
```

Inspect a modulefile:

```shell
module show geant4/11.4.0
```

This is useful for understanding what environment variables and dependencies are configured.

---

## Install one or more Geant4 versions

Load the system build environment:

```shell
module load sim_system
```

Install one or more versions:

```shell
install_geant4 11.3.2
install_geant4 11.4.0
```

These installs coexist and remain independently selectable.

### Important behavior

Installing a new version does **not** replace an existing one. For example:

* `install_geant4 11.3.2` → creates / registers `geant4/11.3.2`
* `install_geant4 11.4.0` → creates / registers `geant4/11.4.0`

Both remain available.

---

## Load a specific version

```shell
module load geant4/11.4.0
```

This automatically loads the required dependencies, including:

* [CLHEP](https://gitlab.cern.ch/CLHEP/CLHEP)
* [Xerces-C](https://github.com/apache/xerces-c.git)

Verify the selected version:

```shell
geant4-config --version
which geant4-config
module list
```

---

## Switching between versions (core workflow)

### Preferred method: `module switch`

```shell
module load geant4/11.3.2
# build / run / test

module switch geant4/11.3.2 geant4/11.4.0
# rebuild / rerun / compare
```

### Alternative method: unload + load

```shell
module unload geant4/11.3.2
module load geant4/11.4.0
```

This is useful on systems where `module switch` is unavailable or behaves differently.

---

## Example validation workflow across Geant4 releases

A common use case is regression testing or physics validation. 

```shell
module use /path/to/g4install

# Test with Geant4 11.3.2
module load geant4/11.3.2
geant4-config --version
# configure/build/run your application
# save outputs / logs

# Switch to Geant4 11.4.0
module switch geant4/11.3.2 geant4/11.4.0
geant4-config --version
# reconfigure/rebuild/rerun
# compare outputs
```

### Recommendation

Add `module use /path/to/g4install` to your `.[bash][zsh][csh]rc` .

---

## Building a Geant4 example (B5) with the active version

A quick way to verify that the currently loaded Geant4 module is working correctly is to build one of the Geant4 examples (for example, **Basic Example B5**).

After loading the desired Geant4 version, build the example like this:

```shell
mkdir build_B5
cd build_B5
cmake $G4INSTALL/data/Geant4/examples/basic/B5
make -j4
```

### Notes

* This builds the example against the **currently loaded** Geant4 module.
* If you switch Geant4 versions, use a **different build directory** (recommended) or remove/reconfigure the existing one.
* You can confirm the active version before building with:

```shell
geant4-config --version
module list
```

### Multi-version example build workflow

```shell
# Build B5 with Geant4 11.3.2
module load geant4/11.3.2
mkdir -p build_B5_g4_11_3_2
cd build_B5_g4_11_3_2
cmake $G4INSTALL/data/Geant4/examples/basic/B5
make -j4
cd ..

# Switch and build B5 with Geant4 11.4.0
module switch geant4/11.3.2 geant4/11.4.0
mkdir -p build_B5_g4_11_4_0
cd build_B5_g4_11_4_0
cmake $G4INSTALL/data/Geant4/examples/basic/B5
make -j4
cd ..
```

This is a simple, practical way to validate that different installed Geant4 versions can be selected and used seamlessly.


---

## Docker and CVMFS in the same multi-version workflow

`g4install` supports the same “version-targeted” mindset across local installs, containers, and CVMFS.

### Docker

Container tags are versioned, e.g.:

* `ghcr.io/gemc/g4install:11.4.0-ubuntu24`
* `ghcr.io/gemc/g4install:11.3.2-fedora40`

This allows exact version pinning in CI and developer workflows.

Batch example:

```shell
docker run --rm -it ghcr.io/gemc/g4install:11.4.0-ubuntu-24.04 bash -li
```

### CVMFS

Geant4 libraries are distributed at:

```shell
/cvmfs/jlab.opensciencegrid.org/geant4/g4install
```

This is useful for shared clusters and grid environments where local installation is not preferred.

---

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


---

## Summary

`g4install` is built around a simple principle:

> **Install many Geant4 versions once, then switch between them safely and quickly using modules.**

This makes it practical to support:

* project-specific version requirements
* regression testing across releases
* reproducible CI/container workflows
* shared lab/cluster environments

For a quick-start overview, see the repository `README.md`.

