#!/usr/bin/env bash
# Configure and compile one Geant4 example that ships inside the image under
# $G4INSTALL/share/Geant4/examples.
#
# Usage:   build_example.sh <example-path-under-share/Geant4/examples>
# Example: build_example.sh extended/field/field03
#
# The example is copied into a writable work directory so it can optionally be patched and then
# built out-of-source; the installed example tree is never modified. If $PHYSICS_LIST is set, the
# example's main .cc is first rewritten (via replace_physics_list.py) so its physics list is built
# by the extensible factory using that name (e.g. "FTFP_BERT_EMX+G4OpticalPhysics").
#
# All build chatter goes to stderr. On success two lines are printed to stdout:
#   1. the (copied) example source directory
#   2. the built executable
#
# The work directory defaults to $BUILD_EXAMPLE_WORKDIR (or the workspace) and can be overridden.
set -euo pipefail

example_path="${1:?usage: build_example.sh <example-path under share/Geant4/examples>}"
work_dir="${BUILD_EXAMPLE_WORKDIR:-${GITHUB_WORKSPACE:-$PWD}}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Make sure the Geant4 environment is active (the module sets G4INSTALL, PATH, ...). When the caller
# has already sourced it (as the workflow does) this is a no-op.
if [ -z "${G4INSTALL:-}" ]; then
	DOCKER_ENTRYPOINT_SOURCE_ONLY=1 . /usr/local/bin/docker-entrypoint.sh
	eval "$(geant4-config --sh)"
fi

examples_root="$G4INSTALL/share/Geant4/examples"
[ -d "$examples_root" ] \
	|| examples_root="$(ls -d "$G4INSTALL"/share/Geant4*/examples 2>/dev/null | head -1)"

example_src="${examples_root}/${example_path}"
[ -f "${example_src}/CMakeLists.txt" ] \
	|| { echo "ERROR: ${example_path}/CMakeLists.txt not found under ${examples_root}" >&2; exit 1; }

# Copy into a writable location so we can (optionally) patch it and build out-of-source.
src="${work_dir}/example"
build="${work_dir}/build"
rm -rf "$src" "$build"
cp -r "$example_src" "$src"

# Optional: redirect the physics list through the extensible factory.
if [ -n "${PHYSICS_LIST:-}" ]; then
	main_cc="$(grep -l 'int main' "$src"/*.cc | head -1)"
	[ -n "$main_cc" ] || { echo "ERROR: no main .cc found in $src" >&2; exit 1; }
	python3 "$here/replace_physics_list.py" "$main_cc" "${PHYSICS_LIST}" >&2
fi

# Out-of-source build against the installed Geant4. RelWithDebInfo so the example code also carries
# symbols; the Geant4 libraries already do in the debug image.
cmake -S "$src" -B "$build" \
	-DCMAKE_PREFIX_PATH="$G4INSTALL" \
	-DCMAKE_BUILD_TYPE=RelWithDebInfo >&2
cmake --build "$build" -j"$(nproc)" >&2

# Executable target name, read straight from the example CMakeLists (e.g. exampleB5, TestEm4, wls).
exe="$(grep -hoE 'add_executable\(\s*[A-Za-z0-9_]+' "$src"/CMakeLists.txt | head -1 \
	| sed -E 's/add_executable\(\s*//')"
[ -n "$exe" ] || { echo "ERROR: could not determine executable name from CMakeLists" >&2; exit 1; }

bin="$build/$exe"
[ -x "$bin" ] || bin="$(find "$build" -maxdepth 2 -type f -name "$exe" -perm -u+x | head -1)"
[ -x "$bin" ] || { echo "ERROR: built executable '$exe' not found under $build" >&2; exit 1; }

printf '%s\n%s\n' "$src" "$bin"
