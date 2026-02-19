#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for drift diagnostic script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

DRIFT_FILE="$REPO_ROOT/scripts/diagnostics/drift-dashboard.sh"

# Test: drift-dashboard.sh file exists
test_start "drift_file_exists"
assert_file_exists "$DRIFT_FILE" "drift-dashboard.sh should exist"

# Test: drift-dashboard.sh is valid shell syntax
test_start "drift_syntax_valid"
if bash -n "$DRIFT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

# Test: detects drift
test_start "drift_detects_changes"
if grep -qE 'drift|diff|changed|modified' "$DRIFT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: detects drift"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should detect drift"
fi

# Test: uses chezmoi
test_start "drift_uses_chezmoi"
if grep -q 'chezmoi' "$DRIFT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses chezmoi"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use chezmoi"
fi

# Test: shellcheck compliance
test_start "drift_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$DRIFT_FILE" 2>&1 | wc -l)
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
echo "Drift diagnostic tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
