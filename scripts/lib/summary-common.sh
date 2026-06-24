#!/usr/bin/env bash

summary_get_info() {
  local file="$1"
  local key="$2"
  grep -m1 "^${key}=" "${file}" | cut -d= -f2- || true
}

short_commit() {
  local value="$1"
  if [[ -z "${value}" || "${value}" == "unknown" ]]; then
    echo "unknown"
  else
    echo "${value:0:7}"
  fi
}

# Encode a string for use in shields.io badge path segments.
# spaces → _   |   # → %23   |   - → -- (shields.io convention for literal dash)
badge_encode() {
  echo "$1" | sed 's/ /_/g; s/#/%23/g; s/-/--/g'
}

manager_display() {
  case "$1" in
    none)          echo "No Manager" ;;
    kernelsu)      echo "KernelSU" ;;
    kernelsu-next) echo "KernelSU-Next" ;;
    sukisu-ultra)  echo "SukiSU Ultra" ;;
    resukisu)      echo "ReSukiSU" ;;
    *)             echo "$1" ;;
  esac
}

manager_app_url() {
  case "$1" in
    kernelsu)      echo "https://github.com/tiann/KernelSU/releases" ;;
    kernelsu-next) echo "https://github.com/KernelSU-Next/KernelSU-Next/releases" ;;
    sukisu-ultra)  echo "https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases" ;;
    resukisu)      echo "https://github.com/ReSukiSU/ReSukiSU" ;;
    *)             echo "" ;;
  esac
}
