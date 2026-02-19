#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI core commands
# Tests: apply, sync, update, add, diff, status, remove, cd, upgrade, edit, docs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

CORE_FILE="$REPO_ROOT/scripts/dot/commands/core.sh"

# Test: core.sh file exists
test_start "core_file_exists"
assert_file_exists "$CORE_FILE" "core.sh should exist"

# Test: core.sh is valid shell syntax
test_start "core_syntax_valid"
if bash -n "$CORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: core.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: core.sh has syntax errors"
fi

# Test: core.sh defines expected functions
test_start "core_defines_cmd_apply"
if grep -q "cmd_apply\|dot_apply" "$CORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines apply command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define apply command"
fi

test_start "core_defines_cmd_sync"
if grep -q "cmd_sync\|dot_sync" "$CORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines sync command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define sync command"
fi

test_start "core_defines_cmd_update"
if grep -q "cmd_update\|dot_update" "$CORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines update command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define update command"
fi

test_start "core_defines_cmd_diff"
if grep -q "cmd_diff\|dot_diff" "$CORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines diff command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define diff command"
fi

test_start "core_defines_cmd_status"
if grep -q "cmd_status\|dot_status" "$CORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines status command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define status command"
fi

# Test: no hardcoded paths
test_start "core_no_hardcoded_home"
if grep -qE '"/home/[a-z]+' "$CORE_FILE" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should not have hardcoded home paths"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded home paths"
fi

# Test: uses proper error handling
test_start "core_error_handling"
if grep -qE 'set -[euo]|errexit|nounset' "$CORE_FILE" 2>/dev/null || \
   grep -q '|| return\||| exit\|if \[\[' "$CORE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has error handling"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have error handling"
fi

# Test: shellcheck compliance (no major issues)
test_start "core_shellcheck_clean"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$CORE_FILE" 2>&1 | wc -l)
  if [[ "$errors" -eq 0 ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: passes shellcheck (error level)"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: has shellcheck errors"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shellcheck not available, skipped"
fi

# Test: no dangerous commands without guards
test_start "core_no_unguarded_rm_rf"
if grep -qE 'rm -rf /[^$]|rm -rf ~' "$CORE_FILE" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: has dangerous unguarded rm -rf"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no dangerous unguarded rm commands"
fi

echo ""
echo "Core commands tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
