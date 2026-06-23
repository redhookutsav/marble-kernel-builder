# Workflow Reliability and Performance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the single and matrix kernel workflows share one reliable, secure, cache-efficient implementation that succeeds on free GitHub-hosted runners.

**Architecture:** Keep the two dispatch workflows as thin user-facing wrappers and move the build pipeline into a reusable `workflow_call` workflow. Resolve immutable source inputs before caching, treat manager version metadata as optional, and isolate release write permission in a separate job.

**Tech Stack:** GitHub Actions YAML, Bash, GitHub CLI, ccache, Android Clang, AnyKernel3.

---

## File Map

- Create `.github/workflows/build-core.yml`: reusable build and optional release jobs.
- Rewrite `.github/workflows/build-marble.yml`: single-build dispatch wrapper.
- Rewrite `.github/workflows/build-matrix.yml`: matrix generation/policy validation wrapper.
- Create `.github/dependabot.yml`: weekly official action update PRs.
- Modify `scripts/read-manager-version.sh`: safe multi-format metadata parsing.
- Create `tests/test-manager-version.sh`: regression cases for manager version parsing.
- Modify `scripts/build-kernel.sh`: safe 2 GiB ccache configuration.
- Modify `scripts/package-anykernel.sh`: immutable AnyKernel checkout and provenance.
- Modify `config/marble.env`: AnyKernel ref and pinned Clang Git commit.
- Update `README.md`, `docs/versions.md`, and Memory Bank files after remote verification.

### Task 1: Fix manager version detection with TDD

**Files:**
- Create: `tests/test-manager-version.sh`
- Modify: `scripts/read-manager-version.sh`

- [ ] **Step 1: Write failing parser cases**

Create temporary manager trees and assert that literal `KERNELSU_VERSION := 12345` and `KSU_VERSION = 13000` produce numeric metadata, while dynamic or absent assignments produce an empty value without failure. Pass an explicit `RESOLVED_REFS_FILE` so tests never touch repository output.

```bash
run_case literal-kernelsu 'KERNELSU_VERSION := 12345' 12345
run_case literal-ksu 'KSU_VERSION = 13000' 13000
run_case dynamic 'KSU_VERSION := $(shell expr 1 + 2)' ''
run_case missing '# no version' ''
```

- [ ] **Step 2: Verify RED**

Run: `bash tests/test-manager-version.sh`

Expected: FAIL because the current script ignores `RESOLVED_REFS_FILE`, exits on a failed grep under `pipefail`, and cannot parse `KSU_VERSION`.

- [ ] **Step 3: Implement minimal safe parsing**

Use a defaulted metadata path and one `sed` expression that accepts numeric literal assignments only:

```bash
RESOLVED_REFS_FILE="${RESOLVED_REFS_FILE:-release/resolved-refs.env}"
manager_version_code="$(
  sed -nE 's/^(KERNELSU_VERSION|KSU_VERSION)[[:space:]]*:?=[[:space:]]*([0-9]+)[[:space:]]*$/\2/p' \
    "${manager_makefile}" | head -n1 || true
)"
```

All output paths append to `RESOLVED_REFS_FILE`; missing/dynamic metadata warns and exits zero.

- [ ] **Step 4: Verify GREEN and regressions**

Run: `bash tests/test-manager-version.sh && bash tests/test-manager-policy.sh && bash tests/test-summary-format.sh && bash tests/test-susfs-presets.sh`

Expected: all tests print their pass messages and exit zero.

- [ ] **Step 5: Commit**

```bash
git add scripts/read-manager-version.sh tests/test-manager-version.sh
git commit -m "fix: make manager version metadata resilient"
```

### Task 2: Pin and verify build inputs

**Files:**
- Modify: `config/marble.env`
- Modify: `scripts/package-anykernel.sh`
- Modify: `.github/workflows/build-core.yml` in Task 3

- [ ] **Step 1: Resolve immutable values**

Resolve the official `master-kernel-build-2021` branch to its Git commit and confirm the reviewed AnyKernel3 commit exists upstream. Generated Gitiles archive bytes are not suitable as the immutable identity because repeated downloads can differ.

Run:

```bash
git ls-remote https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 \
  refs/heads/master-kernel-build-2021
gh api repos/osm0sis/AnyKernel3/commits/dca9dc370838d919d56c1f59ec78b27a14a72c68 --jq .sha
```

