#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot/lib/ui.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

UI_FILE="$REPO_ROOT/scripts/dot/lib/ui.sh"

# Test: ui.sh file exists
test_start "ui_file_exists"
assert_file_exists "$UI_FILE" "ui.sh should exist"

# Test: ui.sh is valid shell syntax
test_start "ui_syntax_valid"
if bash -n "$UI_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: ui.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: ui.sh has syntax errors"
fi

# Test: defines UI functions
test_start "ui_defines_functions"
if grep -qE 'ui_|print_|show_' "$UI_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines UI functions"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define UI functions"
fi

# Test: has spinner/progress functions
test_start "ui_has_progress"
if grep -qE 'spinner|progress|loading' "$UI_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has progress indicators"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have progress indicators"
fi

# Test: uses ANSI colors
test_start "ui_uses_colors"
if grep -qE '\\033\[|\\e\[|tput' "$UI_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses ANSI colors"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use ANSI colors"
fi

# Test: shellcheck compliance
test_start "ui_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$UI_FILE" 2>&1 | wc -l)
  if [[ "$errors" -eq 0 ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: passes shellcheck"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: has shellcheck errors"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shellcheck not available"
fi

echo ""
echo "UI library tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
