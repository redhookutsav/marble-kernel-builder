# Marble Kernel Builder — Project Improvement Analysis

Date: 2026-06-24  
Original scope: analysis only.  
Constraint: keep everything free/no-cost; no paid runners, no paid services, no custom paid infrastructure.

> Implementation follow-up: the main hardening recommendations from this report were implemented later on 2026-06-24: preflight CI, shared summary helpers, structured `build-info.json`, data-driven matrix generation, workflow concurrency, release-core permission isolation, and ZIP artifact attestations. Non-zipped artifact upload was evaluated but not applied because GitHub's `archive: false` mode only supports a single file, while the project intentionally uploads ZIP + checksum + metadata together.

## Executive summary

The project is already in a strong place: the build path is centralized in `build-core.yml`, official actions are pinned, debug artifacts are removed, ccache is enabled with content-based compiler validation, matrix builds use the reusable workflow, and the matrix summary is combined into one readable report.

The next best improvements are not “make the kernel compile faster by magic.” The most valuable work now is to reduce maintenance risk and avoid future CI regressions:

1. Extract common summary-rendering logic shared by `generate-build-summary.sh` and `generate-matrix-summary.sh`.
2. Add a lightweight static preflight workflow for shell/YAML/policy checks so expensive kernel builds fail less often.
3. Make matrix generation more data-driven from `config/managers.json`.
4. Move free-text metadata away from sourceable `.env` files and toward a JSON metadata file.
5. Consider GitHub artifact attestations for release ZIP provenance if the repository remains public.
6. Keep optimizing cache behavior with measured experiments, not blind ccache “sloppiness.”

## Current architecture health

### What is working well

- `build-core.yml` is the single build implementation for single and matrix dispatches.
- `build-marble.yml` and `build-matrix.yml` are thin wrappers, which is the right shape.
- `config/managers.json` is already the source of truth for manager repos/default refs.
- Runtime scripts are small and mostly focused.
- Flash artifacts are now lean: ZIP, checksum, metadata, summary, audit, ccache stats, and zip-name metadata.
- Debug artifact uploads are removed, which avoids the previous 500MB+ artifact problem.
- Official GitHub actions are pinned by commit and Dependabot tracks GitHub Actions weekly.
- Matrix summary aggregation uses `marble-flash-*`, avoiding accidental non-flash artifact downloads.

### Main risks left

- Summary rendering is duplicated across two large scripts.
- `resolved-refs.env` / `build-info.txt` are source-style key/value files; this is convenient but fragile when values can contain spaces, commas, quotes, or shell metacharacters.
- Matrix generation still duplicates manager policy in Bash instead of deriving most of it from `config/managers.json`.
- There is no dedicated “cheap preflight CI” workflow for workflow/script/docs changes.
- Historical planning docs under `docs/superpowers/` still describe old debug-artifact behavior. They are not runtime files, but future readers may confuse them with current policy.

## Script usage audit

No unused runtime script was found. Every file under `scripts/*.sh` is called by the workflow, by tests, or both.

| Script | Runtime usage | Test coverage / reference | Status |
|---|---|---|---|
| `scripts/validate-inputs.sh` | `build-core.yml` | `test-manager-policy.sh` | Used |
| `scripts/resolve-refs.sh` | `build-core.yml` | indirectly covered through workflow policy | Used |
| `scripts/patch-manager.sh` | `build-core.yml` | `test-manager-policy.sh` checks pinned commit invocation | Used |
| `scripts/read-manager-version.sh` | `build-core.yml` | `test-manager-version.sh` | Used |
| `scripts/read-manager-build-metadata.sh` | `build-core.yml` | `test-manager-build-metadata.sh` | Used |
| `scripts/apply-susfs.sh` | `build-core.yml` | `test-susfs-presets.sh` / policy tests indirectly | Used |
| `scripts/build-kernel.sh` | `build-core.yml` | `test-workflow-policy.sh` checks ccache policy | Used |
| `scripts/package-anykernel.sh` | `build-core.yml` | `test-build-input-pins.sh` | Used |
| `scripts/audit-flashable-zip.sh` | `build-core.yml` | workflow runtime audit | Used |
| `scripts/generate-build-summary.sh` | `build-core.yml` | `test-summary-format.sh` | Used |
| `scripts/generate-matrix-summary.sh` | `build-matrix.yml` aggregate job | `test-matrix-summary.sh` | Used |

### Non-runtime stale references

These are not unused scripts, but stale historical docs:

- `docs/superpowers/plans/2026-06-23-workflow-reliability-performance.md`
- `docs/superpowers/specs/2026-06-23-workflow-reliability-performance-design.md`

