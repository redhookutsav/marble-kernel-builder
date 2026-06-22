#!/usr/bin/env bash
set -euo pipefail

MANAGER="${MANAGER:-none}"
KERNEL_DIR="${KERNEL_DIR:-kernel-source}"

manager_version_code=""

if [[ "${MANAGER}" == "none" ]]; then
  echo "No manager — skipping version read"
  echo "manager_version_code=" >> release/resolved-refs.env
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
  echo "manager_version_code=" >> release/resolved-refs.env
  exit 0
fi

manager_version_code="$(grep -m1 '^KERNELSU_VERSION' "${manager_makefile}" | \
  sed -E 's/KERNELSU_VERSION[[:space:]]*:?=[[:space:]]*//' | \
  tr -d '[:space:]')"

if [[ -z "${manager_version_code}" ]]; then
  echo "::warning::KERNELSU_VERSION not found in ${manager_makefile}"
  echo "manager_version_code=" >> release/resolved-refs.env
  exit 0
fi

echo "Manager version code: ${manager_version_code}"
echo "manager_version_code=${manager_version_code}" >> release/resolved-refs.env
