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
| **Event** | `push`, `pull_request`, `merge_group` | Code-change gates — must run on every PR. |
| **Weekly** | `schedule:` Monday or Sunday | Drift detection, beta-tool watch, extended platform matrices. |
| **Monthly** | (none currently) | Long-running audits, historical scans. |
| **Manual** | `workflow_dispatch` only | Releases, ad-hoc tooling. |

**Anti-rule:** no workflow runs on `cron: '* * * *'` (daily) unless its
output is consumed daily by something downstream. Nothing today meets
that bar; see "Why no daily jobs" below.

## Workflow cadence table

| Workflow | Triggers | Schedule (UTC) | Why this cadence |
|---|---|---|---|
| `ci.yml` | event + schedule | Mon 06:00 (weekly) | Lint / test on every PR; weekly schedule catches drift from external dependencies (apt mirrors, Homebrew bottles) even when no code lands. |
| `ci-enforced.yml` | event | — | Strict gates fire on every PR; no scheduled run (covered by ci.yml weekly). |
| `codeql.yml` | event + schedule | Mon 06:00 (weekly) | Source-code SAST. Weekly schedule catches new CodeQL rule packs. |
| `compliance-guard.yml` | event | — | Policy enforcement on every PR; no need to schedule. |
| `cross-platform-test.yml` | event + schedule | Sun 07:00 (weekly) | Validates BSD vs GNU tool divergence on every PR; weekly catches GitHub-hosted-runner image updates. |
| `devcontainer-prebuild.yml` | event + schedule | Mon 03:00 (weekly) | Pre-build the devcontainer image weekly so first `Open in Codespaces` is fast. |
| `manual-publish.yml` | manual only | — | Release-trigger flow; never scheduled. |
| `nightly.yml` | schedule + manual | **Sun 02:00 (weekly)** | Was daily; flipped to weekly under [#861](https://github.com/sebastienrousseau/dotfiles/issues/861). Jobs (beta-tool detection, extended OS matrix on macos-15-intel/macos-14, dependency-report) don't need daily cadence. |
| `npm-publish.yml` | release tag | — | Trigger: `push` of a version tag. |
| `policy-bundle-release.yml` | manual + release | — | Manual / release-trigger only. |
| `pr-signature.yml` | pull_request | — | Verifies PR description has the branding signature. |
| `reliability-gate.yml` | event | — | Reliability audit on every PR; no scheduled cadence. |
| `reusable-*.yml` (×7) | callable | — | Called by other workflows; not directly triggered. |
| `sbom-diff.yml` | pull_request | — | Generates SBOM diff per PR. |
| `security-enhanced.yml` | event + schedule | **Sun 02:00 (weekly)** | Was daily; reduced to weekly in earlier hardening. Per-PR runs cover the active-change case. |
| `security-release.yml` | release tag | — | SLSA provenance on release; never scheduled. |
| `sync-versions.yml` | manual | — | Version-bump tooling. |
| `update-deps.yml` | schedule | Mon 08:00 (weekly) | Dependabot is the primary path; this is a belt-and-suspenders weekly sweep. |

## Why no daily jobs

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

- [`nightly.yml`](https://github.com/sebastienrousseau/dotfiles/blob/master/.github/workflows/nightly.yml) — the workflow whose cadence flip triggered this page.
- [`security-enhanced.yml`](https://github.com/sebastienrousseau/dotfiles/blob/master/.github/workflows/security-enhanced.yml) — earlier daily→weekly reduction.
- Issue [#861](https://github.com/sebastienrousseau/dotfiles/issues/861).
