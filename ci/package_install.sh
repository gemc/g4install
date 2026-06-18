#!/usr/bin/env bash
set -euo pipefail

# Build a relocatable Geant4 binary tarball from the module-installed trees.
#
# Usage:
#   ci/package_install.sh [OUTPUT_DIR] [PACKAGE_NAME]
#
# The archive bundles the Geant4, CLHEP and Xerces-C install trees so that
# Geant4 is usable without recompiling. The Geant4 physics data is deliberately
# excluded (it is multi-GB); a generated install_geant4_data.sh downloads it at
# install time, mirroring what ../src does for the GEMC tarball.
#
# The following environment variables are expected (set by `module load geant4`):
#   G4INSTALL       Geant4 install prefix  (.../geant4/<g4_version>)
#   CLHEP_BASE_DIR  CLHEP install prefix   (.../clhep/<clhep_version>)
#   XERCESCROOT     Xerces-C install prefix(.../xercesc/<xercesc_version>)
# The G4*DATA variables (set by `eval "$(geant4-config --sh)"`) describe the
# Geant4 datasets to download.

output_dir="${1:-dist}"

g4install="${G4INSTALL:?G4INSTALL not set; run 'module load geant4/<version>' first}"
clhep_dir="${CLHEP_BASE_DIR:?CLHEP_BASE_DIR not set; run 'module load geant4/<version>' first}"
xercesc_dir="${XERCESCROOT:?XERCESCROOT not set; run 'module load geant4/<version>' first}"

geant4_version="${GEANT4_VERSION:-${G4_VERSION:-$(basename "${g4install}")}}"
clhep_version="$(basename "${clhep_dir}")"
xercesc_version="$(basename "${xercesc_dir}")"

arch="$(uname -m)"
case "${arch}" in
  x86_64) arch=amd64 ;;
  aarch64 | arm64) arch=arm64 ;;
esac

package_name="${2:-geant4-${geant4_version}-linux-${arch}}"

for prefix in "${g4install}" "${clhep_dir}" "${xercesc_dir}"; do
  if [[ ! -d "${prefix}" ]]; then
    echo "Install prefix does not exist: ${prefix}" >&2
    exit 1
  fi
done

mkdir -p "${output_dir}"
output_dir="$(cd "${output_dir}" && pwd)"
stage="$(mktemp -d)"
trap 'rm -rf "${stage}"' EXIT

package_root="${stage}/${package_name}"
mkdir -p "${package_root}"

# Relative layout inside the package (keeps the module-style geant4/<ver> tree).
geant4_rel="geant4/${geant4_version}"
clhep_rel="clhep/${clhep_version}"
xercesc_rel="xercesc/${xercesc_version}"

mkdir -p "${package_root}/geant4" "${package_root}/clhep" "${package_root}/xercesc"
cp -a "${g4install}"    "${package_root}/${geant4_rel}"
cp -a "${clhep_dir}"    "${package_root}/${clhep_rel}"
cp -a "${xercesc_dir}"  "${package_root}/${xercesc_rel}"

# Drop the bundled Geant4 physics data: it is downloaded at install time.
# Geant4 keeps it under share/Geant4*/data (and an optional package cache).
find "${package_root}/${geant4_rel}/share" -maxdepth 2 -type d -name data -prune \
  -exec rm -rf {} + 2>/dev/null || true

# lib vs lib64 differs per distro; pick whichever each tree actually has.
choose_libdir() {
  local root="$1"
  if [[ -d "${root}/lib64" ]]; then
    echo "lib64"
  else
    echo "lib"
  fi
}
geant4_lib="$(choose_libdir "${package_root}/${geant4_rel}")"
clhep_lib="$(choose_libdir "${package_root}/${clhep_rel}")"
xercesc_lib="$(choose_libdir "${package_root}/${xercesc_rel}")"

# ---------------------------------------------------------------------------
# Collect the Geant4 dataset descriptors from the environment.
# Each record is "ENV_NAME|ARCHIVE_NAME|DATA_DIR_NAME".
# ---------------------------------------------------------------------------
archive_name_from_data_dir() {
  local directory="$1"
  local prefix version

  if [[ "${directory}" =~ ^(G4)?([A-Za-z]+)([0-9].*)$ ]]; then
    prefix="${BASH_REMATCH[1]}${BASH_REMATCH[2]}"
    version="${BASH_REMATCH[3]}"
  else
    echo "Cannot derive Geant4 dataset archive name from directory: ${directory}" >&2
    return 1
  fi

  if [[ "${prefix}" == G4* ]]; then
    printf '%s.%s.tar.gz\n' "${prefix}" "${version}"
  else
    printf 'G4%s.%s.tar.gz\n' "${prefix}" "${version}"
  fi
}

if command -v geant4-config >/dev/null 2>&1; then
  eval "$(geant4-config --sh)"
fi

geant4_dataset_records=()
while IFS='=' read -r env_name env_path; do
  [[ -n "${env_name}" && -n "${env_path}" ]] || continue
  data_dir_name="$(basename "${env_path}")"
  archive_name="$(archive_name_from_data_dir "${data_dir_name}")"
  geant4_dataset_records+=( "${env_name}|${archive_name}|${data_dir_name}" )
done < <(env | LC_ALL=C sort | grep -E '^G4[A-Z0-9_]*DATA=' || true)

