#!/usr/bin/env bash
set -euo pipefail

MANAGER="${MANAGER:-none}"
KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
RESOLVED_REFS_FILE="${RESOLVED_REFS_FILE:-release/resolved-refs.env}"

manager_version_code=""
mkdir -p "$(dirname "${RESOLVED_REFS_FILE}")"

if [[ "${MANAGER}" == "none" ]]; then
  echo "No manager — skipping version read"
  echo "manager_version_code=" >> "${RESOLVED_REFS_FILE}"
  exit 0
fi

# All KernelSU-family managers embed KERNELSU_VERSION in their kernel/Makefile.
# Candidate locations, tried in order (setup.sh may place sources in different dirs):
makefile_candidates=(
  "${KERNEL_DIR}/KernelSU/kernel/Makefile"
  "${KERNEL_DIR}/KernelSU-Next/kernel/Makefile"
  "${KERNEL_DIR}/drivers/kernelsu/Makefile"
)

manager_makefile=""
for candidate in "${makefile_candidates[@]}"; do
  if [[ -f "${candidate}" ]]; then
    manager_makefile="${candidate}"
    break
  fi
done

if [[ -z "${manager_makefile}" ]]; then
  echo "::warning::Manager Makefile not found in expected locations — version code will be empty"
  echo "manager_version_code=" >> "${RESOLVED_REFS_FILE}"
  exit 0
fi

manager_version_code="$(
  sed -nE 's/^[[:space:]]*(KERNELSU_VERSION|KSU_VERSION)[[:space:]]*:?=[[:space:]]*([0-9]+)[[:space:]]*$/\2/p' \
    "${manager_makefile}" | head -n1 || true
)"

if [[ -z "${manager_version_code}" ]]; then
  echo "::warning::Literal manager version code not found in ${manager_makefile}"
  echo "manager_version_code=" >> "${RESOLVED_REFS_FILE}"
  exit 0
fi

echo "Manager version code: ${manager_version_code}"
echo "manager_version_code=${manager_version_code}" >> "${RESOLVED_REFS_FILE}"
