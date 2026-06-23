# Workflow Reliability CI Verification — 2026-06-23

Implementation commit: `865f9719a474555284d4165986a20ddb2bd4a71f`

| Workflow | Run | Result |
|---|---|---|
| Single — KernelSU-Next + SUSFS v2.2.0 | [28001500296](https://github.com/mohdakil2426/marble-kernel-builder/actions/runs/28001500296) | Passed |
| Matrix — KernelSU-Next, SukiSU Ultra, ReSukiSU + SUSFS v2.2.0 | [28002300749](https://github.com/mohdakil2426/marble-kernel-builder/actions/runs/28002300749) | All three builds passed |

The matrix artifacts were downloaded after the run. Each flashable ZIP contained 27 audited entries and matched its accompanying SHA-256 file. KernelSU-Next completed in 8m43s with a warm compiler cache: 3,008 of 3,012 cacheable calls hit (99.87%). SukiSU Ultra completed in 12m29s and ReSukiSU in 12m25s.

The first cold matrix attempt exposed HTTP 503 responses from the generated Gitiles archive endpoint. Retries recovered the transfer but a second download had different archive bytes and therefore a different whole-archive SHA-256. The reliable fix is to identify Android Clang by its source Git commit: partial-clone the official repository, verify `master-kernel-build-2021` resolves to `6e3223f76384455acde43affde3df0ea9df66c0d`, and sparse-checkout only `clang-r416183b`.

After verification, 11 obsolete compiler/ccache entries were removed. Four current caches remain (three manager-specific ccache entries plus the pinned Clang cache), totaling approximately 2.03 GiB.
