#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot/lib/ui.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

UI_FILE="$REPO_ROOT/lib/dot/ui.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# Test: ui.sh file exists
test_start "ui_file_exists"
assert_file_exists "$UI_FILE" "ui.sh should exist"

# Test: ui.sh is valid shell syntax
test_start "ui_syntax_valid"
if bash -n "$UI_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: ui.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ui.sh has syntax errors"
fi

# Test: defines UI functions
test_start "ui_defines_functions"
if grep -qE 'ui_|print_|show_' "$UI_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines UI functions"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define UI functions"
fi

# Test: has spinner/progress functions
test_start "ui_has_progress"
if grep -qE 'ui_status|ui_logo_dot|ui_bullet|ui_kv' "$UI_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has rich UI helpers"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define rich UI helpers"
fi

test_start "ui_progress_glyphs"
assert_file_contains "$UI_FILE" '_GL_BAR_FILL="￭"' "uses halfwidth black square for filled bars"
assert_file_contains "$UI_FILE" '_GL_BAR_EMPTY="･"' "uses a lightweight empty progress glyph"

# Test: uses ANSI colors
test_start "ui_uses_colors"
if grep -qE 'tput|UI_COLOR|BOLD|RED|GREEN|BLUE' "$UI_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses ANSI colors"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use ANSI colors"
fi

# Test: shellcheck compliance
test_start "ui_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$UI_FILE" 2>&1 | wc -l)
  if [[ "$errors" -eq 0 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: passes shellcheck"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: has shellcheck errors"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: shellcheck not available"
fi

# Test: a zero-row table must render, not abort.
#
# Regression guard. ui_table_end and _ui_table_printf_fallback expanded
# "${_UI_TABLE_ROWS[@]}" unguarded. On bash 3.2 — still /bin/bash on
# macOS — expanding an empty array under `set -u` is an unbound-variable
# error, which is fatal regardless of errexit. Any command rendering an
# empty table (e.g. `dot registry search` with no matches) died instead
# of printing an empty table. bash 4.4+ is unaffected, so this only
# fails on the macOS runners.
test_start "ui_table_empty_no_unbound_variable"
if out="$(
  bash -c '
    set -euo pipefail
    source "$1" || exit 1
    ui_table_begin "Col A" "Col B"
    ui_table_end
    ui_table_sep
    printf "SURVIVED\n"
  ' _ "$UI_FILE" 2>&1
)" && [[ "$out" == *SURVIVED* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: empty table renders"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: aborted on empty table — ${out:-no output}"
fi

echo ""
echo "UI library tests completed."
# Slice 3 (#883): exercise the script under sandbox for line coverage
cov_exercise_script "$UI_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
