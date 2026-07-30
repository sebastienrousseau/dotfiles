---
render_with_liquid: false
---

# ADR-012 — `dot` CLI Three-Tier Architecture

- **Status**: Accepted
- **Date**: 2026-07-30
- **Deciders**: primary maintainer
- **Related**: [ADR-004 CLI Architecture](ADR-004-cli-architecture.md), [`docs/architecture/REPO_LAYOUT.md`](../architecture/REPO_LAYOUT.md)

## Context

The `dot` CLI grew organically from a single `bin/dot` script into
its current form: 19 subcommands, 5 shared library modules, and a
family of ancillary entry points (`dot-bootstrap`, `dot-theme-sync`,
`dot.ps1`). Two forces shaped the current layout:

1. **Packaging pressure**: Homebrew / Scoop / AUR each ship the
   entry point as a distributable artefact. The entry point needs
   to be small and self-contained; pulling in the whole tree
   inflates the package.
2. **Reuse pressure**: subcommand implementations kept
   re-implementing logging, TTY detection, and platform sniffing.
   Extracting these into shared libraries deduped ~15 places by the
   time this ADR was written.

Without codifying the layout, both forces were pulling code back
into a monolithic `bin/dot` that would defeat both goals.

## Decision

Adopt a three-tier architecture with explicit responsibilities:

```
bin/dot                (entry point)
   │
   ▼
scripts/dot/commands/  (subcommand implementations)
   │
   ▼
lib/dot/               (shared libraries)
```

### Tier 1 — `bin/dot`

- Owns argv parsing, subcommand dispatch, PATH-side entry.
- Small on purpose so distribution packages don't pull in the tree.
- Never contains subcommand logic — only routing.

### Tier 2 — `scripts/dot/commands/<name>.sh`

- One file per subcommand.
- Each file exposes a `main()` function.
- Sources what it needs from tier 3.
- Never sources another tier-2 file directly — cross-cutting
  helpers belong in tier 3.

### Tier 3 — `lib/dot/*.sh`

- Reusable primitives: `log.sh`, `ui.sh`, `platform.sh`, `bento.sh`,
  `utils.sh`.
- Each file has a re-source guard (`_DOT_LIB_*_LOADED`) so sourcing
  is idempotent.
- Commands sourced at tier 2 must not have side effects at
  source-time — only function definitions and constant
  assignments.

### Cross-tier rules

- **Tier 3 → Tier 3**: allowed and expected (e.g. `utils.sh` sources
  `ui.sh` + `platform.sh`).
- **Tier 2 → Tier 2**: forbidden.
- **Tier 2 → Tier 3**: normal usage.
- **Tier 1 → Tier 3**: allowed at bootstrap time only.
- **Tier 1 → Tier 2**: via dispatch, not direct sourcing.

### Ancillary entry points

`bin/dot-bootstrap`, `bin/dot-theme-sync`, `bin/dot.ps1` etc. are
tier-1 peers of `bin/dot` — each is a self-contained entry that may
source tier-3 libraries but does not go through the `dot` dispatch.

## Consequences

**Positive:**

- New subcommand? Add a file in `scripts/dot/commands/` and a
  dispatch case in `bin/dot`. Two-file change with a well-known
  shape. New contributors can copy an existing command.
- Duplication signals become actionable — if two commands need the
  same helper, promote it to tier 3.
- The
  [`scripts/qa/shell-surface-audit.sh`](../../scripts/qa/shell-surface-audit.sh)
  ratchet enforces the boundary: `dot_command` and `lib`
  categories grow (or shrink) intentionally, while `one_off`
  requires an RFC to grow.
- Distribution packages ship a small tier-1 artefact +
  targeted tier-3 files, not the whole tree.

**Negative:**

- Adds a mental hop for readers: "which tier owns this helper?"
  Mitigated by
  [`docs/architecture/REPO_LAYOUT.md`](../architecture/REPO_LAYOUT.md)'s
  "where to add things" table.
- Sourcing chains can get deep. Mitigated by the re-source guards
  in every tier-3 module.

**Neutral:**

- Enforcement is convention-based (via CI + auditor) rather than
  language-level. That's acceptable for a shell codebase; a
  compiled language would use module boundaries instead.

## Alternatives considered

1. **Single-file `bin/dot`** (the pre-tiering shape). Rejected —
   inflated distribution packages, no dedup surface, hard to test
   subcommands in isolation.

2. **Flat command layout with helpers inline in each file**.
   Rejected — the mise-aware `check_cmd()` had drifted to four
   different implementations by the time it was consolidated
   ([`refactor(lib)`](../../lib/dot/utils.sh)). Predictable outcome
   at scale.

3. **A single `lib/dot.sh` monolith instead of a `lib/dot/`
   directory**. Rejected — sourcing an 800-line file for a helper
   that touches 20 lines is wasteful, and per-module re-source
   guards work more cleanly when each module is its own file.

4. **Compile everything to a single stapled shell script at
   packaging time**. Considered — has some appeal for
   distribution size — but the shell tooling for this is fragile
   (`shpp`, `bashly`) and doesn't preserve line numbers for
   debuggability. Revisit if distribution size becomes an issue.

## Enforcement

- `scripts/qa/shell-surface-audit.sh` classifies files by tier and
  emits duplication signals when tier-2 files reinvent tier-3
  helpers.
- `.github/workflows/reliability-gate.yml` runs the auditor with
  `--max-total 1000` so the total tier count can only decrease
  without an RFC.
- New subcommand PRs should tick the "argv contract + tier-3
  dependencies" box in the PR template.
