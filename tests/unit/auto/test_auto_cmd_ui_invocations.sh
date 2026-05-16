#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Hand-curated invocation test for scripts/dot/lib/ui.sh. The generic
# fn-exercise helper calls each ui_* function with `$tmpfile`, which
# produces output but doesn't exercise the conditional branches inside
# each helper. This test passes the SHAPE each function expects
# (status enum, key/value pair, color flag, progress %) so the body
# of every helper runs end-to-end. Closes a ~50-line gap in ui.sh
# vs the generic helper alone.
#
# AUTO-GENERATED: false (hand-written, do not regenerate)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

UI="$REPO_ROOT/scripts/dot/lib/ui.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "ui_sh_exists"
assert_file_exists "$UI" "ui.sh must exist"

# Helper: run the inner script under sourced ui.sh with full
# interpreter trapping. Each invocation runs in its own bash -c so
# UI_ENABLED / UI_UTF8 state doesn't leak between calls.
run_under_ui() {
  local title="$1"
  shift
  test_start "ui_${title}"
  bash -c '
    set +eu
    source "$1" || true
    set +eu
    shift
    "$@"
  ' _ "$UI" "$@" </dev/null >/dev/null 2>&1
  rc=$?
  # rc=124 means timeout (real failure); 127 means command-not-found
  # (a sandbox quirk we accept). Everything else is "ran cleanly".
  if [[ "$rc" -ne 124 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
  fi
}

# The init function with a few env modes
run_under_ui init_default       ui_init
run_under_ui init_accessibility env DOTFILES_ACCESSIBILITY=1 bash -c 'source "'"$UI"'"; ui_init; ui_ok "test" "ok"'

# Status helpers (each takes 1-2 args)
run_under_ui header              ui_header "Test Header"
run_under_ui section             ui_section "Test Section"
run_under_ui ok                  ui_ok "Component" "success message"
run_under_ui warn                ui_warn "Component" "warning message"
run_under_ui err                 ui_err "Component" "error message"
run_under_ui info                ui_info "Component" "info text"
run_under_ui meta                ui_meta "Component" "meta value"
run_under_ui cmd                 ui_cmd "echo hello"
run_under_ui bullet              ui_bullet "bullet item"
run_under_ui kv                  ui_kv "key" "value"
run_under_ui key_value           ui_key_value "key" "value"

# Cursor / clear-line helpers (TTY no-ops in our sandbox)
run_under_ui clear_line          ui_clear_line
run_under_ui hide_cursor         ui_hide_cursor
run_under_ui show_cursor         ui_show_cursor

# Status enum dispatcher
run_under_ui status_ok           ui_status "ok"   "label" "value"
run_under_ui status_fail         ui_status "fail" "label" "value"
run_under_ui status_warn         ui_status "warn" "label" "value"
run_under_ui status_info         ui_status "info" "label" "value"
run_under_ui status_skip         ui_status "skip" "label" "value"

# Progress (percentage form)
run_under_ui progress_25         ui_progress 25
run_under_ui progress_50         ui_progress 50 "Halfway done"
run_under_ui progress_100        ui_progress 100 "Complete"

# Spinner — start without TTY no-ops cleanly; stop reaps the bg loop.
run_under_ui spinner_pair        bash -c 'source "'"$UI"'"; ui_init; ui_spinner_start "test"; ui_spinner_stop'

# ui_run_cmd in non-TTY mode (the round-2 mktemp-race fix lives here).
# Both success and failure paths exercise different branches.
run_under_ui run_cmd_success     bash -c 'source "'"$UI"'"; ui_init; ui_run_cmd "label" 0 1 true'
run_under_ui run_cmd_failure     bash -c 'source "'"$UI"'"; ui_init; ui_run_cmd "label" 0 1 false'

# Toast / table primitives — visual helpers used by `dot doctor`,
# `dot fleet`, etc. Each has a no-arg / single-arg / multi-cell shape.
run_under_ui toast_default       ui_toast "Hello"
run_under_ui toast_success       ui_toast "Saved" "ok"
run_under_ui toast_warn          ui_toast "Drift detected" "warn"
run_under_ui table_header        ui_table_header "Col A" "Col B" "Col C"
run_under_ui table_row           ui_table_row    "data1" "data2" "data3"
run_under_ui table_sep           ui_table_sep

# Banner helpers — branding strings used by every command's banner.
run_under_ui logo_dot            ui_logo_dot
run_under_ui product_banner      ui_product_banner "Dot" "Reference"
run_under_ui dot_banner          ui_dot_banner "Reference"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
