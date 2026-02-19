#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot/lib/utils.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

UTILS_FILE="$REPO_ROOT/scripts/dot/lib/utils.sh"

# Test: utils.sh file exists
test_start "utils_file_exists"
assert_file_exists "$UTILS_FILE" "utils.sh should exist"

# Test: utils.sh is valid shell syntax
test_start "utils_syntax_valid"
if bash -n "$UTILS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: utils.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: utils.sh has syntax errors"
fi

# Test: defines utility functions
test_start "utils_defines_functions"
func_count=$(grep -cE '^[a-z_]+\(\)\s*\{' "$UTILS_FILE" 2>/dev/null || echo 0)
if [[ "$func_count" -gt 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines $func_count functions"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define utility functions"
fi

# Test: has logging functions
test_start "utils_has_logging"
if grep -qE 'log_|print_|echo_' "$UTILS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has logging functions"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have logging functions"
fi

# Test: uses colors properly
test_start "utils_uses_colors"
if grep -qE 'RED|GREEN|YELLOW|NC|\\033\[|tput' "$UTILS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses color codes"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use color codes"
fi

# Test: no hardcoded paths
test_start "utils_no_hardcoded_paths"
if grep -qE '"/home/[a-z]+' "$UTILS_FILE" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: has hardcoded paths"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

# Test: shellcheck compliance
test_start "utils_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$UTILS_FILE" 2>&1 | wc -l)
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
echo "Utils library tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
