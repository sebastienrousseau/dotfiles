#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/misc/last.sh"

test_start "func_file_exists"
assert_file_exists "$FUNC_FILE" "last.sh should exist"

test_start "func_valid_syntax"
if bash -n "$FUNC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "func_defines_function"
if grep -qE '^[a-z_]+\(\)\s*\{' "$FUNC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "logging_fallback_defined"
assert_file_contains "$FUNC_FILE" 'declare -f log_error' "should have logging fallback guard"

test_start "logging_fallback_defines_log_error"
assert_file_contains "$FUNC_FILE" 'log_error() { echo "[ERROR]' "should define fallback log_error"

test_start "help_output"
assert_file_contains "$FUNC_FILE" 'Recently Modified Files Viewer' "should contain help text"

test_start "detect_tool_returns_valid"
assert_file_contains "$FUNC_FILE" 'detect_tool()' "should define detect_tool function"

test_start "invalid_input_returns_error"
assert_file_contains "$FUNC_FILE" "Invalid input:" "should check for invalid input"

test_start "invalid_input_has_return_1"
# Verify return 1 follows the invalid input log_error
if awk '/Invalid input/{found=1} found && /return 1/{print "OK"; exit}' "$FUNC_FILE" | grep -q OK; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: return 1 after invalid input error"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: return 1 after invalid input error"
fi

test_start "max_range_returns_error"
assert_file_contains "$FUNC_FILE" "Time range too large" "should check for max time range"

test_start "max_range_has_return_1"
if awk '/Time range too large/{found=1} found && /return 1/{print "OK"; exit}' "$FUNC_FILE" | grep -q OK; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: return 1 after max range error"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: return 1 after max range error"
fi

test_start "detect_tool_no_rg_fallback"
# rg doesn't support --changed-within; detect_tool should not list it
if grep -q '"rg"' "$FUNC_FILE" 2>/dev/null; then
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: rg should not be a fallback (invalid flags)"
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: rg correctly excluded from detect_tool"
fi

test_start "detect_tool_no_tools_has_return_1"
if awk '/No compatible tools found/{found=1} found && /return 1/{print "OK"; exit}' "$FUNC_FILE" | grep -q OK; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: return 1 after no tools error"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: return 1 after no tools error"
fi

test_start "logging_path_resolves_correctly"
# The logging source path should use ../ to reach utils/ from misc/
if grep -q '../utils/logging.sh' "$FUNC_FILE"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: logging path uses ../utils/logging.sh"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: logging path should use ../utils/logging.sh"
fi

test_start "unknown_tool_has_return_1"
if awk '/Unknown tool detected/{found=1} found && /return 1/{print "OK"; exit}' "$FUNC_FILE" | grep -q OK; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: return 1 after unknown tool error"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: return 1 after unknown tool error"
fi

test_start "guarded_dollar_1"
# The help check should use ${1:-} not bare "$1"
# shellcheck disable=SC2016
if grep -q '"\${1:-}"' "$FUNC_FILE"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: \$1 is guarded with default"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: \$1 should be guarded with \${1:-}"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
