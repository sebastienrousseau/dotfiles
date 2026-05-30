# `lib/dot/` — Framework Library

Shared bash library sourced by every `dot` subcommand and the
top-level dispatcher. Per `docs/operations/RFC_v0_2_503_reorganization.md`
Phase 1, these files moved here from `scripts/dot/lib/`.

| File | Exports | Source from `scripts/dot/commands/*.sh` |
|------|---------|-----------------------------------------|
| `utils.sh` | `die`, `warn`, `info`, `has_command`, `validate_name`, `validate_xdg_path`, `require_source_dir`, `dotfiles_version`, `dot_command_summary`, `dot_ui_command_banner` | `source "$SCRIPT_DIR/../../../lib/dot/utils.sh"` |
| `ui.sh` | `ui_ok`, `ui_warn`, `ui_err`, `ui_info`, `ui_header`, `ui_section`, `ui_table_begin/add/end`, `ui_spinner_*`, `ui_confirm`, `ui_run_cmd` | `source "$SCRIPT_DIR/../../../lib/dot/ui.sh"` |
| `platform.sh` | `dot_platform_os`, `dot_path_to_unix`, `dot_path_to_native`, WSL detection | `source "$SCRIPT_DIR/../../../lib/dot/platform.sh"` |
| `log.sh` | `dot_log`, `dot_metric`, `dot_jsonl_append`, `dot_agent_session_log`, `log_info/warn/error/success` shims | `source "$SCRIPT_DIR/../../../lib/dot/log.sh"` |
| `bento.sh` | `dot_render_bento` (the "💎 D O T F I L E S" splash + intelligence-surface card) | `source "$SCRIPT_DIR/../../../lib/dot/bento.sh"` |

## Why this directory exists

`scripts/dot/lib/` was the historical location. It moved here for
two reasons:

1. **Distribution shape**. The Homebrew / Scoop / AUR scaffolds in
   `install/{homebrew,scoop,aur}/` need a `lib/` directory at the
   repo root so `bin.install` and `lib.install` map cleanly.
2. **Layout discipline**. Mirrors the Debian/aws-cli convention
   (every top-level dir has a singular purpose) — `scripts/` is
   for repo-internal ops, `lib/` is for distributable framework
   code.

## Adding a new helper

Same `set -euo pipefail`-tolerant, ui_-namespaced contract as the
existing files. After adding `lib/dot/foo.sh`:

1. Source it from the consuming command:

   ```bash
   # shellcheck source=../../../lib/dot/foo.sh
   source "$SCRIPT_DIR/../../../lib/dot/foo.sh"
   ```

2. Document the helper here.
3. Add a unit test under `tests/unit/lib/test_foo.sh`.

## See also

- `../../docs/STRUCTURE.md` — top-level repo map.
- `scripts/README.md` — `scripts/` subtree (the ops-only sister).
- `docs/operations/RFC_v0_2_503_reorganization.md` — full reorg plan.