Expected: one exact Clang Git commit and the exact AnyKernel commit.

- [ ] **Step 2: Record immutable configuration**

Add:

```bash
ANYKERNEL3_REF=dca9dc370838d919d56c1f59ec78b27a14a72c68
ANDROID_CLANG_REF=master-kernel-build-2021
ANDROID_CLANG_REF_COMMIT=6e3223f76384455acde43affde3df0ea9df66c0d
```

- [ ] **Step 3: Fetch AnyKernel at the pinned commit**

Replace the moving shallow clone with an initialized repository and an exact fetch:

```bash
git init -q "${work_dir}/ak3"
git -C "${work_dir}/ak3" remote add origin "${ANYKERNEL3_REPO}"
git -C "${work_dir}/ak3" fetch --depth=1 origin "${ANYKERNEL3_REF}"
git -C "${work_dir}/ak3" checkout -q --detach FETCH_HEAD
echo "anykernel3_commit=$(git -C "${work_dir}/ak3" rev-parse HEAD)" >> release/resolved-refs.env
```

- [ ] **Step 4: Verify syntax and packaging tests**

Run: `bash -n scripts/package-anykernel.sh && git diff --check`

Expected: exit zero.

- [ ] **Step 5: Commit**

```bash
git add config/marble.env scripts/package-anykernel.sh
git commit -m "build: pin external packaging inputs"
```

### Task 3: Build the reusable workflow and cache design

**Files:**
- Create: `.github/workflows/build-core.yml`
- Modify: `scripts/build-kernel.sh`

- [ ] **Step 1: Define typed `workflow_call` inputs**

Define every value currently accepted by the single workflow plus `artifact_label` and `run_policy_tests`. Use `ubuntu-24.04`, a 120-minute timeout, and job-level `contents: read` for the build.

- [ ] **Step 2: Pin official actions**

Use exact SHAs with version comments:

```yaml
actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v7.0.0
actions/cache@27d5ce7f107fe9357f9df03efb73ab90386fccae # v5.0.5
actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1
actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1
```

Set `persist-credentials: false` for both checkouts.

- [ ] **Step 3: Make setup lean and deterministic**

Run policy tests only when `run_policy_tests` is true. Measure `/` availability and remove large SDK directories only below 20 GiB. Install required packages with `--no-install-recommends`.

- [x] **Step 4: Verify the pinned Clang Git commit**

On a toolchain cache miss, use a partial clone and sparse checkout for `clang-r416183b`, verify the requested branch resolves to commit `6e3223f76384455acde43affde3df0ea9df66c0d`, then check out that commit. Include OS, architecture, version, and commit in the toolchain cache key.

- [ ] **Step 5: Resolve refs before restoring ccache**

After source checkout, run `resolve-refs.sh`, source `release/resolved-refs.env`, hash compilation-affecting files, and emit a cache key containing source, manager, SUSFS, compiler, scope, and config identities.

- [ ] **Step 6: Configure safe ccache behavior**

In `build-kernel.sh` use:

```bash
export CCACHE_COMPILERCHECK=content
ccache -M 2G
ccache -o compression=true
```

Restore/save through cache v5. Cache misses are non-fatal and saves occur only after successful builds.

- [ ] **Step 7: Tune artifacts and metadata**

Flash artifacts use `compression-level: 0` and `retention-days: 30`; debug artifacts use level 0 and 7 days. Add runner image, cache key/hit, Clang version/commit, and AnyKernel commit to `build-info.txt`.

- [ ] **Step 8: Isolate release write permission**

Expose the flash artifact name as a build output. A conditional release job with `contents: write` downloads that artifact and creates the draft release. The build job remains read-only.

- [ ] **Step 9: Validate structure**

Run: `bash -n scripts/build-kernel.sh && git diff --check`

Expected: exit zero.

- [ ] **Step 10: Commit**

```bash
git add .github/workflows/build-core.yml scripts/build-kernel.sh
git commit -m "ci: add reusable optimized build workflow"
```

### Task 4: Convert dispatch workflows and automate action updates

**Files:**
- Modify: `.github/workflows/build-marble.yml`
- Modify: `.github/workflows/build-matrix.yml`
- Create: `.github/dependabot.yml`

- [ ] **Step 1: Convert the single workflow**