They still mention debug artifacts and 7-day debug retention. Since they are historical planning artifacts, the best fix is not deletion by default. Better options:

- Add a short “Historical; superseded on 2026-06-24 by debug artifact removal” note at the top.
- Or move old plans under `docs/archive/`.

## Priority recommendations

### P1 — Extract shared summary logic

Current state:

- `generate-build-summary.sh`: 304 lines.
- `generate-matrix-summary.sh`: 332 lines.
- Both duplicate helpers and content patterns:
  - `short_commit`
  - `badge_encode`
  - manager display names
  - manager app URLs
  - Installation section
  - warning block
  - credits style
  - artifact/checksum rendering style

Recommendation:

Create a small shared library, for example:

```text
scripts/lib/summary-common.sh
```

Move only stable helpers first:

- `get_info`
- `short_commit`
- `badge_encode`
- `manager_display`
- `manager_app_url`
- `render_install_warning`
- `render_common_credits_row`

Do not rewrite the whole summary system in one pass. Keep the visual style exactly the same and reduce duplication gradually.

Why it helps:

- Future style changes happen once.
- Matrix and single summaries stay visually consistent.
- Less chance of one summary supporting new metadata while the other forgets it.

Risk:

- Medium, because summary formatting is user-facing and easy to accidentally change.

Verification:

- Extend `test-summary-format.sh`.
- Extend `test-matrix-summary.sh`.
- Add before/after generated summary snapshots if desired.

### P1 — Add a cheap static preflight workflow

Current state:

- Static checks exist as shell tests, but they run inside build/matrix policy flow.
- There is no separate workflow whose only job is to validate scripts/workflows without compiling the kernel.

Recommendation:

Add a lightweight workflow such as:

```text
.github/workflows/preflight.yml
```

Run on:

- `push` to `main`
- `pull_request`
- `workflow_dispatch`

Checks:

- `bash -n scripts/*.sh tests/*.sh`
- `bash tests/test-*.sh`
- `actionlint`
- `shellcheck scripts/*.sh tests/*.sh` if installed or installed via apt
- `git diff --check`

Why it helps:

- Catches YAML/script mistakes before a 10–60 minute kernel build.
- Very low/no cost compared with matrix kernel builds.
- Makes workflow refactors safer.

Docs backing:

- GitHub job summaries are intended to surface useful results without digging through logs, and `GITHUB_STEP_SUMMARY` supports Markdown summaries for this kind of reporting: [GitHub workflow commands — job summaries](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands).

Risk:

- Low. This does not change the kernel build path.

### P1 — Replace sourceable free-text metadata with JSON as canonical metadata

Current state:

- `release/resolved-refs.env` is sourced by scripts.
- `build-info.txt` is key/value text.
- A real bug already happened because ReSukiSU emitted `MKSU, RKSU, ...`, and sourcing the env-style file treated part of the value as shell syntax.

Recommendation:

Keep `resolved-refs.env` only for strict shell-safe machine fields.

Add canonical JSON:

```text
release/build-info.json
```

Use it for:

- summary generation
- matrix aggregation
- release notes
- future metadata fields

Keep `build-info.txt` as a human-readable export if desired.

Why it helps:

- Free-text values become safe by default.
- No future quote/space/comma shell parsing bugs.
- Easier to validate with `jq`.
- Easier to extend with nested sections like `manager`, `susfs`, `compiler`, `artifact`, `cache`.

Risk:

- Medium. This touches metadata producers and summary consumers.

Safe migration plan:

1. Generate JSON alongside current files.
2. Add tests that compare JSON and env/text values.
3. Switch summaries to JSON.
4. Keep `.env` only for packaging shell needs.

### P1 — Make matrix generation data-driven

Current state:

- `config/managers.json` defines allowed managers and refs.
- `build-matrix.yml` still hardcodes each selected manager in Bash.

Recommendation:

Keep the static GitHub UI checkboxes, because `workflow_dispatch` inputs cannot be dynamically generated from JSON.

But after inputs arrive, generate the matrix using `jq` and `config/managers.json`:

- Read manager metadata from `config/managers.json`.
- Decide SUSFS support from config fields.
- Build label from manager slug + SUSFS state.
- Reject unsupported combinations through the existing validation policy.

Why it helps:

- New manager or ref changes happen mostly in one config file.
- Less duplication between `validate-inputs.sh`, `build-matrix.yml`, docs, and tests.
- Makes config the real source of truth.

Docs backing:

- GitHub reusable workflows support matrix jobs calling a reusable workflow, which is already the correct architecture here: [GitHub Docs — reusable workflows with matrix](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows).

Risk:

- Medium. Matrix generation affects CI fan-out.

