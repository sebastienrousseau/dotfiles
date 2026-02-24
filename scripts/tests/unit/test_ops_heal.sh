#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for heal operations script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

HEAL_FILE="$REPO_ROOT/scripts/ops/heal.sh"

# Test: heal.sh file exists
test_start "heal_file_exists"
assert_file_exists "$HEAL_FILE" "heal.sh should exist"

# Test: heal.sh is valid shell syntax
test_start "heal_syntax_valid"
if bash -n "$HEAL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: heal.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: heal.sh has syntax errors"
fi

# Test: defines healing functions
test_start "heal_defines_functions"
if grep -qE 'heal_|fix_|repair_' "$HEAL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines healing functions"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define healing functions"
fi

# Test: uses chezmoi for repairs
test_start "heal_uses_chezmoi"
if grep -q 'chezmoi' "$HEAL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses chezmoi for repairs"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use chezmoi for repairs"
fi

# Test: creates backup before healing
test_start "heal_creates_backup"
if grep -qE 'backup|cp.*bak|\.bak' "$HEAL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: creates backup before healing"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should backup before healing"
fi

# Test: shellcheck compliance
test_start "heal_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$HEAL_FILE" 2>&1 | wc -l)
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
echo "Heal operations tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
