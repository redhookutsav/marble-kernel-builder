#!/usr/bin/env bash
set -euo pipefail

source config/marble.env

KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
MANAGER="${MANAGER:-none}"
ENABLE_SUSFS="${ENABLE_SUSFS:-false}"
BUILD_SCOPE="${BUILD_SCOPE:-image-only}"

release_dir="${KERNEL_DIR}/${RELEASE_DIR}"
build_info="${release_dir}/build-info.txt"
zip_env="${release_dir}/zip-name.env"
summary="${release_dir}/summary.md"

if [[ ! -f "${build_info}" || ! -f "${zip_env}" ]]; then
  echo "::error::Missing build metadata for summary generation"
  exit 1
fi

source "${zip_env}"

get_info() {
  local key="$1"
  grep -m1 "^${key}=" "${build_info}" | cut -d= -f2- || true
}

short_commit() {
  local value="$1"
  if [[ -z "${value}" || "${value}" == "unknown" ]]; then
    echo "unknown"
  else
    echo "${value:0:7}"
  fi
}

source_repo="$(get_info source_repo)"
source_ref="$(get_info source_ref)"
source_commit="$(get_info source_commit)"
workflow_run="$(get_info workflow_run)"
manager_name="$(get_info manager)"
manager_repo="$(get_info manager_repo)"
manager_ref="$(get_info manager_ref)"
manager_commit="$(get_info manager_commit)"
manager_tag="$(get_info manager_tag)"
manager_version_code="$(get_info manager_version_code)"
susfs_version="$(get_info susfs_version)"
susfs_branch="$(get_info susfs_kernel_branch)"
susfs_ref="$(get_info susfs_ref)"
susfs_commit="$(get_info susfs_commit)"
susfs_reported="$(get_info susfs_reported_version)"
susfs_url="$(get_info susfs_url)"
zip_sha="$(sha256sum "${release_dir}/${zip_name}" | awk '{print $1}')"
image_sha="$(sha256sum "${release_dir}/Image" | awk '{print $1}')"
zip_size="$(du -h "${release_dir}/${zip_name}" | awk '{print $1}')"
build_date="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
build_id="${GITHUB_RUN_ID:-}"
if [[ -z "${build_id}" && -n "${workflow_run}" ]]; then
  build_id="${workflow_run##*/}"
fi

manager_display="${manager_name}"
case "${manager_name}" in
  none)          manager_display="No manager" ;;
  kernelsu)      manager_display="KernelSU" ;;
  kernelsu-next) manager_display="KernelSU-Next" ;;
  sukisu-ultra)  manager_display="SukiSU Ultra" ;;
  resukisu)      manager_display="ReSukiSU" ;;
esac

title_suffix=""
if [[ "${ENABLE_SUSFS}" == "true" ]]; then
  title_suffix=" + SUSFS ${susfs_reported:-${susfs_version}}"
fi

manager_app_url=""
case "${manager_name}" in
  kernelsu)      manager_app_url="https://github.com/tiann/KernelSU/releases" ;;
  kernelsu-next) manager_app_url="https://github.com/KernelSU-Next/KernelSU-Next/releases" ;;
  sukisu-ultra)  manager_app_url="https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases" ;;
  resukisu)      manager_app_url="https://github.com/ReSukiSU/ReSukiSU" ;;
esac

