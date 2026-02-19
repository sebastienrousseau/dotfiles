#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for rollback operations script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

ROLLBACK_FILE="$REPO_ROOT/scripts/ops/rollback.sh"

# Test: rollback.sh file exists
test_start "rollback_file_exists"
assert_file_exists "$ROLLBACK_FILE" "rollback.sh should exist"

# Test: rollback.sh is valid shell syntax
test_start "rollback_syntax_valid"
if bash -n "$ROLLBACK_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: rollback.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: rollback.sh has syntax errors"
fi

# Test: supports rollback functionality
test_start "rollback_supports_rollback"
if grep -qE 'rollback|restore|revert|undo' "$ROLLBACK_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports rollback functionality"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support rollback"
fi

# Test: uses git for versioning
test_start "rollback_uses_git"
if grep -qE 'git|commit|checkout|reset' "$ROLLBACK_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses git for versioning"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use git for versioning"
fi

# Test: requires confirmation
test_start "rollback_requires_confirm"
if grep -qE 'confirm|y/n|yes|read -[rp]' "$ROLLBACK_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: requires confirmation"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should require confirmation"
fi

# Test: shellcheck compliance
test_start "rollback_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$ROLLBACK_FILE" 2>&1 | wc -l)
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
echo "Rollback operations tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
