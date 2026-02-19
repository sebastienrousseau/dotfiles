# Milestone v0.2.487 Scope

This milestone keeps scope intentionally small and operationally focused.

## Goals

- Make post-merge verification a first-class workflow (`dot verify`).
- Keep protected-branch CI deterministic (no unsigned bot commits on `master`).
- Improve day-2 operator confidence with explicit verification guidance.

## In Scope

- [x] Add `dot verify` command routing in diagnostics module.
  - `scripts/dot/commands/diagnostics.sh`
  - `dot_local/bin/executable_dot`
- [x] Add verification runner script.
  - `scripts/diagnostics/verify.sh`
  - Runs:
    - `dot doctor`
    - `dot status`
    - `chezmoi diff`
- [x] Update completion surfaces for new command.
  - `dot_local/share/bash-completion/completions/dot`
  - `dot_local/bin/executable_dot_completion`
- [x] Harden sync-versions behavior for protected `master`.
  - `.github/workflows/sync-versions.yml`
  - `master` now verifies only; auto-sync commit job runs on non-master branches.
- [x] Update docs and command references.
  - `README.md`
  - `docs/README.md`
  - `docs/OPERATIONS.md`

## Out of Scope

- New security controls beyond existing baseline.
- Major CLI redesign or command namespace reshuffle.
- Release process automation changes outside sync-versions policy hardening.

## Exit Criteria

- `dot verify` returns non-zero on drift/issues and zero when healthy.
- `sync-versions` workflow no longer attempts commits to protected `master`.
- Relevant unit tests and targeted command tests pass.