{
  echo "# Marble Kernel — ${manager_display}${title_suffix}"
  echo
  echo "> Build Date: ${build_date}"
  echo "> Build ID: \`${build_id:-unknown}\`"
  echo "> Workflow: ${workflow_run}"
  echo
  echo "---"
  echo
  echo "## Build Configuration"
  echo
  echo "| Component | Details |"
  echo "|---|---|"
  echo "| Device | Poco F5 / Redmi Note 12 Turbo (\`marble\`, \`marblein\`) |"
  echo "| Kernel Base | \`android12-5.10\` |"
  echo "| Build Scope | \`${BUILD_SCOPE}\` |"
  echo "| Source | [\`${source_repo}@${source_ref}\`](https://github.com/${source_repo}/commit/${source_commit}) (\`$(short_commit "${source_commit}")\`) |"
  echo "| Compiler | Android \`clang-r416183b\` |"
  echo
  echo "## Manager"
  echo
  if [[ "${manager_name}" == "none" ]]; then
    echo "No root manager integrated. Baseline vanilla build only."
  else
    echo "| Field | Value |"
    echo "|---|---|"
    echo "| Manager | ${manager_display} |"
    echo "| Repository | [\`${manager_repo}@${manager_ref}\`](https://github.com/${manager_repo}) |"
    echo "| Commit | [\`$(short_commit "${manager_commit}")\`](https://github.com/${manager_repo}/commit/${manager_commit}) |"
    if [[ -n "${manager_tag}" ]]; then
      echo "| Version Tag | \`${manager_tag}\` |"
    fi
    if [[ -n "${manager_version_code}" ]]; then
      echo "| Version Code | \`${manager_version_code}\` |"
    fi
    if [[ "${manager_name}" == "kernelsu-next" && "${ENABLE_SUSFS}" == "true" ]]; then
      echo "| SUSFS Policy | Uses \`pershoot/KernelSU-Next@dev-susfs\` for SUSFS builds |"
    fi
  fi
  echo
  echo "## SUSFS"
  echo
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "| Field | Value |"
    echo "|---|---|"
    echo "| Version | \`${susfs_reported:-${susfs_version}}\` |"
    echo "| Kernel Branch | \`${susfs_branch}\` |"
    echo "| Commit | [${susfs_commit:0:7}](${susfs_url}) |"
  else
    echo "SUSFS is not enabled for this build."
  fi
  echo
  echo "---"
  echo
  echo "## Installation"
  echo
  echo "### Prerequisites"
  echo
  echo "- Unlocked bootloader"
  echo "- Poco F5 (\`marblein\`) or Redmi Note 12 Turbo (\`marble\`) only"
  echo "- Stock \`boot.img\` from the same ROM/firmware stored outside the device"
  if [[ "${manager_name}" != "none" ]]; then
    echo "- Matching manager app: ${manager_display}"
  fi
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "- [KSU SUSFS module](https://github.com/sidex15/susfs4ksu-module/releases) for \`${susfs_reported:-${susfs_version}}\`"
  fi
  echo
  echo "### Steps"
  echo
  echo "1. Download \`${zip_name}\` and verify its SHA256 checksum."
  echo "2. Flash the ZIP to the active slot via [Kernel Flasher](https://github.com/fatalcoder524/KernelFlasher/releases)."
  echo "3. The installer confirms the device codename (\`marble\`/\`marblein\`) and backs up the current boot image to \`/sdcard/marble-kernel-backup/\` before flashing."
  if [[ "${manager_name}" != "none" ]]; then
    echo "4. Install/open the ${manager_display} manager app after boot."
  fi
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "5. Install the KSU SUSFS module, configure hiding rules, then reboot."
  fi
  echo
  echo "> **Bootloop recovery:** Flash the stock \`boot.img\` back to the active slot."
  echo
  echo "---"
  echo
  echo "## Artifacts"
  echo
  echo "| File | Details |"
  echo "|---|---|"
  echo "| \`${zip_name}\` | Flashable AnyKernel3 zip, ${zip_size} |"
  echo "| \`${zip_name}.sha256\` | SHA256 checksum |"
  echo "| \`build-info.txt\` | Exact resolved refs and workflow metadata |"
  echo
  echo "### Checksums"
  echo
  echo "| Artifact | SHA256 |"
  echo "|---|---|"
  echo "| Image | \`${image_sha}\` |"
  echo "| ${zip_name} | \`${zip_sha}\` |"
  echo
  echo "---"
  echo
  echo "## Credits"
  echo
  echo "- Xiaomi/Poco kernel source maintainers"
  echo "- AnyKernel3 by osm0sis"
  echo "- KernelSU / KernelSU-Next / SukiSU Ultra / ReSukiSU maintainers"
  echo "- susfs4ksu by simonpunk and contributors"
  echo
  echo "---"
  echo
  echo "⚡ Built with GitHub Actions"
} > "${summary}"

cat "${summary}"
