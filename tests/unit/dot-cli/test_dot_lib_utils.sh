#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot/lib/utils.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

UTILS_FILE="$REPO_ROOT/lib/dot/utils.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# Test: utils.sh file exists
test_start "utils_file_exists"
assert_file_exists "$UTILS_FILE" "utils.sh should exist"

# Test: utils.sh is valid shell syntax
test_start "utils_syntax_valid"
if bash -n "$UTILS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: utils.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: utils.sh has syntax errors"
fi

# Test: the helpers behave as documented
test_start "utils_defines_functions"
utils_rc() { bash -c 'source "$1"; shift; "$@"' _ "$UTILS_FILE" "$@" >/dev/null 2>&1 && echo 0 || echo $?; }
assert_equals "0" "$(utils_rc has_command bash)" "has_command finds bash"
assert_equals "1" "$(utils_rc has_command dot-no-such-command)" "and not a missing command"
assert_equals "0" "$(utils_rc validate_name ok-name.1)" "validate_name accepts a safe name"
assert_equals "1" "$(utils_rc validate_name '../x')" "and rejects a path"
assert_equals "3" "$(utils_rc die boom 3)" "die exits with the code it is given"
assert_contains "boom" "$(bash -c 'source "$1"; die boom' _ "$UTILS_FILE" 2>&1 >/dev/null)" "die prints to stderr"

# Test: has logging functions
test_start "utils_has_logging"
if grep -qE 'die\(|warn\(|info\(|ui_' "$UTILS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: has logging functions"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have logging functions"
fi

# Test: uses colors properly
test_start "utils_uses_colors"
if grep -qE 'source .*ui.sh|ui_err|ui_warn|ui_info' "$UTILS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses color codes"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use color codes"
fi

# Test: no hardcoded paths
test_start "utils_no_hardcoded_paths"
if grep -qE '"/home/[a-z]+' "$UTILS_FILE" 2>/dev/null; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: has hardcoded paths"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

# Test: shellcheck compliance
echo ""
echo "Utils library tests completed."
# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$UTILS_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
