#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

matrix="$(
  BUILD_KERNELSU_NEXT=true \
  BUILD_SUKISU_ULTRA=true \
  BUILD_RESUKISU=true \
  ENABLE_SUSFS=true \
  GITHUB_OUTPUT=/dev/null \
  bash scripts/generate-build-matrix.sh
)"

python3 - "${matrix}" <<'PY'
import json
import sys

data = json.loads(sys.argv[1])
items = data["include"]
assert [item["manager"] for item in items] == [
    "kernelsu-next",
    "sukisu-ultra",
    "resukisu",
]
assert [item["enable_susfs"] for item in items] == ["true", "true", "true"]
assert [item["label"] for item in items] == [
    "kernelsu-next-susfs",
    "sukisu-ultra-susfs",
    "resukisu-susfs",
]
PY

if BUILD_KERNELSU=true ENABLE_SUSFS=true GITHUB_OUTPUT=/dev/null \
  bash scripts/generate-build-matrix.sh >/dev/null 2>&1; then
  echo "FAIL: KernelSU + SUSFS matrix generation should be rejected" >&2
  exit 1
fi

echo "Matrix generator tests passed"