if (( ${#geant4_dataset_records[@]} == 0 )); then
  echo "No Geant4 data environment variables were found." >&2
  echo "Run 'eval \"\$(geant4-config --sh)\"' before $0." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# geant4.env: source after unpacking to use the relocated Geant4 install.
# ---------------------------------------------------------------------------
cat > "${package_root}/geant4.env" <<EOF
# Source this file after unpacking the Geant4 tarball.
#
# Geant4 data directories live under \${GEANT4_HOME}/geant4-data.
# Run \${GEANT4_HOME}/install_geant4_data.sh once to download them.

if [ -n "\${BASH_SOURCE[0]:-}" ]; then
  G4ENV_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "\${ZSH_VERSION:-}" ]; then
  G4ENV_DIR="\$(cd "\$(dirname "\${(%):-%x}")" && pwd)"
else
  G4ENV_DIR="\$(pwd)"
fi

export GEANT4_HOME="\${GEANT4_HOME:-\${G4ENV_DIR}}"
export G4INSTALL="\${GEANT4_HOME}/${geant4_rel}"
export CLHEP_BASE_DIR="\${GEANT4_HOME}/${clhep_rel}"
export XERCESCROOT="\${GEANT4_HOME}/${xercesc_rel}"

export PATH="\${G4INSTALL}/bin:\${PATH}"
export LD_LIBRARY_PATH="\${G4INSTALL}/${geant4_lib}:\${CLHEP_BASE_DIR}/${clhep_lib}:\${XERCESCROOT}/${xercesc_lib}:\${LD_LIBRARY_PATH:-}"

export GEANT4_DATA_DIR="\${GEANT4_HOME}/geant4-data"

g4_datasets=(
EOF

for record in "${geant4_dataset_records[@]}"; do
  env_name="${record%%|*}"
  rest="${record#*|}"
  data_dir_name="${rest#*|}"
  printf '  "%s|%s"\n' "${env_name}" "${data_dir_name}" >> "${package_root}/geant4.env"
done

cat >> "${package_root}/geant4.env" <<'EOF'
)

for g4_dataset in "${g4_datasets[@]}"; do
  g4_env_name="${g4_dataset%%|*}"
  g4_data_dir="${g4_dataset#*|}"
  export "${g4_env_name}=${GEANT4_DATA_DIR}/${g4_data_dir}"
done

g4_missing_data=()
for g4_dataset in "${g4_datasets[@]}"; do
  g4_env_name="${g4_dataset%%|*}"
  g4_data_dir="${g4_dataset#*|}"
  if [ ! -d "${GEANT4_DATA_DIR}/${g4_data_dir}" ]; then
    g4_missing_data+=("${g4_env_name}: ${GEANT4_DATA_DIR}/${g4_data_dir}")
  fi
done

if [ "${#g4_missing_data[@]}" -gt 0 ]; then
  echo "Geant4 data check failed. Missing required data directories:" >&2
  printf '  %s\n' "${g4_missing_data[@]}" >&2
  echo "Run: ${GEANT4_HOME}/install_geant4_data.sh" >&2
  return 1 2>/dev/null || exit 1
fi

unset g4_data_dir g4_dataset g4_env_name g4_datasets g4_missing_data
EOF

# ---------------------------------------------------------------------------
# install_geant4_data.sh: download the datasets into geant4-data/.
# ---------------------------------------------------------------------------
cat > "${package_root}/install_geant4_data.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
data_dir="${script_dir}/geant4-data"
base_url="${GEANT4_DATA_BASE_URL:-https://cern.ch/geant4-data/datasets}"

datasets=(
EOF

for record in "${geant4_dataset_records[@]}"; do
  env_name="${record%%|*}"
  rest="${record#*|}"
  archive_name="${rest%%|*}"
  data_dir_name="${rest#*|}"
  printf '  "%s|%s|%s"\n' "${env_name}" "${archive_name}" "${data_dir_name}" >> "${package_root}/install_geant4_data.sh"
done

cat >> "${package_root}/install_geant4_data.sh" <<'EOF'
)

download() {
  local url="$1"
  local output="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fL --retry 3 -o "${output}" "${url}"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "${output}" "${url}"
  else
    echo "Neither curl nor wget is available." >&2
    return 1
  fi
}

mkdir -p "${data_dir}"

for item in "${datasets[@]}"; do
  env_name="${item%%|*}"
  rest="${item#*|}"
  archive="${rest%%|*}"
  directory="${rest#*|}"
  target="${data_dir}/${directory}"

  if [[ -d "${target}" ]]; then
    echo "Found ${env_name}: ${directory}"
    continue
  fi

  tmp="$(mktemp -d)"
  trap 'rm -rf "${tmp}"' EXIT
  echo "Downloading ${env_name}: ${directory}"
  download "${base_url}/${archive}" "${tmp}/${archive}"
  tar -xzf "${tmp}/${archive}" -C "${data_dir}"
  rm -rf "${tmp}"
  trap - EXIT

  if [[ ! -d "${target}" ]]; then
    echo "Expected directory was not created: ${target}" >&2
    exit 1
  fi
done

echo "Geant4 data installed in ${data_dir}"
EOF
chmod +x "${package_root}/install_geant4_data.sh"

cat > "${package_root}/INSTALL_TARBALL.md" <<EOF
# Geant4 binary tarball

This archive bundles a prebuilt Geant4 ${geant4_version} together with its
CLHEP (${clhep_version}) and Xerces-C (${xercesc_version}) dependencies, so you
can use Geant4 without recompiling it.

## Geant4 data

The multi-GB physics data is **not** included. Download it once, then source the
environment:

\`\`\`bash
./install_geant4_data.sh
source ./geant4.env
geant4-config --version
\`\`\`

The archive is relocatable: \`geant4.env\` derives all paths from its own
location, so it works wherever you unpack it.
EOF

tarball="${output_dir}/${package_name}.tar.gz"
tar -C "${stage}" -czf "${tarball}" "${package_name}"
echo "${tarball}"