Verification:

- Expand `test-manager-policy.sh`.
- Add a dedicated matrix-generation test that asserts exact JSON for common selections.

### P2 — Add workflow-level concurrency guard for accidental duplicate manual runs

Current state:

- Manual dispatch can start multiple expensive builds for the same source/manager/scope if clicked repeatedly.

Recommendation:

Add conservative concurrency to single and matrix workflows. Do not cancel in-progress builds by default unless the user explicitly wants that behavior.

Possible policy:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false
```

For a more exact group, include selected inputs, but keep it readable.

Why it helps:

- Prevents duplicate pending runs from piling up.
- Keeps free GitHub-hosted minutes healthier.

Docs backing:

- GitHub concurrency can ensure one running/pending workflow or job per group; `cancel-in-progress` controls whether an active run is canceled: [GitHub Docs — control workflow concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency).

Risk:

- Low to medium. Bad group names can block unrelated experiments, so this should be designed carefully.

### P2 — Investigate `upload-artifact` non-zipped artifact mode

Current state:

- The build creates a flashable ZIP.
- GitHub artifact upload can still wrap uploaded contents as an artifact archive.
- Artifact compression is already `0`, which is good for speed.

Recommendation:

Investigate whether `actions/upload-artifact@v7` with non-zipped artifact support improves user download experience for flashable ZIPs.

Why it helps:

- May avoid “ZIP inside artifact ZIP” style confusion.
- Could make downloads cleaner for end users.

Docs backing:

- `upload-artifact` recommends `compression-level: 0` for large data that does not benefit from compression: [actions/upload-artifact README](https://github.com/actions/upload-artifact).
- GitHub announced non-zipped artifact upload/download support in 2026, requiring `upload-artifact` v7 and `download-artifact` v8 for that mode: [GitHub changelog — non-zipped artifacts](https://github.blog/changelog/2026-02-26-github-actions-now-supports-uploading-and-downloading-non-zipped-artifacts/).

Risk:

- Medium. Artifact UX changes can surprise users, so test on one manual run before adopting.

### P2 — Add artifact attestations for release ZIP provenance

Current state:

- ZIP SHA256 is generated.
- Exact source/manager/SUSFS commits are recorded.
- There is no signed provenance attestation.

Recommendation:

For public repo releases, consider adding GitHub artifact attestations for the flashable ZIP.

Why it helps:

- Users can verify the ZIP came from the expected repository/workflow/commit.
- Strengthens supply-chain trust without paid infrastructure for a public repository.

Docs backing:

- GitHub artifact attestations are available on Free/Pro/Team plans for public repositories, and require `id-token: write`, `contents: read`, and `attestations: write` permissions plus `actions/attest`: [GitHub Docs — use artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations).

Risk:

- Medium. It adds a new permission and action. Keep it only around final artifact generation, not every step.

### P2 — Revisit release permission structure

Current state:

- `build-core.yml` internally separates build job (`contents: read`) and release job (`contents: write`).
- The caller job in `build-marble.yml` / `build-matrix.yml` grants `contents: write` to the reusable workflow call so the optional release job can work.

Recommendation:

Consider splitting release creation out of the reusable build workflow:

- `build-core.yml`: always read-only, always builds/uploads artifacts.
- caller-level release job or separate `release-core.yml`: write permission only when `make_release=true`.

Why it helps:

- Cleaner least-privilege story.
- Normal build calls do not need a write-capable reusable workflow ceiling.

Docs backing:

- GitHub recommends granting `GITHUB_TOKEN` the minimum required permissions and increasing permissions only for jobs that need them: [GitHub secure use reference](https://docs.github.com/en/actions/reference/security/secure-use).
- Reusable workflow permissions can be maintained or reduced, not elevated, across nested workflow chains: [GitHub Docs — reusable workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows).

Risk:

- Medium. Release behavior needs careful regression testing.

### P2 — Improve cache observability before changing cache policy

Current state:

- ccache stats are saved in artifacts.
- Cache key includes source, manager, SUSFS, scope, compiler, and config hash.
- ccache max size is 2 GiB.

Recommendation:

Before changing cache behavior, collect comparable metrics in `build-info.txt` / summary:

- exact cache hit: true/false/empty
- restore key used, if available
- ccache hit rate
- ccache cache size
- compile duration
- package duration
- artifact upload duration

Then experiment with one variable at a time:

- Save ccache on failed builds if not canceled, because partial successful compilations can still be useful.
- Set `SEGMENT_DOWNLOAD_TIMEOUT_MINS` if cache downloads ever hang.
- Benchmark ccache `CCACHE_BASEDIR` / `CCACHE_NOHASHDIR` behavior carefully.

Docs backing:

- `actions/cache` supports granular restore/save, `lookup-only`, `fail-on-cache-miss`, and segment timeout tuning: [actions/cache README](https://github.com/actions/cache).
- ccache warns that disabling directory hashing can increase cross-directory hits but may produce incorrect debug working-directory info; ccache also documents sloppiness as a deliberate trade-off that can produce false hits if misused: [ccache manual](https://ccache.dev/manual/4.13.6.html).

Risk:

- Medium. Cache changes can silently affect reproducibility if done too aggressively.

### P2 — Add shellcheck to quality gates

Current state:

- Scripts use `set -euo pipefail`.
- Existing tests are good.
- Local environment did not show `shellcheck` as installed during this analysis.

Recommendation:

Use shellcheck in the proposed preflight workflow. If local Windows does not have it, install in CI with apt.

Why it helps:

- Catches quoting, array, sourcing, and globbing mistakes.
- Especially valuable because this repo is mostly Bash glue.

Risk:

- Low, but first run may reveal warnings that need triage.

### P3 — Add summary size guard

Current state:

- Matrix summary is compact for current manager count.
- GitHub step summary has a per-step size limit.

Recommendation:

Add a test that generated summaries stay comfortably below GitHub’s step summary limit.

Docs backing:

- GitHub documents job-summary step isolation and a 1 MiB per-step summary limit: [GitHub workflow commands — step isolation and limits](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands).

Risk:

- Low.

### P3 — Archive or annotate old planning docs

Current state:

- Historical docs under `docs/superpowers/` still mention debug artifacts.

Recommendation:

Do not delete them automatically. Either:

- add a superseded note at the top, or
- move them under `docs/archive/`.

Why it helps:

- Avoids confusing future agents/users.
- Keeps history without making it look current.

Risk:

- Low.

## Performance notes

### What is already optimized

- `fetch-depth: 1` for kernel source checkout.
- Android Clang is cached separately.
- ccache is enabled and keyed by meaningful build identity.
- Artifact compression is `0`.
- Debug artifacts are removed.
- Matrix builds run in parallel and share the same core workflow.

### What probably will not help much

- More Bash micro-optimizations. Kernel compile time dominates.
- More aggressive ccache sloppiness without measurement.
- More artifact compression. The flash ZIP is already compressed; extra compression wastes CPU.
- Paid/larger runners, because the project constraint is free/no-cost.

### Best performance experiments

1. Measure step durations and cache hit rate in summary.
2. Try saving ccache on failed-but-not-canceled builds.
3. Investigate non-zipped artifact mode.
4. Consider concurrency guard for accidental duplicate runs.
5. Keep dependency installs lean; only add tools like shellcheck to cheap preflight, not necessarily to every kernel build.

## Reusability notes

Best next reusable design:

```text
scripts/lib/
├── metadata.sh          # source-safe env writing, JSON writing helpers
├── summary-common.sh    # display names, badges, shared sections
└── workflow-common.sh   # small shared validation helpers if needed
```

Keep this small. Do not build a large framework. The repo’s strength is that each script is currently understandable.

## Suggested implementation order

1. Add preflight workflow.
2. Add shellcheck and actionlint gates there.
3. Extract `summary-common.sh` helpers only.
4. Add `build-info.json` alongside current metadata.
5. Switch summary scripts to JSON.
6. Convert matrix generation to derive from `config/managers.json`.
7. Experiment with artifact non-zipped mode on one manual run.
8. Consider artifact attestation for release ZIP.
9. Revisit release permission split.

## Final verdict

The project does not need a big rewrite. It needs small, deliberate hardening passes.

Most important finding: there are no unused runtime scripts to remove right now. The better cleanup target is duplicated summary code and stale historical docs. The biggest reliability improvement is moving human/free-text metadata out of sourceable env files and into JSON.

## Sources

- [GitHub Docs — Reuse workflows](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows)
- [GitHub Docs — Control workflow concurrency](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/control-workflow-concurrency)
- [GitHub Docs — Workflow commands / job summaries](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands)
- [GitHub Docs — Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use)
- [GitHub Docs — Artifact attestations](https://docs.github.com/en/actions/how-tos/secure-your-work/use-artifact-attestations/use-artifact-attestations)
- [actions/cache README](https://github.com/actions/cache)
- [actions/upload-artifact README](https://github.com/actions/upload-artifact)
- [GitHub changelog — non-zipped artifacts](https://github.blog/changelog/2026-02-26-github-actions-now-supports-uploading-and-downloading-non-zipped-artifacts/)
- [ccache manual 4.13.6](https://ccache.dev/manual/4.13.6.html)
