#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for health diagnostic script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

HEALTH_FILE="$REPO_ROOT/scripts/diagnostics/health.sh"

# Test: health.sh file exists
test_start "health_file_exists"
assert_file_exists "$HEALTH_FILE" "health.sh should exist"

# Test: health.sh is valid shell syntax
test_start "health_syntax_valid"
if bash -n "$HEALTH_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: health.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: health.sh has syntax errors"
fi

# Test: defines health check functions
test_start "health_defines_check_functions"
if grep -qE 'check_|run_check|health_check' "$HEALTH_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines check functions"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define check functions"
fi

# Test: checks for required tools
test_start "health_checks_tools"
if grep -qE 'command -v|which|type' "$HEALTH_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks for tool availability"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should check for tool availability"
fi

# Test: provides pass/fail output
test_start "health_provides_status"
if grep -qE 'PASS|FAIL|OK|ERROR|✓|✗' "$HEALTH_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: provides pass/fail status"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should provide pass/fail status"
fi

# Test: no hardcoded paths
test_start "health_no_hardcoded_paths"
if grep -qE '"/home/[a-z]+' "$HEALTH_FILE" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should not have hardcoded paths"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

# Test: shellcheck compliance
test_start "health_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$HEALTH_FILE" 2>&1 | wc -l)
  if [[ "$errors" -eq 0 ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: passes shellcheck"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: has shellcheck errors"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shellcheck not available, skipped"
fi

echo ""
echo "Health diagnostic tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
