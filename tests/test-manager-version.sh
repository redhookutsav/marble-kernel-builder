#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

run_case() {
  local name="$1"
  local makefile_content="$2"
  local expected="$3"
  local case_dir="${tmp_dir}/${name}"
  local refs_file="${case_dir}/resolved-refs.env"

  mkdir -p "${case_dir}/kernel-source/KernelSU/kernel"
  printf '%s\n' "${makefile_content}" > "${case_dir}/kernel-source/KernelSU/kernel/Makefile"
  : > "${refs_file}"

  if ! KERNEL_DIR="${case_dir}/kernel-source" \
    RESOLVED_REFS_FILE="${refs_file}" \
    MANAGER=kernelsu \
    bash scripts/read-manager-version.sh >/dev/null; then
    echo "FAIL: ${name} exited non-zero" >&2
    exit 1
  fi

  actual="$(sed -n 's/^manager_version_code=//p' "${refs_file}")"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "FAIL: ${name}: expected '${expected}', got '${actual}'" >&2
    exit 1
  fi
}

run_case literal-kernelsu 'KERNELSU_VERSION := 12345' '12345'
run_case literal-ksu 'KSU_VERSION = 13000' '13000'
run_case whitespace '  KSU_VERSION  :=  14000  ' '14000'
run_case dynamic 'KSU_VERSION := $(shell expr 1 + 2)' ''
run_case missing '# no version assignment' ''

none_refs="${tmp_dir}/none-resolved-refs.env"
: > "${none_refs}"
RESOLVED_REFS_FILE="${none_refs}" MANAGER=none bash scripts/read-manager-version.sh >/dev/null
grep -qx 'manager_version_code=' "${none_refs}" || {
  echo "FAIL: none manager did not write empty version metadata" >&2
  exit 1
}

echo "Manager version tests passed"
