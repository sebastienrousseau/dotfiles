---
render_with_liquid: false
---

# CI Cadence

This page tabulates every GitHub Actions workflow in `.github/workflows/`
with its trigger cadence and the rationale for that cadence. Maintained
under [issue #861](https://github.com/sebastienrousseau/dotfiles/issues/861).

## Cadence rules

We use four cadence buckets:

| Bucket | When | Used for |
|---|---|---|
| **Event** | `push`, `pull_request`, `merge_group`, `release` | Code-change gates and release steps. |
| **Daily** | `schedule:` every day | Only where a daily signal is consumed; two workflows today, see below. |
| **Weekly** | `schedule:` one day a week (Sunday, Monday or Tuesday) | Drift detection, beta-tool watch, extended platform matrices, external-feed checks. |
| **Manual** | `workflow_dispatch` only | Ad-hoc tooling. |

**Anti-rule:** no workflow runs on a daily cron (`'0 2 * * *'` and the
like) unless its output is consumed daily by something downstream.
Two meet that bar today: `drift-detection.yml` and
`mutation-nightly.yml`. See "Why no daily jobs" below for the original
review.

## Workflow cadence table

"dispatch" means `workflow_dispatch`; "paths" means the push or PR
trigger is path-filtered.

| Workflow | Triggers | Schedule (UTC) | Why this cadence |
|---|---|---|---|
| `branch-drift-guard.yml` | schedule + dispatch | Mon 07:00 (weekly) | Long-lived branches must not silently drift from `main`; a weekly check is enough. |
| `cflite_pr.yml` | PR (paths) | — | Builds the ClusterFuzzLite fuzzers on PRs that touch them; fuzzing itself runs in `fuzz.yml`. |
| `ci.yml` | push `main` + `v*.*.*` tags (paths), PR (paths), merge queue, schedule, dispatch | Mon 06:00 (weekly) | Lint / test on every PR; weekly schedule catches drift from external dependencies (apt mirrors, Homebrew bottles) even when no code lands. |
| `ci-enforced.yml` | push `main` + `v*.*.*` tags, PR, dispatch | — | Strict gates fire on every PR; no scheduled run (covered by ci.yml weekly). |
| `cockpit-test.yml` | push `main` (paths), PR (paths) | — | Go gates for the `dot ai` cockpit (`dot-ai-tui`), only when its source changes. |
| `codeql.yml` | push `main`, PR (paths), merge queue, schedule | Mon 06:00 (weekly) | Source-code SAST. Weekly schedule catches new CodeQL rule packs. |
| `compliance-guard.yml` | PR, merge queue, push `main` (paths) | — | Policy enforcement on every PR; no need to schedule. |
| `core-contracts.yml` | PR (paths), push `main`, dispatch | — | Core and delivery contracts on change. |
| `coverage.yml` | PR (paths), push `main`, dispatch | — | Coverage gate on change. |
| `cross-platform-test.yml` | PR, push `main` (paths), merge queue, schedule, dispatch | Sun 07:00 (weekly) | Validates BSD vs GNU tool divergence on every PR; weekly catches GitHub-hosted-runner image updates. |
| `dco.yml` | PR | — | Sign-off check on every PR commit. |
| `dependency-review.yml` | PR | — | Dependency diff review per PR. |
| `deps-dev-validation.yml` | PR (paths), push `main`, schedule, dispatch | Tue 04:00 (weekly) | deps.dev advisories appear without a code change, so direct dependencies are re-checked weekly; advisory on PRs. |
| `devcontainer-prebuild.yml` | push `main` (paths), PR (paths), schedule, dispatch | Mon 03:00 (weekly) | Pre-build the devcontainer image weekly so first `Open in Codespaces` is fast. |
| `doc-drift.yml` | push `main`, PR (paths), dispatch | — | Generated docs (command index, man page, completions, version stamps) on change. |
| `docs-link-check.yml` | push `main`, PR, schedule, dispatch | Mon 06:00 (weekly) | External links rot without a code change. |
| `dot-cli-bench.yml` | push `main` (paths), PR (paths) | — | CLI cold-start bench when the CLI changes. |
| `dot-ui-test.yml` | push `main` (paths), PR (paths) | — | Go tests for `dot-ui`, only when its code changes. |
| `drift-detection.yml` | schedule + dispatch | **Daily 04:00** | Source-vs-deployed drift on `main`; opens or updates a tracking issue. Daily because the check is cheap. |
| `fuzz.yml` | push `main`, PR (paths), dispatch | — | Native Go fuzz harnesses. |
| `govulncheck.yml` | PR (paths), push `main`, schedule, dispatch | Mon 06:17 (weekly) | Go vulnerability database changes without a code change. |
| `install-fuzz.yml` | schedule, dispatch, PR (paths) | Mon 03:00 (weekly) | `install.sh` argument fuzzing; weekly plus PRs that touch the installer. |
| `manual-publish.yml` | push `main` (paths), PR (paths), release published, dispatch | — | Builds the manual on change; attaches it to each published Release. |
| `mcp-server-test.yml` | push `main` (paths), PR (paths) | — | Go tests for the MCP server, only when its code changes. |
| `mutation-nightly.yml` | schedule + dispatch | **Daily 03:17** | Scores the core scripts' mutation coverage every night (the PR gate scores only changed lines), against a 90% floor. |
| `nightly.yml` | schedule + dispatch | **Sun 02:00 (weekly)** | Was daily; flipped to weekly under [#861](https://github.com/sebastienrousseau/dotfiles/issues/861). Jobs (dependency updates, test suite, extended OS matrix on macOS 13/14/15-intel/latest, beta tools, extended security, performance tracking) don't need daily cadence. |
| `npm-publish.yml` | release published, dispatch | — | Publishes the npm package for each Release. |
| `pages.yml` | push `main` (paths), dispatch | — | Deploys the docs site when its sources change. |
| `perf-baseline.yml` | schedule, push `feat/**` (paths), dispatch | Sun 03:00 (weekly) | Weekly run records the baseline; per-commit runs on feature branches catch startup regressions early. |
| `policy-bundle-release.yml` | dispatch | — | Manual only: packages a policy bundle at a given version. |
| `pr-signature.yml` | PR | — | Verifies PR description has the branding signature. |
| `pre-commit.yml` | PR, push `main`, merge queue | — | The pre-commit hooks, in CI. |
| `regression-trace-audit.yml` | schedule + dispatch | Mon 05:00 (weekly) | Checks every `# Regression for: GH-NNN` reference still resolves to a real issue; runs after Dependabot. |
| `release-attestation-check.yml` | schedule + dispatch | Mon 07:00 (weekly) | Checks the latest Release still carries its attestation bundle. |
| `release-distribute-aur.yml`, `-homebrew.yml`, `-scoop.yml` | release published, dispatch | — | Publish each Release to its channel. |
| `release-install-smoke.yml` | release published, dispatch | — | Clean install of each published Release. |
| `release-package-dot.yml` | release created, dispatch | — | Builds the release archives; never scheduled. |
| `reliability-gate.yml` | PR, push `main`, dispatch | — | Reliability audit on every PR; no scheduled cadence. |
| `reusable-*.yml` (×7) | `workflow_call` | — | Called by other workflows; not directly triggered. |
| `rust.yml` | push `main` (paths), PR (paths), dispatch | — | Rust `dot-sys` build and tests, only when that code changes. |
| `sbom-diff.yml` | PR | — | Generates SBOM diff per PR. |
| `scorecard.yml` | branch-protection change, schedule, push `main`, dispatch | Mon 06:00 (weekly) | OpenSSF Scorecard. |
| `security-enhanced.yml` | push `main` (paths), PR (paths), merge queue, schedule, dispatch | **Sun 02:00 (weekly)** | Was daily; reduced to weekly in earlier hardening. Per-PR runs cover the active-change case. |
| `security-release.yml` | release published, dispatch | — | SBOM, SLSA provenance and the signed manifest for each Release; never scheduled. |
| `sync-versions.yml` | push `main` + `feat/v*` (paths), PR (paths), dispatch | — | Verifies version references on `main` and PRs; syncs and commits them on `feat/v*`. |
| `theme-contracts.yml` | push `main`, PR, dispatch | — | Theme rendering contracts on every change. |
| `update-deps.yml` | schedule + dispatch | Mon 08:00 (weekly) | Dependabot is the primary path; this is a belt-and-suspenders weekly sweep. |
| `verify-gpg-wkd.yml` | push `main` (paths), PR (paths), schedule, dispatch | Mon 09:00 (weekly) | The in-repo disclosure key and its WKD copy can drift independently. |
| `verify-tag-signature.yml` | push of a `v*` tag | — | Rejects lightweight or unsigned release tags. |

## Why no daily jobs

This section records the 2026-05-12 review. `drift-detection.yml` and
`mutation-nightly.yml` were given daily schedules after it, each with
the reason in its table row above.

We reviewed every workflow with maintainer Sebastien Rousseau on
2026-05-12 and concluded:

1. **No external signal needs daily polling.** Dependency updates flow
   through Dependabot (push-driven, not poll-driven). Beta-tool
   detection in `nightly.yml` checks for major Chezmoi / ShellCheck
   updates — these ship every few months, not days. CVE scans run on
   every PR (`sbom-diff.yml`) plus a weekly aggregate
   (`security-enhanced.yml`).

2. **No downstream consumer reads daily artifacts.** No external
   dashboard, no published feed, no alert ingester depends on a daily
   nightly artifact. The artifacts are inspected ad-hoc.

3. **Daily cadence was vestigial.** `nightly.yml` had cron `0 2 * * *`
   from an earlier era when the workflow ran the full test matrix; the
   matrix has since moved into `ci-enforced.yml` (event-driven), but
   the cron was never updated. Confirmed via `git log` of the file.

If any of these conditions changes (e.g., we add a publishing pipeline
that needs daily artifacts), the appropriate path is a new `daily-checks.yml`
workflow with explicit cadence rationale documented here — *not* flipping
an existing weekly back to daily.

## Cost impact of the daily → weekly flip

Before (daily nightly):

- 7 runs/week × ~40 min total CI minutes per run = **~280 min/week**
- ~14,560 minutes/year (~243 hours of CI compute)

After (weekly nightly):

- 1 run/week × ~40 min = **~40 min/week**
- ~2,080 minutes/year (~35 hours)

**Net saving: ~208 hours of CI compute per year (~85% reduction)** on
the nightly workflow alone. GitHub-hosted minutes are billed per
runner-minute; saving aligns with the project's "zero-debt, no waste"
mandate.

## Reviewing this page

When adding a new workflow:

1. Pick a bucket from the rules at the top of this page.
2. Add the row to the table — include the **why**, not just the cron
   expression. Future maintainers should be able to decide whether a
   cadence is still load-bearing.
3. If proposing a daily cadence, justify why a weekly version doesn't
   meet the need in the workflow's PR description.

## References

- [`nightly.yml`](https://github.com/sebastienrousseau/dotfiles/blob/main/.github/workflows/nightly.yml) — the workflow whose cadence flip triggered this page.
- [`security-enhanced.yml`](https://github.com/sebastienrousseau/dotfiles/blob/main/.github/workflows/security-enhanced.yml) — earlier daily→weekly reduction.
- Issue [#861](https://github.com/sebastienrousseau/dotfiles/issues/861).
