---
render_with_liquid: false
---

# Shell Surface Policy

The repo carries close to a thousand shell scripts today, split
across libraries, `dot` subcommand implementations, tests, ops
tooling, installers, and one-off diagnostics. That's a real
maintenance cost: every duplicate helper, every reinvented logger,
every ad-hoc arg parser is a place where an incorrect assumption
can rot silently.

This document defines how we keep the surface honest.

## Measurement

The canonical measurement tool is
[`scripts/qa/shell-surface-audit.sh`](../../scripts/qa/shell-surface-audit.sh).

```bash
# Human report
bash scripts/qa/shell-surface-audit.sh

# JSON for pipelines
bash scripts/qa/shell-surface-audit.sh --json

# Fail if total exceeds a threshold (used in CI)
bash scripts/qa/shell-surface-audit.sh --max-total 1000
```

The auditor classifies every `*.sh` file into one of the following
buckets and emits duplication signals:

| Bucket | Purpose | Grow it? |
|---|---|---|
| `lib` (`lib/dot/`) | Shared libraries sourced by ≥2 callers | **Yes** — this is where duplication should land |
| `dot_command` (`scripts/dot/commands/`) | One file per `dot` subcommand | Only with a new subcommand |
| `entrypoint` (`bin/`) | User-facing CLIs on `$PATH` | Only for new top-level binaries |
| `test` (`tests/`) | Unit / integration / regression / fuzz / perf tests | **Yes** — more coverage is always OK |
| `install` (`install/`) | Bootstrap installer + packaging | Only with packaging changes |
| `scripts_ci`, `scripts_ops`, `scripts_qa`, `scripts_security`, `scripts_diagnostics`, `scripts_tools`, `scripts_lib` | Domain-scoped tooling | Slowly — prefer a `lib/` helper over a new script |
| `one_off` | Everything else | **No** — every new one-off requires an RFC |

## Ratchet

Total shell-file count is a ratchet: it can only go **down** (or stay
flat) unless the change comes with an RFC in
[`docs/operations/`](.) that lists the new files and justifies why
they don't fit an existing bucket.

Enforcement:

- The CI job `.github/workflows/reliability-gate.yml` runs
  `shell-surface-audit.sh --max-total ${CEILING}` where `${CEILING}`
  is the current committed value in
  [`.chezmoidata.toml`](../../defaults/.chezmoidata.toml) under
  `[maintenance] shell_surface_ceiling`.
- When you *remove* scripts (e.g. by consolidating three helpers into
  one `lib/dot/x.sh`), lower the ceiling in the same commit.
- When you *cannot* avoid adding scripts (new subcommand, new install
  target), raise the ceiling by exactly the number of new files
  added — and reference the RFC that justifies each one.

## Duplication signals

The auditor emits two duplication signals worth acting on:

1. **Duplicate basenames across roles.** If `backup.sh` exists in
   both `scripts/ops/` and `install/`, they likely share logic.
   Promote the shared parts to `lib/dot/backup.sh` and have both
   callers source it.

2. **Function names defined in ≥2 files.** E.g. `check_cmd` defined
   in 4 files means we have four subtly-different implementations of
   "does this command exist on the PATH?" — a classic bug farm.
   Extract to `lib/dot/utils.sh::check_cmd` and delete the copies.

The audit is intentionally noisy so drift shows up early. Treat it
like a linter: not every hit needs action *today*, but the trend
line is what we watch.

## Consolidation roadmap

The current backlog of high-value consolidation targets is tracked
in [`docs/operations/ROADMAP.md`](ROADMAP.md) under "Shell surface
reduction". Pick items off the top; each ships as its own PR with a
before/after auditor delta in the description.

## Related

- [`docs/architecture/REPO_LAYOUT.md`](../architecture/REPO_LAYOUT.md) —
  where new files should go.
- [`docs/operations/MAINTENANCE.md`](MAINTENANCE.md) — broader
  maintenance runbook.
- [`CLAUDE.md`](../../CLAUDE.md) — style rules for shell (2-space
  indent, `set -euo pipefail`, shellcheck-clean, `shfmt -i 2 -ci`).
