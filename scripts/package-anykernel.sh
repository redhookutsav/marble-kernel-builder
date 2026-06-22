#!/usr/bin/env bash
set -euo pipefail

source config/marble.env

KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
MANAGER="${MANAGER:-none}"
ENABLE_SUSFS="${ENABLE_SUSFS:-false}"
BUILD_SCOPE="${BUILD_SCOPE:-image-only}"
run_number="${GITHUB_RUN_NUMBER:-local}"

release_dir="${KERNEL_DIR}/${RELEASE_DIR}"
image_path="${release_dir}/Image"
if [[ ! -s "${image_path}" ]]; then
  echo "::error::Cannot package without ${image_path}"
  exit 1
fi

variant="${MANAGER}"
if [[ "${ENABLE_SUSFS}" == "true" ]]; then
  variant="${variant}-susfs"
fi

zip_name="Marble-${variant}-${BUILD_SCOPE}-dev-${run_number}.zip"
work_dir="$(mktemp -d)"
git clone --depth=1 "${ANYKERNEL3_REPO}" "${work_dir}/ak3"
rsync -a ak3/ "${work_dir}/ak3/"
cp "${image_path}" "${work_dir}/ak3/Image"

pushd "${work_dir}/ak3" >/dev/null
zip -r9 "${OLDPWD}/${release_dir}/${zip_name}" . -x ".git/*" "README.md" "*placeholder*"
popd >/dev/null

pushd "${release_dir}" >/dev/null
sha256sum "${zip_name}" > "${zip_name}.sha256"
printf 'zip_name=%s\n' "${zip_name}" > zip-name.env
popd >/dev/null

rm -rf "${work_dir}"
echo "Packaged ${release_dir}/${zip_name}"