Keep its public inputs unchanged. Replace duplicated build steps with a local reusable-workflow call, pass `run_policy_tests: true`, and grant the called workflow `contents: write` as the permission ceiling needed by its isolated optional release job.

- [ ] **Step 2: Convert the matrix workflow**

Keep matrix generation and `fail-fast: false`. Pin checkout v7 in setup, run all `tests/test-*.sh` once there, and call the reusable workflow for each matrix entry with `run_policy_tests: false`.

- [ ] **Step 3: Add Dependabot**

Create weekly GitHub Actions updates:

```yaml
version: 2
updates:
  - package-ecosystem: github-actions
    directory: /
    schedule:
      interval: weekly
```

- [ ] **Step 4: Check public input compatibility**

Compare all old dispatch input names/defaults with the rewritten wrappers. Confirm manager/SUSFS policy and artifact labels remain unchanged.

- [ ] **Step 5: Commit**

```bash
git add .github/workflows/build-marble.yml .github/workflows/build-matrix.yml .github/dependabot.yml
git commit -m "ci: share build pipeline across dispatch workflows"
```

### Task 5: Full local verification and review

**Files:** all changed implementation files.

- [ ] **Step 1: Run all shell tests**

Run: `for test_script in tests/test-*.sh; do bash "$test_script"; done`

Expected: every test exits zero.

- [ ] **Step 2: Parse every shell script**

Run: `for script in scripts/*.sh tests/*.sh; do bash -n "$script"; done`

Expected: exit zero.

- [ ] **Step 3: Validate repository state**

Run: `git diff --check && git status --short && git log --oneline -8`

Expected: no whitespace errors and only planned files/commits.

- [ ] **Step 4: Review five quality axes**

Review tests first, then workflow/scripts for correctness, simplicity, architecture, security, and performance. Fix all blocking findings and rerun Steps 1–3.

### Task 6: Publish and verify GitHub Actions

- [ ] **Step 1: Push verified commits**

Run: `git push origin main`

Expected: remote main advances to the verified local HEAD.

- [ ] **Step 2: Dispatch the previous matrix**

Run `build-matrix.yml` on `main` with KernelSU-Next, SukiSU Ultra, and ReSukiSU selected; SUSFS v2.2.0; image-only; ccache enabled; debug/release disabled.

- [ ] **Step 3: Monitor to completion**

Capture the dispatched run URL in `RUN_URL`, set `RUN_ID="${RUN_URL##*/}"`, then run: `gh run watch "$RUN_ID" --exit-status`.

Expected: setup and all three build calls succeed.

- [ ] **Step 4: Inspect artifacts and cache statistics**

Confirm three unique flashable artifacts exist, each contains audit/summary/build-info, and cache keys reflect resolved immutable inputs.

- [ ] **Step 5: Handle failures scientifically**

For any failing job, fetch `gh run view "$RUN_ID" --log-failed`, identify one root cause, add a reproducing test when local behavior is involved, apply one focused fix, reverify locally, push, and rerun the same matrix.

### Task 7: Cache cleanup and documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/versions.md`
- Modify outside repo: `../memory-bank/activeContext.md`, `../memory-bank/progress.md`, and other Memory Bank files only where facts changed.

- [ ] **Step 1: Prune obsolete cache keys**

Only after the replacement matrix succeeds, delete caches using the legacy `marble-builder-ccache-` key scheme while preserving new schema caches and the pinned Clang cache.

- [ ] **Step 2: Document versions and architecture**

Record pinned action versions, AnyKernel commit, Clang Git commit policy, ccache key strategy/size, artifact retention, reusable workflow design, and successful run URL.

- [ ] **Step 3: Update Memory Bank**

Replace stale latest-commit/current-status claims and record the manager-version failure/fix, workflow architecture, cache policy, and final CI evidence.

- [ ] **Step 4: Verify documentation and commit**

Run: `git diff --check` and review links/commit IDs/run IDs for accuracy.

```bash
git add README.md docs/versions.md
git commit -m "docs: record optimized workflow verification"
git push origin main
```

- [ ] **Step 5: Final status check**

Run: `git status -sb`, `gh run view "$RUN_ID" --json status,conclusion,url,jobs`, and `gh cache list`.

Expected: clean synchronized worktree, successful matrix, and cache usage below the default repository limit.
