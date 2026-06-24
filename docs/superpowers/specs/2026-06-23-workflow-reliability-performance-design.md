# Workflow Reliability and Performance Design

> Historical note: this design is superseded by the 2026-06-24 CI hardening pass. Debug artifacts were removed, build metadata now includes `build-info.json`, release creation moved to `release-core.yml`, and build ZIPs receive GitHub artifact attestations.

## Goal

Make both Marble kernel workflows reliable, maintainable, secure, and faster on free GitHub-hosted runners while preserving the currently boot-tested kernel, manager, and SUSFS behavior.

Success means:

- The single-build and matrix entrypoints use the same build implementation.
- KernelSU, KernelSU-Next, SukiSU Ultra, and ReSukiSU version metadata never aborts an otherwise valid build.
- The three-manager SUSFS v2.2.0 matrix completes and uploads audited artifacts.
- Cache use stays below the repository limit and cannot reuse objects built with a different compiler or resolved source configuration.
- External actions and downloaded build inputs are immutable and verifiable.
- No paid runner, custom runner, or custom container is required.

## Scope

### Included

- Manager version detection fix and regression coverage.
- Reusable workflow extraction for the shared build pipeline.
- Latest compatible official GitHub Actions, pinned to full commit SHAs.
- Ccache correctness, keying, size, and cleanup improvements.
- Conditional disk cleanup and leaner dependency installation.
- Artifact upload performance and retention settings.
- Least-privilege permissions and checkout credential hardening.
- AnyKernel3 commit pinning and Android Clang Git commit verification.
- Dependabot configuration for GitHub Actions updates.
- Performance and provenance metadata sufficient to diagnose future regressions.
- Documentation and Memory Bank updates after verification.

### Excluded

- Paid larger runners.
- Self-hosted runners.
- A custom GHCR builder image.
- Replacing the kernel-required `clang-r416183b` toolchain.
- Changing manager allowlist policy, SUSFS pins, kernel features, or flash behavior.

## Chosen Architecture

Keep `build-marble.yml` and `build-matrix.yml` as user-facing dispatch workflows. Move their duplicated build steps into one reusable workflow invoked with explicit inputs. The matrix workflow retains its setup job and calls the reusable workflow once per generated matrix entry with `fail-fast: false`.

The reusable workflow owns validation, source checkout, ref resolution, cache restoration, patching, compilation, packaging, auditing, artifact upload, and optional draft release creation. Build jobs use read-only repository permissions. A separate release job receives write permission only when release creation is requested.

This keeps both entrypoints behaviorally identical and prevents future fixes from landing in only one workflow.

## Manager Version Detection

`read-manager-version.sh` will treat version metadata as optional enrichment, never as a build prerequisite.

It will:

1. Locate the installed manager Makefile using the existing candidate directories.
2. Read known assignment forms such as `KERNELSU_VERSION` and `KSU_VERSION` without allowing a no-match `grep` status to terminate the script.
3. Accept only a resolved numeric value for `manager_version_code`.
4. Emit a warning and store an empty value when a manager computes the version dynamically or exposes no numeric literal.
5. Preserve tag/SHA fallback naming when the numeric code is unavailable.

Tests will cover no manager, both supported variable names, whitespace/assignment variations, missing Makefiles, dynamic values, and no matching version variable.

## Cache Design

Android Clang remains a separate immutable cache keyed by runner OS/architecture, Clang version, verified Git commit, and cache schema version.

Ccache restoration happens after source checkout and manager/SUSFS ref resolution. Its primary identity includes:

- runner OS and architecture;
- cache schema version;
- Android Clang version and verified Git commit;
- resolved kernel source commit;
- resolved manager commit;
- resolved SUSFS commit or `none`;
- build scope;
- hashes of build configuration and scripts that affect compilation.

