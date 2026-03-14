#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/misc/logout.sh"

test_start "func_file_exists"
assert_file_exists "$FUNC_FILE" "logout.sh should exist"

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
assert_file_contains "$FUNC_FILE" 'Cross-Platform Logout Utility' "should contain help text"

test_start "force_flag_support"
assert_file_contains "$FUNC_FILE" '"--force"' "should support --force flag"

test_start "os_detection_via_uname"
assert_file_contains "$FUNC_FILE" 'uname' "should detect OS via uname"

test_start "darwin_logout_return_1"
if awk '/Failed to log out using AppleScript/{found=1} found && /return 1/{print "OK"; exit}' "$FUNC_FILE" | grep -q OK; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: return 1 after macOS logout error"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: return 1 after macOS logout error"
fi

test_start "linux_no_method_return_1"
if awk '/Unable to determine logout method/{found=1} found && /return 1/{print "OK"; exit}' "$FUNC_FILE" | grep -q OK; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: return 1 after Linux no-method error"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: return 1 after Linux no-method error"
fi

test_start "windows_logout_return_1"
if awk '/Failed to log out from Windows/{found=1} found && /return 1/{print "OK"; exit}' "$FUNC_FILE" | grep -q OK; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: return 1 after Windows logout error"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: return 1 after Windows logout error"
fi

test_start "unsupported_os_return_1"
if awk '/Unsupported operating system/{found=1} found && /return 1/{print "OK"; exit}' "$FUNC_FILE" | grep -q OK; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: return 1 after unsupported OS error"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: return 1 after unsupported OS error"
fi

test_start "logging_path_resolves_correctly"
if grep -q '../utils/logging.sh' "$FUNC_FILE"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: logging path uses ../utils/logging.sh"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: logging path should use ../utils/logging.sh"
fi

test_start "guarded_dollar_1"
# shellcheck disable=SC2016
if grep -q '"\${1:-}"' "$FUNC_FILE"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: \$1 is guarded with default"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: \$1 should be guarded with \${1:-}"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
