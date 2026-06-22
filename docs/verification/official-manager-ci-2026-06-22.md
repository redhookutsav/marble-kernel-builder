# Official Manager CI Verification

Verified on 2026-06-22 from builder commit `0a842ae`.

## Supported Matrix

| Manager | Official source | SUSFS | CI run | Result |
|---|---|---:|---|---|
| KernelSU | `tiann/KernelSU@fda952bffe54c52d63f210358d47610cd9175cea` | off | `27933596271` | build, package, audit, artifact upload passed |
| KernelSU-Next | `KernelSU-Next/KernelSU-Next@30802e7260e2387176b9301377e88fc6fb0356b7` | off | `27933596110` | build, package, audit, artifact upload passed |
| KernelSU-Next | `pershoot/KernelSU-Next@5a8a604a9078c2fbfb50e2b0cba87b3a6f4da1c2` | v2.2.0 | `27937351021` | build, package, audit, artifact upload passed |
| KernelSU-Next | `pershoot/KernelSU-Next@5a8a604a9078c2fbfb50e2b0cba87b3a6f4da1c2` | v2.2.0 | `27939229556` | final SUSFS-only matrix build, package, audit, artifact upload passed |
| KernelSU-Next | `pershoot/KernelSU-Next@5a8a604a9078c2fbfb50e2b0cba87b3a6f4da1c2` | v2.2.0 | `27940668609` | strict release-summary template build, package, audit, artifact upload passed |
| SukiSU Ultra | `SukiSU-Ultra/SukiSU-Ultra@b88403d2561b6e00dff84a3c851e630c62f57fd0` | v2.2.0 | `27933596022` | build, package, audit, artifact upload passed |
| SukiSU Ultra | `SukiSU-Ultra/SukiSU-Ultra@b88403d2561b6e00dff84a3c851e630c62f57fd0` | v2.2.0 | `27939234278` | final SUSFS-only matrix build, package, audit, artifact upload passed |
| SukiSU Ultra | `SukiSU-Ultra/SukiSU-Ultra@b88403d2561b6e00dff84a3c851e630c62f57fd0` | v2.2.0 | `27940670539` | strict release-summary template build, package, audit, artifact upload passed |
| ReSukiSU | `ReSukiSU/ReSukiSU@8147c167a07ff2a3368ff31b790ad800a0d85211` | v2.2.0 | `27933596047` | build, package, audit, artifact upload passed |
| ReSukiSU | `ReSukiSU/ReSukiSU@6838204d58985296c7087d86f03af7a1df7668ac` | v2.2.0 | `27939239053` | final SUSFS-only matrix build, package, audit, artifact upload passed |
| ReSukiSU | `ReSukiSU/ReSukiSU@6838204d58985296c7087d86f03af7a1df7668ac` | v2.2.0 | `27940672290` | strict release-summary template build, package, audit, artifact upload passed |
| SukiSU Ultra | `SukiSU-Ultra/SukiSU-Ultra@b88403d2561b6e00dff84a3c851e630c62f57fd0` | v2.1.0 | `27934105424` | version selection, build, package, and audit passed |

SUSFS v2.2.0 is pinned to `4003ecf2d01c6d13fa8edf6c4f2607365738dc3d`. SUSFS v2.1.0 is pinned to `86114db0c49f20fa7857b8b559f3ab87cbc2d00d`.

## Rejected Matrix

| Manager | SUSFS | CI run | Result |
|---|---:|---|---|
| KernelSU | v2.2.0 | `27933596089` | rejected during input validation |
| KernelSU-Next official dev | v2.2.0 | `27936142485` | kernel-side SUSFS patch applied, but generic manager patch did not apply to official dev |

The rejected official KernelSU-Next combinations do not have a Marble-compatible official manager-side SUSFS path. Earlier exploratory KernelSU-Next `legacy-susfs` runs `27932281128` and `27932878089` failed compile/link verification and are not release-ready. The supported KernelSU-Next SUSFS path uses the pershoot `dev-susfs` fork branch.

## Artifact Audit

Every successful final zip contains 27 entries and includes `Image`, `anykernel.sh`, both `META-INF` installer files, `tools/ak3-core.sh`, `tools/magiskboot`, and `LICENSE`. Downloaded checksum files match the zip SHA256 values. Build summaries contain configuration, official manager app links, flashing instructions, bootloop recovery, artifacts, checksums, and credits.

Final artifacts were downloaded and audited under `docs/builds/final-0a842ae`, `docs/builds/final-extra-0a842ae`, and `docs/builds/final-susfs-a686fc3` in the project workspace.

The final SUSFS-only matrix generated these flashable zips:

- `AK3_Marble_android12-5.10_KSUNext-dev-susfs_5a8a604_SuSFS-v2.2.0_4003ecf_20260622_r43.zip`
- `AK3_Marble_android12-5.10_SukiSUUltra-builtin_b88403d_SuSFS-v2.2.0_4003ecf_20260622_r44.zip`
- `AK3_Marble_android12-5.10_ReSukiSU-main_6838204_SuSFS-v2.2.0_4003ecf_20260622_r45.zip`

After commit `8da4a3a`, the strict WildKernels-style summary template was verified by CI and downloaded under `docs/builds/final-susfs-8da4a3a` in the project workspace. These artifacts include the same generated summary for Actions summary and release notes, with unsupported upstream-only sections absent:

- `AK3_Marble_android12-5.10_KSUNext-dev-susfs_5a8a604_SuSFS-v2.2.0_4003ecf_20260622_r46.zip`
- `AK3_Marble_android12-5.10_SukiSUUltra-builtin_b88403d_SuSFS-v2.2.0_4003ecf_20260622_r47.zip`
- `AK3_Marble_android12-5.10_ReSukiSU-main_6838204_SuSFS-v2.2.0_4003ecf_20260622_r48.zip`

## Cache And Release

Final matrix ccache statistics show approximately 99.87% hits across cacheable calls. Run `27934105409` verified draft release creation for SukiSU Ultra + SUSFS v2.2.0:

- Draft: `marble-sukisu-ultra-susfs-37`
- Assets: flashable zip, SHA256 file, and `build-info.txt`
- Release notes: generated from the same complete markdown summary used by GitHub Actions

The obsolete fork-based draft release was removed.
