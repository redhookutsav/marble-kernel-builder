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

if [[ -f release/resolved-refs.env ]]; then
  source release/resolved-refs.env
fi

manager_label="${MANAGER}"
case "${MANAGER}" in
  none)         manager_label="NoRoot" ;;
  kernelsu)     manager_label="KernelSU" ;;
  kernelsu-next) manager_label="KSUNext" ;;
  sukisu-ultra) manager_label="SukiSU-Ultra" ;;
  resukisu)     manager_label="ReSukiSU" ;;
esac

# Use version tag when available (e.g. v3.2.0), otherwise fall back to short SHA.
manager_version="${manager_tag:-}"
if [[ -z "${manager_version}" && -n "${manager_commit:-}" ]]; then
  manager_version="${manager_commit:0:7}"
fi
if [[ -z "${manager_version}" ]]; then
  manager_version="none"
fi

susfs_label="NoSUSFS"
if [[ "${ENABLE_SUSFS}" == "true" ]]; then
  susfs_label="SUSFS-${susfs_reported_version:-${SUSFS_VERSION:-unknown}}"
fi

build_date="${BUILD_DATE:-$(date -u +%Y%m%d)}"

# Final format: Marble_<Manager>-<version>_<SUSFS>_<date>_r<run>.zip
# Example: Marble_KSUNext-v3.2.0_SUSFS-v2.2.0_20260622_r46.zip
# Example: Marble_KernelSU-v1.0.3_NoSUSFS_20260622_r12.zip
# Example: Marble_NoRoot_NoSUSFS_20260622_r5.zip
if [[ "${MANAGER}" == "none" ]]; then
  zip_name="Marble_NoRoot_NoSUSFS_${build_date}_r${run_number}.zip"
else
  zip_name="Marble_${manager_label}-${manager_version}_${susfs_label}_${build_date}_r${run_number}.zip"
fi

work_dir="$(mktemp -d)"
git init -q "${work_dir}/ak3"
git -C "${work_dir}/ak3" remote add origin "${ANYKERNEL3_REPO}"
git -C "${work_dir}/ak3" fetch --depth=1 origin "${ANYKERNEL3_REF}"
git -C "${work_dir}/ak3" checkout -q --detach FETCH_HEAD
anykernel3_commit="$(git -C "${work_dir}/ak3" rev-parse HEAD)"
echo "anykernel3_commit=${anykernel3_commit}" >> release/resolved-refs.env
rsync -a ak3/ "${work_dir}/ak3/"
cp "${image_path}" "${work_dir}/ak3/Image"

pushd "${work_dir}/ak3" >/dev/null
zip -r9 "${OLDPWD}/${release_dir}/${zip_name}" . -x ".git/*" "README.md" "*placeholder*"
popd >/dev/null

pushd "${release_dir}" >/dev/null
sha256sum "${zip_name}" > "${zip_name}.sha256"
printf 'zip_name=%s\n' "${zip_name}" > zip-name.env
printf 'zip_sha256=%s\n' "$(sha256sum "${zip_name}" | awk '{print $1}')" >> zip-name.env
popd >/dev/null

rm -rf "${work_dir}"
echo "Packaged ${release_dir}/${zip_name}"
