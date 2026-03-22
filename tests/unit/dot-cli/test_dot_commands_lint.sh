#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI lint command
# Tests: file existence, syntax, functions, flags, dispatch

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

LINT_FILE="$REPO_ROOT/scripts/dot/commands/lint.sh"

# Test: lint.sh file exists
test_start "lint_file_exists"
assert_file_exists "$LINT_FILE" "lint.sh should exist"

# Test: lint.sh is executable
test_start "lint_file_executable"
if [[ -x "$LINT_FILE" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: lint.sh is executable"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: lint.sh should be executable"
fi

# Test: lint.sh is valid shell syntax
test_start "lint_syntax_valid"
if bash -n "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: lint.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: lint.sh has syntax errors"
fi

# Test: lint.sh uses strict mode
test_start "lint_strict_mode"
if grep -q 'set -euo pipefail' "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: lint.sh uses strict mode"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: lint.sh should use set -euo pipefail"
fi

# Test: lint.sh defines cmd_lint function
test_start "lint_defines_cmd_lint"
if grep -q 'cmd_lint()' "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines cmd_lint function"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define cmd_lint function"
fi

# Test: lint.sh uses project shellcheck flags
test_start "lint_shellcheck_flags"
if grep -q 'severity=error' "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses project shellcheck flags"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use --severity=error flag"
fi

# Test: lint.sh uses project shfmt flags
test_start "lint_shfmt_flags"
if grep -q '\-i 2 -ci' "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses project shfmt flags"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use -i 2 -ci shfmt flags"
fi

# Test: lint.sh supports --fix flag
test_start "lint_supports_fix_flag"
if grep -q '\-\-fix' "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports --fix flag"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should support --fix flag"
fi

# Test: lint.sh supports --check flag
test_start "lint_supports_check_flag"
if grep -q '\-\-check' "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports --check flag"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should support --check flag"
fi

# Test: lint.sh sources utils.sh
test_start "lint_sources_utils"
if grep -q 'source.*utils\.sh' "$LINT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: sources utils.sh"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should source utils.sh"
fi

echo ""
echo "Lint command unit tests completed."
print_summary
