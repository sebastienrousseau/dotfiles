# `scripts/` — Framework Code

Everything in this directory is **framework code**. Nothing here
deploys to `~/`; chezmoi ignores the whole tree (see
`.chezmoiignore`). Scripts are invoked by the `dot` CLI, by CI
workflows, by `chezmoi apply` hooks, or by hand.

## Subtree map

Per the repository reorg (RFC `docs/operations/RFC_v0_2_503_reorganization.md`),
**repo-only ops** (CI, release, maintenance, docs-generation) have
moved to the top-level `tools/` tree. `scripts/` retains the
**runtime-invoked** scripts that the `dot` CLI dispatches to plus a
few specialised subtrees.

### `scripts/` (CLI dispatch + specialised subtrees)

| Path | Purpose | Touched by |
|---|---|---|
| `scripts/dot/commands/` | Per-subcommand handlers for the `dot` CLI. Sources `lib/dot/*.sh` (moved out of this tree in the Phase 1 reorg). | Dispatched by `bin/dot` |
| `scripts/dot/powershell/` | Native PowerShell module (`Dot.psm1`) exporting `Get-DotVersion` / `Invoke-DotHelp` / `Test-DotAgentsSync`. | `bin/dot.ps1` |
| `scripts/dot/data/` | Per-command static data (registry seeds, palette tables). | `scripts/dot/commands/*` |
| `scripts/lib/` | Cross-cutting library helpers reused across multiple scripts. Example: `secrets_provider.sh` (keychain / pass / age dispatch). | `scripts/dot/commands/*`, ops scripts |
| `scripts/diagnostics/` | `doctor.sh` and its helpers — long-form environment health check. | `dot doctor` |
| `scripts/security/` | Security-domain ops: `check-disclosure-key-expiry.sh`, `lock-configs.sh`, etc. | `dot security`, CI |
| `scripts/secrets/` | Secret-bucket utilities (rotation, audit). | `dot secrets` subcommands |
| `scripts/theme/` | Wallpaper-to-palette extraction logic. | `dot theme rebuild` |
| `scripts/tools/` | Tool-helpers shipped via `dot tools` (e.g. `cmatrix.sh`, `emoji-picker.sh`, `figlet-banner.sh`, `log-rotate.sh`). Runtime-invoked. | `dot tools`, `dot env` |
| `scripts/tuning/` | Opt-in OS tuning scripts (`macos.sh`, `linux.sh`). | `dot tune`, manual invocation |
| `scripts/ops/` | Repo-wide ops: `rollback.sh`, etc. | `dot rollback`, maintenance |
| `scripts/fonts/` | Nerd Font install helpers. | `dot fonts` |
| `scripts/git-hooks/` | Git hooks not managed by chezmoi (kept here for portable install). | `install/provision/*` |
| `scripts/qa/` | Quality-assurance helpers (PowerShell contract tests, version-consistency checks, scorecard snapshot, etc). | `.github/workflows/pr-signature.yml`, `powershell-contract.yml`, doc-drift |
| `scripts/demo/` | Demonstration helpers (recordings, screenshots). | Manual |
| `scripts/version-sync.sh` | Bulk version-string propagator (`scripts/qa/check-version-consistency.sh` is the verifier). | Release flow |
| `scripts/uninstall.sh` | Reverse-of-`install.sh` — user-invoked. | Manual |

### `tools/` (repo-only ops, not distributable)

| Path | Purpose | Touched by |
|---|---|---|
| `tools/ci/` | CI-only helpers: `dot-cli-startup-bench.sh`, `install-chezmoi-verified.sh`, `windows-smoke-test.ps1`, `run-coverage.sh`, etc. | `.github/workflows/*` |
| `tools/release/` | Release-time tasks. | Release workflow |
| `tools/maintenance/` | Recurring upkeep: `check-updates.sh`, etc. | Cron, manual |
| `tools/docs/` | Documentation-generation helpers (manual builds, screenshot CI, `generate-command-index.sh`). | `manual-publish.yml`, `dot manual`, doc-drift |

## `scripts/dot/` breakdown

The `dot` CLI is implemented as `bin/dot`
(dispatcher) + `scripts/dot/commands/<cmd>.sh` (per-command
handlers) + `lib/dot/*.sh` (shared helpers — moved out of
`scripts/dot/lib/` in the Phase 1 reorg per the
[reorganisation RFC](../docs/operations/RFC_v0_2_503_reorganization.md)).

| Path | Purpose |
|---|---|
| `scripts/dot/commands/` | One file per `dot <cmd>` subcommand. Each defines a `cmd_<name>()` function the dispatcher calls. Sources the library via `$SCRIPT_DIR/../../../lib/dot/<X>.sh`. |
| `scripts/dot/powershell/` | Native PowerShell module — see top-level table. |
| **`lib/dot/utils.sh`** | Common helpers (resolve_source_dir, validate_name, die, run_script, etc.). |
| **`lib/dot/ui.sh`** | Single source of truth for CLI output (ui_ok/warn/err/info, ui_header, ui_table_*, ui_spinner_*, ui_confirm, ...). |
| **`lib/dot/platform.sh`** | OS / shell / WSL detection, path translation. |
| **`lib/dot/log.sh`** | Structured logging (JSONL audit log when `DOTFILES_AUDIT_LOG=1`). |
| **`lib/dot/bento.sh`** | The "bento box" layout primitive used by `dot health` and friends. |

## Adding a new subcommand

1. Create `scripts/dot/commands/<name>.sh`:

   ```bash
   #!/usr/bin/env bash
   # Copyright (c) 2015-2026 Dotfiles. All rights reserved.
   set -euo pipefail
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   # shellcheck source=../lib/utils.sh
   source "$SCRIPT_DIR/../lib/utils.sh"

   dot_ui_command_banner "<Title>" "${1:-}"

   cmd_<name>() {
     # ...
   }

   cmd_<name>_help() {
     cat <<-EOF
     Usage: dot <name> [args]
     # ...
   EOF
   }
   ```

2. Add a dispatch arm in `bin/dot`:

   ```bash
   <name>) load_commands "<name>"; cmd_<name> "$@" ;;
   ```

3. Document it in `docs/manual/03-reference/01-dot-cli.md` and add
   to `docs/manual/command-index.md`.

4. Add a help-table entry in `bin/dot`'s
   help renderer.

5. Add a unit test under `tests/unit/<domain>/test_<name>.sh`
   (run with `./tests/framework/test_runner.sh`).

## Conventions

- **Shell style**: 2-space indent, `set -euo pipefail`, shellcheck-clean
  with the project's flags (`--severity=error -e SC1091 -e SC2030 -e SC2031`).
- **Formatting**: `shfmt -i 2 -ci`.
- **Output**: NEVER `printf` raw ANSI. Source `scripts/dot/lib/ui.sh`
  and use `ui_ok`, `ui_table_*`, etc.
- **Exit codes**: 1 = bad usage, 2 = no provider / dependency missing,
  3 = empty result / not found, ≥4 = provider-specific. Document
  per-command in the help text.
- **Validation**: Always `validate_name "$arg" "tool name"` before
  passing user input to `mise`, `gh`, `ssh`, etc.

## See also

- `../docs/STRUCTURE.md` — full repository map.
- `docs/manual/03-reference/01-dot-cli.md` — every `dot <cmd>` documented.
- `scripts/dot/lib/ui.sh` — the UI primitive library (always source this for output).
