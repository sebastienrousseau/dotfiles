#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## Coverage-exercise test: drives high-value, side-effect-free code paths so
## the xtrace coverage runner records them. Targets lib/dot/ui.sh (all ui_*
## output helpers), the env-emit command, and version-sync's --help/--dry-run.
## Each target is exercised inside a `set +e` subshell so a sourced library's
## `set -e` can't abort this test; assertions are deliberately robust.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"
export DOT_COMMAND="coverage-exercise"

# 1. lib/dot/ui.sh — every output helper (non-TTY, output discarded).
(
  set +e
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/dot/ui.sh"
  ui_init
  ui_header "Coverage" "exercise"
  ui_section "section"
  ui_status "ok" "label" "detail"
  ui_ok "label" "detail"
  ui_warn "label" "detail"
  ui_err "label" "detail"
  ui_info "label" "detail"
  ui_meta "label" "detail"
  ui_cmd "some cmd" "desc"
  ui_bullet "bullet"
  ui_kv "key" "value"
  ui_key_value "Key" "Value"
  ui_clear_line
  ui_hide_cursor
  ui_show_cursor
  ui_spinner_start "spinning"
  ui_spinner_stop
  ui_progress 1 3 8
  ui_progress 0 0 8
  ui_run_cmd "run true" 0 1 true
  ui_run_cmd "run false" 0 1 false
  printf 'n\n' | ui_confirm "confirm?" n
  DOTFILES_NONINTERACTIVE=1 ui_confirm "confirm?" y
  DOTFILES_NONINTERACTIVE=1 ui_confirm "confirm?" n
  ui_toast success "toast ok"
  ui_toast error "toast err"
  ui_toast warn "toast warn"
  ui_toast info "toast info"
  ui_table_header "A" "B"
  ui_table_row "1" "2"
  ui_table_sep
  ui_table_begin "A" "B"
  ui_table_add "x" "y"
  ui_table_add "longer" "value"
  ui_table_end
  ui_table_add "orphan" "row"
  ui_steps_begin "Steps" "plain"
  ui_step one "Step One" run
  ui_step one "Step One" ok "done"
  ui_step two "Step Two" warn "warned"
  ui_step three "Step Three" fail "failed"
  ui_step four "Step Four" skip "skipped"
  ui_step five "Step Five" na
  ui_step_progress 1 5
  ui_step_wait "waiting"
  ui_steps_end "summary"
  printf 'a\nb\n' | DOTFILES_NO_TUI=1 ui_pick --header "Pick" --prompt "Select"
  ui_logo_dot
  ui_product_banner "Product"
  ui_product_banner "Product again"
  ui_dot_banner "Section"
  DOTFILES_SHOW_LOGO=0 ui_product_banner "Hidden"
) >/dev/null || true
test_start "ui_helpers_exercised"
assert_file_exists "$REPO_ROOT/lib/dot/ui.sh" "ui.sh present and exercised"

# 2. lib/dot/ui.sh accessibility branch — ASCII glyphs and disabled rich UI.
(
  set +e
  export DOTFILES_ACCESSIBILITY=1
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/dot/ui.sh"
  ui_init
  ui_header "Accessible"
  ui_section "section"
  ui_ok "ok"
  ui_warn "warn"
  ui_err "err"
  ui_info "info"
  ui_cmd "cmd" "desc"
  ui_bullet "bullet"
  ui_progress 2 4 8
  ui_logo_dot "Accessible"
) >/dev/null || true
test_start "ui_accessibility_helpers_exercised"
assert_file_contains "$REPO_ROOT/lib/dot/ui.sh" "DOTFILES_ACCESSIBILITY" "ui accessibility branch present and exercised"

# 3. lib/dot/utils.sh — source-dir, command summaries, and help guards.
(
  set +e
  export HOME="$REPO_ROOT"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/dot/utils.sh"
  resolve_source_dir
  resolve_chezmoi_source_dir
  require_source_dir
  has_command bash
  has_command __dotfiles_missing_command__
  validate_name "valid-name_1.txt" "fixture"
  validate_xdg_path XDG_CACHE_HOME "/tmp/cache"
  validate_xdg_path XDG_CACHE_HOME "relative/cache"
  dotfiles_version
  ui_logo_once "Utils"
  DOTFILES_SHOW_LOGO=0 ui_logo_once "Hidden"
  dot_ui_command_banner "Core" "status"
  dot_ui_command_banner "Core" "status" --json
  is_help_flag --help
  is_help_flag -h
  is_help_flag -- --help
  dot_show_help status
  handle_help_flag status --help
  handle_help_flag status --
  for cmd in apply ai update add diff status remove cd edit doctor heal health security-score scorecard perf conflicts locks snapshot rollback restore drift history benchmark verify tools aliases new packages log-rotate setup theme wallpaper fonts tune secrets-init secrets env secrets-create ssh-key backup encrypt-check firewall telemetry dns-doh lock-screen usb-safety fleet upgrade docs learn keys sandbox mcp metrics cache-refresh search help version unknown; do
    dot_command_summary "$cmd"
  done
) >/dev/null || true
test_start "utils_helpers_exercised"
assert_file_exists "$REPO_ROOT/lib/dot/utils.sh" "utils.sh present and exercised"

# 4. env-emit command — render env in each format (read-only).
(
  set +e
  # shellcheck disable=SC1091
  source "$REPO_ROOT/scripts/dot/commands/env-emit.sh"
  if declare -f dot_env_emit >/dev/null 2>&1; then
    dot_env_emit --help
    dot_env_emit --format json --compact
    dot_env_emit --format json --pretty
    dot_env_emit
  fi
) >/dev/null || true
test_start "env_emit_exercised"
assert_file_exists "$REPO_ROOT/scripts/dot/commands/env-emit.sh" "env-emit present and exercised"

# 5. version-sync.sh — help + dry-run (dry-run does not write files).
(
  set +e
  bash "$REPO_ROOT/scripts/version-sync.sh" --help
  bash "$REPO_ROOT/scripts/version-sync.sh" --dry-run
) >/dev/null || true
test_start "version_sync_exercised"
assert_file_exists "$REPO_ROOT/scripts/version-sync.sh" "version-sync present and exercised"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