The ccache maximum is reduced from 10 GiB to 2 GiB and compiler checking changes from `none` to content-based validation. Broad restore prefixes may reuse compatible source/compiler objects, but must never cross compiler or architecture boundaries.

After a successful replacement build, obsolete caches from the previous key scheme will be removed once. Normal GitHub eviction remains the long-term cleanup mechanism.

## Dependencies and Immutable Inputs

- Keep `ubuntu-24.04` instead of the moving `ubuntu-latest` label for build jobs.
- Upgrade the official actions to the latest compatible releases researched on 2026-06-23 and pin each to its full commit SHA with a version comment: `actions/checkout` v7.0.0 (`9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0`), `actions/cache` v5.0.5 (`27d5ce7f107fe9357f9df03efb73ab90386fccae`), and `actions/upload-artifact` v7.0.1 (`043fb46d1a93c77aae656e7c1c64a875d1fc6a0a`).
- Add Dependabot weekly checks for the `github-actions` ecosystem.
- Use Ubuntu 24.04 supported package versions with `--no-install-recommends`; do not compile newer host tools during every run.
- Keep `clang-r416183b` because it is declared by the kernel source. Fetch only that directory from the official Git repository using partial clone and sparse checkout, after verifying branch `master-kernel-build-2021` resolves to commit `6e3223f76384455acde43affde3df0ea9df66c0d`.
- Pin AnyKernel3 to a reviewed commit rather than cloning a moving default branch. Record the commit in build metadata.
- Continue resolving moving manager refs to immutable commits before use and recording those commits in artifacts.

## Performance Changes

- Run policy tests once before matrix fan-out instead of once per manager job.
- Measure free disk first and perform the existing large SDK cleanup only when root filesystem availability is below 20 GiB.
- Preserve shallow kernel source checkout; caching the Git repository is excluded because it adds invalidation complexity for modest savings.
- Continue using all available runner cores through `make -j$(nproc)`.
- Set artifact compression to zero for already-compressed ZIP/TAR files and binary-heavy debug artifacts.
- Retain flashable artifacts for 30 days and debug artifacts for 7 days.
- Record cache-hit status, ccache statistics, runner image identity, disk usage, and key phase timings for comparison.

No `max-parallel` limit will be added: the three independent free hosted jobs should remain parallel.

## Security

- Pin all external actions to immutable SHAs.
- Use `persist-credentials: false` on checkouts that do not push.
- Default workflow permissions to `contents: read` and grant `contents: write` only to the release job.
- Verify the compiler repository ref against the pinned Git commit before checkout.
- Keep the existing official-manager allowlist and resolved-commit execution model.
- Do not include hidden files in artifacts unless explicitly required.

## Error Handling

- Metadata enrichment failures warn and continue when they do not affect kernel correctness.
- Missing or mismatched compiler commits, unsupported inputs, failed patches, invalid final Kconfig, missing kernel images, and invalid flashable ZIPs remain hard failures.
- Cache misses never fail a build; corrupted or incompatible compiler input must fail before compilation.
- Debug artifact upload remains enabled on failure and must retain the build log when one exists.

## Verification

Local verification will include:

- Red/green tests for manager version parsing.
- All existing policy, SUSFS preset, and summary tests.
- `bash -n` for every shell script.
- Workflow structure checks and diff whitespace validation.
- A focused review across correctness, simplicity, security, and performance.

Remote verification will run the same image-only SUSFS v2.2.0 matrix used previously:

- KernelSU-Next
- SukiSU Ultra
- ReSukiSU

Completion requires all three jobs to compile, audit, and upload artifacts. Cache statistics and setup timings will be compared with prior runs. The single-build workflow will also be checked for shared-workflow input compatibility.

## Delivery

Implementation will be divided into focused commits where practical: reliability/tests, reusable workflow and action upgrades, cache/performance/security, then documentation. Changes will be pushed only after local verification. CI failures will be investigated from logs and fixed at their root cause; unrelated refactoring is out of scope.
