# `tools/` — Repo-Only Operations

Everything in this directory is **internal to the repo** — CI helpers,
release tooling, documentation generators, maintenance jobs. Nothing
here ships to end users; the `dot` CLI doesn't dispatch to anything
under `tools/`.

Per the v0.2.503 reorg (`docs/operations/RFC_v0_2_503_reorganization.md`
Phase 5), this directory holds what used to live under
`scripts/{ci,release,maintenance,docs}/`. The split clarifies which
scripts a downstream distro packager needs to ship (`bin/`, `lib/`,
`plugins/`, `scripts/` and the rest `tools/release/stage-dot.sh`
stages) versus which only run in this repo's own CI
(`tools/`).

## Subtree map

| Path | Purpose | Touched by |
|---|---|---|
| `tools/ci/` | CI-only helpers. `dot-cli-startup-bench.sh`, `install-chezmoi-verified.sh`, `windows-smoke-test.ps1`, `run-coverage.sh`, etc. | `.github/workflows/*` |
| `tools/release/` | Release-time tasks. | Release workflow + `gh release create` flow |
| `tools/maintenance/` | Recurring upkeep: `check-updates.sh`, etc. | Cron, manual |
| `tools/docs/` | Documentation-generation helpers: `generate-command-index.sh`, manual and site builds, and the generators for man pages, completions and cmdlets (`gen_manpages.py`, `gen_completions.py`, `gen_cmdlets.py`). | `manual-publish.yml`, `dot help --manual`, doc-drift |

## Why this directory exists

The R4 audit (`docs/operations/HARD_AUDIT_2026.md` §8.3 P4) flagged
the framework / repo-ops intermingling under `scripts/` as a
contributor-onboarding cost. New contributors couldn't tell:

> "Is `scripts/ci/install-chezmoi-verified.sh` part of the CLI, or
> is it just a CI helper?"

Splitting them physically answers the question without anyone
having to grep. `scripts/` is now the runtime-invoked surface (apart
from the `scripts/ci/` compat shims kept for pinned reusable
workflows); `tools/` is exclusively repo-internal.

## Conventions

Same as `scripts/`:

- Shell style: 2-space indent, `set -euo pipefail`, shellcheck-clean.
- Format with `shfmt -i 2 -ci`.
- Source `lib/dot/ui.sh` for output (no raw `printf`).

## See also

- `../docs/STRUCTURE.md` — top-level repo map.
- `scripts/README.md` — the runtime-invoked sister tree.
- `docs/operations/RFC_v0_2_503_reorganization.md` — Phase 5 spec.
