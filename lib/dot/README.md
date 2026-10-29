# `lib/dot/` — Framework Library

Shared bash library sourced by the top-level dispatcher (`bin/dot`), the
plugins (`plugins/<domain>/dot-<domain>` and `plugins/<domain>/libexec/`)
and the runtime scripts under `scripts/`. Per
`docs/operations/RFC_v0_2_503_reorganization.md` Phase 1, the first of
these files moved here from `scripts/dot/lib/`.

From a script two levels below the repo root (`plugins/<domain>/libexec/`
or `scripts/dot/commands/`), source a helper as
`source "$SCRIPT_DIR/../../../lib/dot/<file>"`.

### Core helpers

| File | Exports |
|------|---------|
| `utils.sh` | `die`, `warn`, `info`, `has_command`, `validate_name`, `validate_xdg_path`, `resolve_source_dir`, `require_source_dir`, `run_script`, `dotfiles_version`, `dot_command_summary`, `dot_ui_command_banner`, `handle_help_flag`; also sources `ui.sh`, `platform.sh`, `preflight.sh`, `upgrade.sh`, `ai-install.sh` and `ai-provision.sh` |
| `ui.sh` | `ui_ok`, `ui_warn`, `ui_err`, `ui_info`, `ui_header`, `ui_section`, `ui_table_begin/add/end`, `ui_spinner_*`, `ui_steps_*`, `ui_pick`, `ui_confirm`, `ui_run_cmd` |
| `platform.sh` | `dot_platform_id`, `dot_host_os`, `dot_is_wsl`, `dot_path_to_unix`, `dot_path_to_native`, `dot_open_path`, `dot_require_platform` |
| `log.sh` | `dot_log`, `dot_metric`, `dot_jsonl_append`, `dot_agent_session_log`, `log_info/warn/error/success` shims |
| `preflight.sh` | Consent and prerequisites for commands that change the machine |
| `probe.sh` | `dot_probe`: run a query of another tool with a time limit |
| `verified-download.sh` | Checksum-verified downloads for installer and provisioning scripts |

### Command table and help

| File | Role |
|------|------|
| `names.sh` | Sourced by `bin/dot`: builds and reads the ADR-020 command table (merged from the plugins' route fragments, cached under `$XDG_CACHE_HOME/dot/cli/`) |
| `table-merge.awk` | Merges `data/groups.txt` and the `plugins/*/commands.txt` fragments into the command table |
| `help.sh` | `dot help` and `--help` rendering from the command table |
| `data/` | `commands.txt` (the bundled command table), `groups.txt`, `routes.txt`, `help-specs.txt`, `help-details.txt`, `commands.json`, `ai-roster.sh` |

### Domain helpers

| File | Used by |
|------|---------|
| `bento.sh` | `_dotfiles_bento_render`, the "D O T F I L E S" splash and intelligence-surface card that `dot top` runs |
| `ai-commands.sh`, `ai-install.sh`, `ai-probe.sh`, `ai-provision.sh`, `ai-roster.sh` | `dot ai` (`plugins/ai/libexec/ai.sh`), and doctor/apply for the roster and installer |
| `registry-module.sh`, `registry-trust.sh` | `dot cli install` and `dot cli list --available` (`plugins/cli/libexec/registry.sh`) |
| `system.sh` | `dot system status` and `dot system schedule list\|set\|run` |
| `upgrade.sh` | The toolchain side of `dot system update` |
| `installer-digest.sh` | The README installer SHA-256 for a release: `scripts/verify-release-versions` checks it, `scripts/version-sync.sh` writes it |
| `theme-niri.sh`, `theme-nvim.sh`, `theme-transaction.sh` | `bin/dot-theme-sync` targets and its transaction primitives |

## Why this directory exists

`scripts/dot/lib/` was the historical location. It moved here for
two reasons:

1. **Distribution shape**. The Homebrew / Scoop / AUR scaffolds in
   `pkg/{brew,scoop,aur}/` need a `lib/` directory at the
   repo root so `bin.install` and `lib.install` map cleanly.
2. **Layout discipline**. Mirrors the Debian/aws-cli convention
   (every top-level dir has a singular purpose): `scripts/` is
   for runtime scripts the CLI invokes, `tools/` for repo-internal
   ops, `lib/` for distributable framework code.

## Adding a new helper

Same `set -euo pipefail`-tolerant, ui_-namespaced contract as the
existing files. After adding `lib/dot/foo.sh`:

1. Source it from the consuming command:

   ```bash
   # shellcheck source=../../../lib/dot/foo.sh
   source "$SCRIPT_DIR/../../../lib/dot/foo.sh"
   ```

2. Document the helper here.
3. Add a unit test under `tests/unit/<domain>/test_<domain>_foo.sh`.

## See also

- `../../docs/STRUCTURE.md` — top-level repo map.
- `scripts/README.md` — `scripts/` subtree (the runtime scripts).
- `docs/operations/RFC_v0_2_503_reorganization.md` — full reorg plan.
