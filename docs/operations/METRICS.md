---
render_with_liquid: false
---

# Observability & Metrics

The repo emits a handful of signal streams for operators — humans
running `dot doctor` on a workstation, and CI jobs running against
every push. This document consolidates *what* is measured, *where*
it lands, and *how to consume* it.

## Signals at a glance

| Signal | Source | Consumer | Persistence |
|---|---|---|---|
| **Drift** (4 classes) | `dot drift` / `scripts/diagnostics/drift-dashboard.sh` | Human CLI, nightly workflow | `${XDG_STATE_HOME}/dotfiles/drift.log` + workflow artifact |
| **Health** | `dot doctor` | Human CLI, CI reliability-gate | Exit code + stderr summary |
| **Shell surface** | `scripts/qa/shell-surface-audit.sh` | CI reliability-gate (ratchet), maintainers | Stdout JSON on `--json` |
| **Performance** | `.github/workflows/perf-baseline.yml` | Maintainers, PR reviewers | Comment on PR + `nightly-reports/` |
| **Reliability** | `.github/workflows/reliability-gate.yml` | Blocks merge to master | GitHub check status |
| **Coverage** | `.github/workflows/coverage.yml` | Codecov badge, PR reviewers | codecov.io + `dist/coverage-*` |
| **Doc drift** | `.github/workflows/doc-drift.yml` | Maintainers | GitHub issue on drift |
| **SBOM diff** | `.github/workflows/sbom-diff.yml` | Release approver | SBOM artefact + PR comment |
| **Security scorecard** | `.github/workflows/scorecard.yml` + `security-enhanced.yml` | OpenSSF badge, maintainers | scorecard.dev + README badge |
| **Nightly report** | `.github/workflows/nightly.yml` | Maintainers | `nightly-reports/updates.txt` |

## Drift — the primary user-facing signal

Documented in detail in [`DRIFT.md`](DRIFT.md). Four classes tracked:
managed drift, untracked source, orphan deployed, stale source.

- Local, ad-hoc: `dot drift` (human), `dot drift --json` (script),
  `dot drift --diff` (also shows `chezmoi diff` for managed drift).
- Nightly: `.github/workflows/drift-detection.yml` emails/notifies
  on any non-zero class.

**When to run it**: after any `chezmoi apply`, before opening a PR
that touches `defaults/`, and as part of routine "am I in sync?"
checks.

## Health — the "should I intervene?" signal

`dot doctor` runs 20+ built-in checks: PATH sanity, shell startup
files, mise/asdf state, git config integrity, chezmoi source
resolvability, symlink validity, permissions on secret files, …

- Exit 0 = all green (may include informational warnings).
- Exit 1 = critical error — human action required.

Called automatically from `install.sh` post-apply and from the
`reliability-gate` workflow.

## Shell surface — the ratchet

`scripts/qa/shell-surface-audit.sh` counts `*.sh` files by tier and
emits duplication signals. The
[`SHELL_SURFACE.md`](SHELL_SURFACE.md) policy defines the ratchet:
total count can only decrease unless raised by an RFC.

- Human: `bash scripts/qa/shell-surface-audit.sh` (report) or `--json`
- CI: `bash scripts/qa/shell-surface-audit.sh --max-total <ceiling>`
  in `reliability-gate.yml` (fails the build on growth).

Current ceiling: `1000`. Reduced by every consolidation commit.

## Performance — sub-100ms cold-start invariant

The repo's headline claim (sub-100ms CLI cold start) is enforced
by `perf-baseline.yml` which runs `bin/dot-load-benchmark-pty`
against a fresh shell and compares to a stored baseline.

- Baseline: `nightly-reports/perf-baseline.json`
- Regression threshold: 20 % over baseline blocks the PR
- Consumed by: PR reviewers via inline PR comment

## Reliability gate — the merge blocker

`reliability-gate.yml` bundles the tests that MUST pass before
merge to master:

- `reliability-audit.sh --with-integration`
- `shell-surface-audit.sh --max-total 1000`
- `validate-examples.sh`
- `wsl-contract.sh`
- `powershell-contract.ps1`

Reliability-summary job aggregates the results into a single
status check.

## Coverage — trend, not target

Line coverage is tracked via `coverage.yml` → Codecov. It's a
trend metric, not a hard gate; the reliability-gate is what
blocks merges. Coverage regression is surfaced on PR review
without failing the check.

Target: 80 % for `lib/dot/` and `scripts/dot/commands/` by 1.0
(see [`RELEASE_1_0.md`](RELEASE_1_0.md)).

## Consuming the signals from external tooling

All the human-consumable signals also emit JSON for pipelining:

- `dot drift --json`
- `dot doctor --json` (planned; currently text-only)
- `bash scripts/qa/shell-surface-audit.sh --json`

Nightly-report ingestion example:

```bash
jq --slurp '[.[] | {when: .time, drift: .drift_total, health: .health_ok}]' \
    ${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/nightly-*.json
```

## Related runbooks

- [`DRIFT.md`](DRIFT.md) — 4-class drift model, detection + remediation
- [`SHELL_SURFACE.md`](SHELL_SURFACE.md) — ratchet policy for shell files
- [`RELIABILITY.md`](RELIABILITY.md) — how reliability-gate composes
- [`PERFORMANCE.md`](PERFORMANCE.md) — the sub-100ms budget
- [`COVERAGE.md`](COVERAGE.md) — coverage generation + gating
- [`MAINTENANCE.md`](MAINTENANCE.md) — recovery + release runbooks
