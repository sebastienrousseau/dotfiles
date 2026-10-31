# `scripts/` — Framework Code

Everything in this directory is **framework code**. Nothing here
deploys to `~/`: `.chezmoiroot` is `defaults`, so chezmoi never reads
`scripts/`. Scripts are invoked by the `dot` CLI, by CI
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
| `scripts/dot/commands/` | The last legacy route handlers: `diagnostics.sh`, `manual.sh`, `meta.sh`. Every other domain lives in `plugins/<domain>/`. Sources `lib/dot/*.sh`. | Dispatched by `bin/dot` and plugins |
| `scripts/dot/powershell/` | Native PowerShell module (`Dot.psm1`), exporting ten functions (`Get-DotVersion`, `Invoke-DotHelp`, `Test-DotAgentsSync`, `Invoke-DotChezmoi`, `Get-DotStatus`, `Get-DotSourcePath`, `Invoke-DotDoctor`, `Get-DotEnvironment`, `Get-DotAgents`, `Get-DotFleetStatus`). | `bin/dot.ps1` |
| `scripts/dot/data/` | `alias-deprecations.tsv`. | `scripts/dot/commands/*` |
| `scripts/diagnostics/` | `doctor.sh` and its helpers — long-form environment health check. | `dot doctor` |
| `scripts/security/` | Security-domain ops: `check-disclosure-key-expiry.sh`, `lock-configs.sh`, etc. | `dot security`, CI |
| `scripts/secrets/` | Secret-bucket utilities (rotation, audit). | `dot secret` subcommands |
| `scripts/theme/` | Wallpaper-to-palette extraction plus deterministic contrast, xterm-256, and color-vision auditing. | `dot theme rebuild`, `make audit-palettes` |
| `scripts/tools/` | Tool-helpers shipped via `dot tool` (e.g. `cmatrix.sh`, `emoji-picker.sh`, `figlet-banner.sh`, `log-rotate.sh`). Runtime-invoked. | `dot tool`, `dot tool` |
| `scripts/tuning/` | Opt-in OS tuning scripts (`macos.sh`, `linux.sh`). | `dot system settings apply`, manual invocation |
| `scripts/ops/` | Repo-wide ops: `rollback.sh`, etc. | `dot doctor rollback`, maintenance |
| `scripts/fonts/` | Nerd Font install helpers. | `dot theme font install` |
| `scripts/git-hooks/` | Git hooks not managed by chezmoi (kept here for portable install). | `install/provision/*` |
| `scripts/qa/` | Quality-assurance helpers (PowerShell contract tests, version-consistency checks, scorecard snapshot, etc). | `reliability-gate.yml` (its `powershell-contract` job among others), `doc-drift.yml`, `dot-cli-bench.yml`, `npm-publish.yml` |
| `scripts/ci/` | Compat shims for pinned reusable workflows; the canonical scripts are in `tools/ci/`. | Old workflow pins |
| `scripts/nvim/` | `headless-upgrade.lua`: Lazy sync that waits for plugin, parser and tool work. | `dot system update` |
| `scripts/demo/` | Demonstration helpers (recordings, screenshots). | Manual |
| `scripts/version-sync.sh` | Propagates canonical `defaults/.chezmoidata.toml` version metadata to generated surfaces. | Release flow |
| `scripts/release-preflight` | Rejects version drift, reused immutable tags, and installer checksum drift before release. | Release flow / CI |
| `scripts/verify-release-versions` | Asserts every human-visible version surface matches `defaults/.chezmoidata.toml`. | Release flow / CI |
| `scripts/uninstall.sh` | Reverse-of-`install.sh` — user-invoked. | Manual |

### `tools/` (repo-only ops, not distributable)

| Path | Purpose | Touched by |
|---|---|---|
| `tools/ci/` | CI-only helpers: `dot-cli-startup-bench.sh`, `install-chezmoi-verified.sh`, `windows-smoke-test.ps1`, `run-coverage.sh`, etc. | `.github/workflows/*` |
| `tools/release/` | Release-time tasks. | Release workflow |
| `tools/maintenance/` | Recurring upkeep: `check-updates.sh`, etc. | Cron, manual |
| `tools/docs/` | Documentation-generation helpers (manual and site builds, `generate-command-index.sh`, and `gen_manpages.py`, `gen_completions.py`, `gen_cmdlets.py` from the command table). | `manual-publish.yml`, `dot help --manual`, doc-drift |

