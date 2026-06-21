# Verified Defaults

Checked on 2026-06-22.

| Component | Repo | Default Ref | Version / Commit |
|---|---|---|---|
| Kernel source | `Pzqqt/android_kernel_xiaomi_marble` | `melt-rebase` | Poco F5 / marble source |
| Android kernel Clang | `https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86` | `master-kernel-build-2021` | `clang-r416183b`, matching `build.config.common` |
| SUSFS | `https://gitlab.com/simonpunk/susfs4ksu.git` | `gki-android12-5.10` | `SUSFS_VERSION v2.2.0`, commit `aee962343bc49469a5427a0e6987e6a70fe88ba3` |
| SUSFS older preset | `https://gitlab.com/simonpunk/susfs4ksu.git` | commit `8c79dcaa5e73bc33a33ff3af24c5db4eca8b6b0c` | `SUSFS_VERSION v2.1.0` |
| KernelSU | `tiann/KernelSU` | `main` | latest release `v3.2.4` |
| KernelSU-Next | `KernelSU-Next/KernelSU-Next` | `dev` | latest release `v3.2.0` |
| SukiSU Ultra | `SukiSU-Ultra/SukiSU-Ultra` | `main` | latest release `v4.1.3` |
| ReSukiSU | `ReSukiSU/ReSukiSU` | `main` | no GitHub release found; `kernel/setup.sh` exists |

The workflow resolves branch, tag, and commit inputs to exact commits at run time and records them in `release/build-info.txt`. For SUSFS, the user chooses `susfs_version=v2.2.0`, `susfs_version=v2.1.0`, or `susfs_version=custom`. Custom mode uses `susfs_ref` and verifies `susfs_expected_version` when provided.
