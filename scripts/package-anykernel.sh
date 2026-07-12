#!/usr/bin/env bash
set -euo pipefail

# Preserve caller/preset ROM label before marble.env defaults are applied.
_preset_rom_label="${SUPPORTED_ROM_LABEL:-}"

source config/marble.env

KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
MANAGER="${MANAGER:-none}"
ENABLE_SUSFS="${ENABLE_SUSFS:-false}"
BUILD_SCOPE="${BUILD_SCOPE:-image-only}"
run_number="${GITHUB_RUN_NUMBER:-local}"
# Runtime/preset label wins over config/marble.env default.
SUPPORTED_ROM_LABEL="${_preset_rom_label:-${SUPPORTED_ROM_LABEL:-HyperOS}}"
unset _preset_rom_label

release_dir="${KERNEL_DIR}/${RELEASE_DIR}"
if [[ -f release/resolved-refs.env ]]; then
  # shellcheck disable=SC1091
  source release/resolved-refs.env
fi

manager_label="${MANAGER}"
case "${MANAGER}" in
  none)         manager_label="NoRoot" ;;
  kernelsu)     manager_label="KernelSU" ;;
  kernelsu-next) manager_label="KSUNext" ;;
  sukisu-ultra) manager_label="SukiSUUltra" ;;
  resukisu)     manager_label="ReSukiSU" ;;
esac

# Prefer the version printed by the manager build, then its resolved tag, then commit.
manager_version="${manager_build_version_name:-${manager_build_tag:-${manager_tag:-}}}"
manager_version="${manager_version%%@*}"
if [[ -z "${manager_version}" && -n "${manager_commit:-}" ]]; then
  manager_version="${manager_commit:0:7}"
fi
manager_version="$(printf '%s' "${manager_version}" | sed -E \
  -e 's/[^A-Za-z0-9._-]+/-/g' -e 's/^-+//' -e 's/-+$//')"

manager_code="${manager_build_version_code:-${manager_version_code:-}}"
if [[ ! "${manager_code}" =~ ^[0-9]+$ ]]; then
  manager_code=""
fi

susfs_label="NoSUSFS"
if [[ "${ENABLE_SUSFS}" == "true" ]]; then
  susfs_label="SUSFS-${susfs_reported_version:-${SUSFS_VERSION:-unknown}}"
fi

# Prefer runtime/preset ROM label (author-named kernel family), fall back to marble.env.
package_label="${SUPPORTED_ROM_LABEL:-HyperOS}"
package_label="$(printf '%s' "${package_label}" | sed -E \
  -e 's/[^A-Za-z0-9._-]+/-/g' -e 's/^-+//' -e 's/-+$//')"
if [[ -z "${package_label}" ]]; then
  package_label="HyperOS"
fi

# Final format: AK3_Marble-<AuthorOrROM>_<Manager>-<version>-code<code>_<SUSFS>_r<run>.zip
if [[ "${MANAGER}" == "none" ]]; then
  zip_name="AK3_Marble-${package_label}_NoRoot_NoSUSFS_r${run_number}.zip"
else
  manager_identity="${manager_label}"
  if [[ -n "${manager_version}" ]]; then
    manager_identity+="-${manager_version}"
  fi
  if [[ -n "${manager_code}" ]]; then
    manager_identity+="-code${manager_code}"
  fi
  zip_name="AK3_Marble-${package_label}_${manager_identity}_${susfs_label}_r${run_number}.zip"
fi

if [[ "${PACKAGE_NAME_ONLY:-false}" == "true" ]]; then
  printf '%s\n' "${zip_name}"
  exit 0
fi

image_path="${release_dir}/Image"
if [[ ! -s "${image_path}" ]]; then
  echo "::error::Cannot package without ${image_path}"
  exit 1
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