## `scripts/dot/` breakdown

The `dot` CLI is implemented as `bin/dot`
(dispatcher, reading the command table) + `plugins/<domain>/`
(one plugin per domain) + `lib/dot/*.sh` (shared helpers, moved out of
`scripts/dot/lib/` in the Phase 1 reorg per the
[reorganisation RFC](../docs/operations/RFC_v0_2_503_reorganization.md)).
`scripts/dot/` keeps the three legacy route handlers and the
PowerShell module.

| Path | Purpose |
|---|---|
| `scripts/dot/commands/` | Legacy route handlers. `bin/dot` runs `bash <file> <word> [args]`, and the file dispatches on the word. Sources the library via `$SCRIPT_DIR/../../../lib/dot/<X>.sh`. |
| `scripts/dot/powershell/` | Native PowerShell module — see top-level table. |
| **`lib/dot/utils.sh`** | Common helpers (resolve_source_dir, validate_name, die, run_script, etc.). |
| **`lib/dot/ui.sh`** | Single source of truth for CLI output (ui_ok/warn/err/info, ui_header, ui_table_*, ui_spinner_*, ui_confirm, ...). |
| **`lib/dot/platform.sh`** | OS / shell / WSL detection, path translation. |
| **`lib/dot/log.sh`** | Structured logging (JSON entries when `DOTFILES_JSON_LOG=1`). |
| **`lib/dot/bento.sh`** | The "bento box" intelligence surface that `dot top` runs. |

See [`../lib/dot/README.md`](../lib/dot/README.md) for every file.

## Adding a new subcommand

Commands follow ADR-020 (`dot <domain> [object] <verb>`); see
[`docs/adr/ADR-020-command-naming-system.md`](../docs/adr/ADR-020-command-naming-system.md).

1. Declare it in the domain's manifest,
   `plugins/<domain>/dot-plugin.toml`: a `[[commands]]` entry with its
   `verb`, optional `object`, `effect` and `summary`. A command not built
   yet gets `planned = true`.

2. Implement it in the plugin's entry, `plugins/<domain>/dot-<domain>`,
   or in a script under `plugins/<domain>/libexec/` that the entry runs.
   Source the shared helpers from `lib/dot/` (see
   [`../lib/dot/README.md`](../lib/dot/README.md)).

3. Regenerate the command table, the route fragments and the generated
   docs, and check them:

   ```bash
   python3 tools/ci/cli_command_table.py
   python3 tools/docs/gen_manpages.py
   python3 tools/docs/gen_completions.py
   python3 tools/docs/gen_cmdlets.py
   python3 tools/ci/check-cli-contract.py
   ```

4. Document it in `docs/manual/03-reference/01-dot-cli.md` and
   `docs/manual/command-index.md` if it is user-facing.

5. Add a unit test under `tests/unit/<domain>/test_<domain>_<feature>.sh`
   (run with `./tests/framework/test_runner.sh`).

## Conventions

- **Shell style**: 2-space indent, `set -euo pipefail`, shellcheck-clean
  with the project's flags (`--severity=error -e SC1091 -e SC2030 -e SC2031`).
- **Formatting**: `shfmt -i 2 -ci`.
- **Output**: NEVER `printf` raw ANSI. Source `lib/dot/ui.sh`
  and use `ui_ok`, `ui_table_*`, etc.
- **Exit codes** (ADR-020 N10): 0 ok, 1 warning or check failed,
  2 critical, 64 usage error, 75 temporary failure (such as a held
  lock), 127 unknown command, removed name or missing plugin,
  130 interrupted.
- **Validation**: Always `validate_name "$arg" "tool name"` before
  passing user input to `mise`, `gh`, `ssh`, etc.

## See also

- `../docs/STRUCTURE.md` — full repository map.
- `docs/manual/03-reference/01-dot-cli.md` — every `dot <cmd>` documented.
- `lib/dot/ui.sh` — the UI primitive library (always source this for output).
