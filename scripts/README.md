# `scripts/` — Framework Code

Everything in this directory is **framework code**. Nothing here
deploys to `~/`; chezmoi ignores the whole tree (see
`.chezmoiignore`). Scripts are invoked by the `dot` CLI, by CI
workflows, by `chezmoi apply` hooks, or by hand.

## Subtree map

| Path | Purpose | Touched by |
|---|---|---|
| `scripts/dot/` | The `dot` CLI implementation. See breakdown below. | Sourced by `dot_local/bin/executable_dot` |
| `scripts/lib/` | Cross-cutting library helpers reused across multiple scripts. Example: `secrets_provider.sh` (keychain / pass / age dispatch). | `scripts/dot/commands/*`, ops scripts, CI |
| `scripts/ci/` | CI-only helpers: `dot-cli-startup-bench.sh`, `install-chezmoi-verified.sh`, `windows-smoke-test.ps1`, `run-coverage.sh`, etc. | `.github/workflows/*` |
| `scripts/diagnostics/` | `doctor.sh` and its helpers — long-form environment health check. | `dot doctor` |
| `scripts/security/` | Security-domain ops: `check-disclosure-key-expiry.sh`, `lock-configs.sh`, etc. | `dot security`, CI |
| `scripts/secrets/` | Secret-bucket utilities (rotation, audit). | `dot secrets` subcommands |
| `scripts/theme/` | Wallpaper-to-palette extraction logic. | `dot theme rebuild` |
| `scripts/tools/` | Tool-management ops: `log-rotate.sh`, etc. | `dot tools`, `dot env` |
| `scripts/tuning/` | Opt-in OS tuning scripts (`macos.sh`, `linux.sh`). | `dot tune`, manual invocation |
| `scripts/ops/` | Repo-wide ops: `rollback.sh`, etc. | `dot rollback`, maintenance |
| `scripts/maintenance/` | Recurring upkeep: `check-updates.sh`, etc. | Cron, manual |
| `scripts/release/` | Release-time tasks. | Release workflow |
| `scripts/docs/` | Documentation-generation helpers (manual builds, screenshot CI). | `manual-publish.yml`, `dot manual` |
| `scripts/fonts/` | Nerd Font install helpers. | `dot fonts` |
| `scripts/git-hooks/` | Git hooks not managed by chezmoi (kept here for portable install). | `install/provision/*` |
| `scripts/qa/` | Quality-assurance helpers: PowerShell contract tests, etc. | `.github/workflows/pr-signature.yml`, `powershell-contract.yml` |
| `scripts/demo/` | Demonstration helpers (recordings, screenshots). | Manual |

## `scripts/dot/` breakdown

The `dot` CLI is implemented as `dot_local/bin/executable_dot`
(dispatcher) + `scripts/dot/commands/<cmd>.sh` (per-command
handlers) + `scripts/dot/lib/*.sh` (shared helpers).

| Path | Purpose |
|---|---|
| `scripts/dot/commands/` | One file per `dot <cmd>` subcommand. Each defines a `cmd_<name>()` function the dispatcher calls. |
| `scripts/dot/lib/utils.sh` | Common helpers (resolve_source_dir, validate_name, die, run_script, etc.). |
| `scripts/dot/lib/ui.sh` | Single source of truth for CLI output (ui_ok/warn/err/info, ui_header, ui_table_*, ui_spinner_*, ui_confirm, ...). |
| `scripts/dot/lib/platform.sh` | OS / shell / WSL detection, path translation. |
| `scripts/dot/lib/log.sh` | Structured logging (JSONL audit log when `DOTFILES_AUDIT_LOG=1`). |
| `scripts/dot/lib/bento.sh` | The "bento box" layout primitive used by `dot health` and friends. |

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

2. Add a dispatch arm in `dot_local/bin/executable_dot`:

   ```bash
   <name>) load_commands "<name>"; cmd_<name> "$@" ;;
   ```

3. Document it in `docs/manual/03-reference/01-dot-cli.md` and add
   to `docs/manual/command-index.md`.

4. Add a help-table entry in `dot_local/bin/executable_dot`'s
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

- `STRUCTURE.md` (root) — full repository map.
- `docs/manual/03-reference/01-dot-cli.md` — every `dot <cmd>` documented.
- `scripts/dot/lib/ui.sh` — the UI primitive library (always source this for output).
