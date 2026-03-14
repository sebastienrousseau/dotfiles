#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/files/hiddenfiles.sh"

test_start "func_file_exists"
assert_file_exists "$FUNC_FILE" "hiddenfiles.sh should exist"

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

test_start "darwin_guard_present"
assert_file_contains "$FUNC_FILE" 'uname -s' "should check for Darwin platform"

test_start "darwin_guard_rejects_non_mac"
assert_file_contains "$FUNC_FILE" 'macOS only' "should show macOS only message"

test_start "help_output"
assert_file_contains "$FUNC_FILE" 'Hidden Files Visibility Toggle' "should contain help text"

test_start "invalid_arg_returns_error"
assert_file_contains "$FUNC_FILE" 'Invalid argument' "should handle invalid arguments"

test_start "defaults_write_usage"
assert_file_contains "$FUNC_FILE" 'defaults write com.apple.Finder' "should use defaults write for Finder"

test_start "osascript_usage"
assert_file_contains "$FUNC_FILE" 'osascript' "should use osascript to restart Finder"

test_start "guarded_dollar_1"
if grep -q '"\${1:-}"' "$FUNC_FILE"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: \$1 is guarded with default"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: \$1 should be guarded with \${1:-}"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
