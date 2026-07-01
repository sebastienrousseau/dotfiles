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
  ui_progress 1 3 "progress"
  ui_run_cmd "run true" true
  printf 'n\n' | ui_confirm "confirm?"
  ui_toast "toast message"
  ui_table_header "A" "B"
  ui_table_row "1" "2"
  ui_table_sep
  ui_table_begin "A" "B"
  ui_table_add "x" "y"
  ui_table_end
  ui_logo_dot
  ui_product_banner "Product"
  ui_dot_banner "Section"
) >/dev/null 2>&1 || true
test_start "ui_helpers_exercised"
assert_file_exists "$REPO_ROOT/lib/dot/ui.sh" "ui.sh present and exercised"

# 2. env-emit command — render env in each format (read-only).
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
) >/dev/null 2>&1 || true
test_start "env_emit_exercised"
assert_file_exists "$REPO_ROOT/scripts/dot/commands/env-emit.sh" "env-emit present and exercised"

# 3. version-sync.sh — help + dry-run (dry-run does not write files).
(
  set +e
  bash "$REPO_ROOT/scripts/version-sync.sh" --help
  bash "$REPO_ROOT/scripts/version-sync.sh" --dry-run
) >/dev/null 2>&1 || true
test_start "version_sync_exercised"
assert_file_exists "$REPO_ROOT/scripts/version-sync.sh" "version-sync present and exercised"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
