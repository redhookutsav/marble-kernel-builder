#!/usr/bin/env bash
set -euo pipefail

source config/marble.env

KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
BUILD_SCOPE="${BUILD_SCOPE:-image-only}"
MANAGER="${MANAGER:-none}"
ENABLE_SUSFS="${ENABLE_SUSFS:-false}"
JOBS="${JOBS:-$(nproc)}"
USE_CCACHE="${USE_CCACHE:-true}"

pushd "${KERNEL_DIR}" >/dev/null
mkdir -p "${OUT_DIR}" "${RELEASE_DIR}"

export ARCH
export SUBARCH="${ARCH}"
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-marble}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-github-actions}"
export CCACHE_DIR="${CCACHE_DIR:-${HOME}/.ccache}"
export CCACHE_COMPILERCHECK=content
export CCACHE_NOHASHDIR=true

if [[ -n "${ANDROID_CLANG_BIN:-}" ]]; then
  if [[ ! -x "${ANDROID_CLANG_BIN}/clang" ]]; then
    echo "::error::ANDROID_CLANG_BIN does not contain clang: ${ANDROID_CLANG_BIN}"
    exit 1
  fi
  export PATH="${ANDROID_CLANG_BIN}:${PATH}"
fi

if [[ "${USE_CCACHE}" == "true" ]] && command -v ccache >/dev/null 2>&1; then
  export CC="ccache clang"
  ccache -M 2G
  ccache -o compression=true
  ccache -z || true
else
  export CC="clang"
fi

clang --version | tee "${RELEASE_DIR}/build.log"
make O="${OUT_DIR}" ARCH="${ARCH}" LLVM=1 LLVM_IAS=1 CC="${CC}" "${DEFCONFIG}" 2>&1 | tee -a "${RELEASE_DIR}/build.log"

if [[ "${MANAGER}" != "none" ]]; then
  scripts/config --file "${OUT_DIR}/.config" -e KSU
fi
if [[ "${ENABLE_SUSFS}" == "true" ]]; then
  scripts/config --file "${OUT_DIR}/.config" -e KSU_SUSFS
fi

make O="${OUT_DIR}" ARCH="${ARCH}" LLVM=1 LLVM_IAS=1 CC="${CC}" olddefconfig 2>&1 | tee -a "${RELEASE_DIR}/build.log"

if [[ "${MANAGER}" != "none" ]] && ! grep -q '^CONFIG_KSU=y$' "${OUT_DIR}/.config"; then
  echo "::error::CONFIG_KSU is not enabled in the final kernel config"
  exit 1
fi
if [[ "${ENABLE_SUSFS}" == "true" ]] && ! grep -q '^CONFIG_KSU_SUSFS=y$' "${OUT_DIR}/.config"; then
  echo "::error::CONFIG_KSU_SUSFS is not enabled in the final kernel config"
  exit 1
fi

targets=(Image)
if [[ "${BUILD_SCOPE}" == "full" ]]; then
  targets+=(modules dtbs)
fi

make -j"${JOBS}" O="${OUT_DIR}" ARCH="${ARCH}" LLVM=1 LLVM_IAS=1 CC="${CC}" "${targets[@]}" 2>&1 | tee -a "${RELEASE_DIR}/build.log"

image_path="${OUT_DIR}/arch/arm64/boot/Image"
if [[ ! -s "${image_path}" ]]; then
  echo "::error::Built Image not found at ${image_path}"
  exit 1
fi

image_size="$(stat -c%s "${image_path}")"
if [[ "${image_size}" -lt 5000000 ]]; then
  echo "::error::Built Image is unexpectedly small: ${image_size} bytes"
  exit 1
fi

if command -v file >/dev/null 2>&1; then
  file "${image_path}" | tee -a "${RELEASE_DIR}/build.log"
fi

cp "${image_path}" "${RELEASE_DIR}/Image"
for file in System.map vmlinux; do
  if [[ -s "${OUT_DIR}/${file}" ]]; then
    cp "${OUT_DIR}/${file}" "${RELEASE_DIR}/${file}"
  fi
done

if [[ "${BUILD_SCOPE}" == "full" ]]; then
  if find "${OUT_DIR}/arch/arm64/boot/dts" -name '*.dtb' -print -quit | grep -q .; then
    find "${OUT_DIR}/arch/arm64/boot/dts" -name '*.dtb' -print0 | tar --null -T - -czf "${RELEASE_DIR}/dtbs.tar.gz"
  fi
  if find "${OUT_DIR}" -name '*.ko' -print -quit | grep -q .; then
    find "${OUT_DIR}" -name '*.ko' -print0 | tar --null -T - -czf "${RELEASE_DIR}/modules.tar.gz"
  fi
fi

if [[ "${USE_CCACHE}" == "true" ]] && command -v ccache >/dev/null 2>&1; then
  ccache -s | tee "${RELEASE_DIR}/ccache-stats.txt" || true
fi

popd >/dev/null
