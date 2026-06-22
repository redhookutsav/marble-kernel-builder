<div align="center">

# 🪨 Marble Kernel Builder

**CI-driven AnyKernel3 kernel builder for Poco F5 / Redmi Note 12 Turbo**

[![Build](https://img.shields.io/badge/GitHub_Actions-CI_Builder-2088FF?logo=githubactions&logoColor=white)](https://github.com/mohdakil2426/marble-kernel-builder/actions)
[![KernelSU](https://img.shields.io/badge/KernelSU-Supported-4CAF50?logo=linux&logoColor=white)](https://github.com/tiann/KernelSU)
[![KernelSU-Next](https://img.shields.io/badge/KernelSU--Next-Supported-4CAF50?logo=linux&logoColor=white)](https://github.com/KernelSU-Next/KernelSU-Next)
[![SukiSU Ultra](https://img.shields.io/badge/SukiSU_Ultra-Supported-4CAF50?logo=linux&logoColor=white)](https://github.com/SukiSU-Ultra/SukiSU-Ultra)
[![ReSukiSU](https://img.shields.io/badge/ReSukiSU-Supported-4CAF50?logo=linux&logoColor=white)](https://github.com/ReSukiSU/ReSukiSU)
[![SUSFS](https://img.shields.io/badge/SUSFS-v2.2.0-FF6D00?logo=gitlab&logoColor=white)](https://gitlab.com/simonpunk/susfs4ksu)
[![Device](https://img.shields.io/badge/Device-Poco_F5_%2F_Redmi_Note_12_Turbo-EF5350)](https://github.com/mohdakil2426/android_kernel_xiaomi_marble)

</div>

---

## ⚠️ Disclaimer

> Flashing a custom kernel always carries a risk of bootloop or data loss. This builder is experimental — artifacts are provided as-is.
>
> - 💾 **Always back up your `boot.img`** from the same ROM/firmware before flashing
> - 🧠 **Understand what you are flashing** — read this README fully
> - 🔓 Unlocked bootloader is required
> - 📱 **Poco F5 (`marblein`) and Redmi Note 12 Turbo (`marble`) only**
>
> By flashing these artifacts **you accept all risk**. The maintainer is not responsible for bricked devices or data loss.

<div align="center">

### 🚨 Proceed at your own risk!

</div>

---

## 📖 Repository Model

This project uses a **two-repo separation** to keep the kernel source fork clean:

| Repo | Purpose |
|---|---|
| [`mohdakil2426/android_kernel_xiaomi_marble`](https://github.com/mohdakil2426/android_kernel_xiaomi_marble) | Clean upstream kernel source fork — never patched locally |
| [`mohdakil2426/marble-kernel-builder`](https://github.com/mohdakil2426/marble-kernel-builder) | This repo — CI workflows, scripts, config, and docs |

GitHub Actions checks out both repos separately, applies manager and SUSFS patches **only inside the temporary CI workspace**, builds, packages, and uploads artifacts. The source fork remains permanently clean.

---

## 🤖 Manager Matrix

| Manager | Without SUSFS | With SUSFS | Notes |
|---|:---:|:---:|---|
| `none` | ✅ | ❌ | Baseline no-root build only |
| `kernelsu` | ✅ | ❌ | Official only; no compatible SUSFS integration yet |
| `kernelsu-next` | ✅ | ✅ | Non-SUSFS → official `dev`; SUSFS → `pershoot/dev-susfs` |
| `sukisu-ultra` | ✅ | ✅ | Non-SUSFS → `main`; SUSFS → official `builtin` |
| `resukisu` | ✅ | ✅ | `main` includes built-in manager-side SUSFS support |

> **Policy:** Only official upstream manager repositories are used. Custom or forked manager repositories are rejected by the allowlist enforced at CI time. The one exception is `pershoot/KernelSU-Next@dev-susfs` for KernelSU-Next + SUSFS builds, which is a CI-proven fork branch carrying SUSFS integration based on the official `dev` branch.

---

## ⚙️ Workflow Inputs

| Input | Default | Description |
|---|---|---|
| `source_repo` | `mohdakil2426/android_kernel_xiaomi_marble` | Kernel source repository |
| `source_ref` | `melt-rebase` | Source branch, tag, or commit |
| `manager` | `none` | Root manager: `none`, `kernelsu`, `kernelsu-next`, `sukisu-ultra`, `resukisu` |
| `manager_ref` | *(empty)* | Override manager branch, tag, or commit (leave empty for defaults) |
| `enable_susfs` | `false` | Apply SUSFS kernel patches |
| `susfs_version` | `v2.2.0` | SUSFS preset: `v2.2.0`, `v2.1.0`, or `custom` |
| `susfs_kernel_branch` | `gki-android12-5.10` | SUSFS patch branch for Marble's 5.10 kernel |
| `susfs_ref` | *(empty)* | Custom SUSFS ref — required only when `susfs_version=custom` |
| `susfs_expected_version` | *(empty)* | Optional version guard for custom refs |
| `build_scope` | `image-only` | `image-only` or `full` (includes modules and dtbs) |
| `enable_ccache` | `true` | Use ccache to speed up rebuilds |
| `debug_artifacts` | `false` | Upload debug files on success; failed runs always upload available debug files |
| `make_release` | `false` | Create a draft GitHub release |

---

## 📦 Artifact Layout

### ✅ Successful build artifact

```
marble-flashable-<manager>-<scope>-<run>/
├─ AK3_Marble_android12-5.10_<manager>_<manager-sha>_<susfs>_<susfs-sha>_<date>_r<run>.zip
├─ AK3_Marble_android12-5.10_<manager>_<manager-sha>_<susfs>_<susfs-sha>_<date>_r<run>.zip.sha256
├─ build-info.txt      ← exact resolved refs and workflow metadata
├─ summary.md          ← build summary (also used for release notes)
├─ zip-audit.txt       ← structure audit results
└─ ccache-stats.txt
```

### 🐛 Debug artifact (on failure or `debug_artifacts=true`)

```
marble-debug-<manager>-<scope>-<run>/
├─ Image
├─ System.map
├─ vmlinux
├─ dtbs.tar.gz
├─ modules.tar.gz
└─ build.log
```

---

## 🔒 Verified Defaults

Last verified: **2026-06-22**

| Component | Default Ref | Pinned Commit / Version |
|---|---|---|
| SUSFS (v2.2.0) | `gki-android12-5.10` | `4003ecf2d01c6d13fa8edf6c4f2607365738dc3d` |
| SUSFS (v2.1.0) | `gki-android12-5.10` | `86114db0c49f20fa7857b8b559f3ab87cbc2d00d` |
| KernelSU | `tiann/KernelSU@main` | SUSFS disabled (no compatible official integration) |
| KernelSU-Next (no SUSFS) | `KernelSU-Next/KernelSU-Next@dev` | Official |
| KernelSU-Next (+ SUSFS) | `pershoot/KernelSU-Next@dev-susfs` | CI-proven |
| SukiSU Ultra | `SukiSU-Ultra/SukiSU-Ultra@main` / `builtin` | Official |
| ReSukiSU | `ReSukiSU/ReSukiSU@main` | Built-in SUSFS support |
| Android kernel Clang | `clang-r416183b` | Declared by `build.config.common` |

---

## 🧪 Safe Build Order

Run these in order — verify each before proceeding to the next:

1. `manager=none` · `enable_susfs=false` · `build_scope=image-only`
2. `manager=none` · `enable_susfs=false` · `build_scope=full`
3. `manager=kernelsu` · `enable_susfs=false`
4. `manager=kernelsu-next` · `enable_susfs=false`
5. `manager=sukisu-ultra` · `enable_susfs=false`
6. `manager=resukisu` · `enable_susfs=false`
7. SUSFS builds: `kernelsu-next`, `sukisu-ultra`, or `resukisu` with `enable_susfs=true` — leave `manager_ref` empty so the workflow selects the correct ref automatically

---

## 🚀 Flashing Instructions

### Prerequisites

- Unlocked bootloader
- Poco F5 (`marblein`) or Redmi Note 12 Turbo (`marble`) only
- Stock `boot.img` from the **same ROM/firmware** stored somewhere safe (outside the device)
- Matching manager app for root builds

### Via Kernel Flasher *(recommended)*

1. Download the flashable `.zip` and its `.sha256` file
2. Verify the checksum before flashing
3. Flash the ZIP to the active slot using [Kernel Flasher](https://github.com/fatalcoder524/KernelFlasher/releases)
4. The AnyKernel3 installer will verify the device codename (`marble` / `marblein`) and **automatically back up the current boot image** to `/sdcard/marble-kernel-backup/` before writing
5. Install the matching manager app after boot
6. If SUSFS is enabled, install the [KSU SUSFS module](https://github.com/sidex15/susfs4ksu-module/releases) and configure hiding rules

### Recovery from bootloop

Flash the stock `boot.img` from the same ROM/firmware back to the active slot. On A/B slot devices, target the correct slot or flash both.

---

## 🔗 Related Resources

| Resource | Link |
|---|---|
| 📱 Kernel Source Fork | [mohdakil2426/android_kernel_xiaomi_marble](https://github.com/mohdakil2426/android_kernel_xiaomi_marble) |
| 🏗️ Upstream Source | [Pzqqt/android_kernel_xiaomi_marble](https://github.com/Pzqqt/android_kernel_xiaomi_marble) |
| 🫙 AnyKernel3 | [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) |
| 🔑 KernelSU | [tiann/KernelSU](https://github.com/tiann/KernelSU) |
| 🔑 KernelSU-Next | [KernelSU-Next/KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) |
| 🔑 SukiSU Ultra | [SukiSU-Ultra/SukiSU-Ultra](https://github.com/SukiSU-Ultra/SukiSU-Ultra) |
| 🔑 ReSukiSU | [ReSukiSU/ReSukiSU](https://github.com/ReSukiSU/ReSukiSU) |
| 🛡️ SUSFS | [simonpunk/susfs4ksu](https://gitlab.com/simonpunk/susfs4ksu) |
| ⚡ Kernel Flasher | [fatalcoder524/KernelFlasher](https://github.com/fatalcoder524/KernelFlasher) |
| 📦 SUSFS Module | [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module) |

---

## 🙏 Credits

- **Pzqqt** — upstream Marble kernel source and maintenance
- **osm0sis** — AnyKernel3 flashing framework
- **tiann** — KernelSU
- **KernelSU-Next team** — KernelSU-Next
- **SukiSU Ultra team** — SukiSU Ultra
- **ReSukiSU team** — ReSukiSU
- **simonpunk** — susfs4ksu patches
- **WildKernels** — reference CI and release patterns
- Xiaomi/MIUI kernel source maintainers

---

<div align="center">

⚡ Built with ❤️ using GitHub Actions

</div>
