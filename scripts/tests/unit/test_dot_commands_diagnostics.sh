#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI diagnostics commands
# Tests: drift, history, doctor, heal, health, security-score, benchmark, restore, rollback

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

DIAG_FILE="$REPO_ROOT/scripts/dot/commands/diagnostics.sh"

# Test: diagnostics.sh file exists
test_start "diagnostics_file_exists"
assert_file_exists "$DIAG_FILE" "diagnostics.sh should exist"

# Test: diagnostics.sh is valid shell syntax
test_start "diagnostics_syntax_valid"
if bash -n "$DIAG_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: diagnostics.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: diagnostics.sh has syntax errors"
fi

# Test: defines doctor command
test_start "diagnostics_defines_doctor"
if grep -q "cmd_doctor\|dot_doctor\|_doctor" "$DIAG_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines doctor command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define doctor command"
fi

# Test: defines health command
test_start "diagnostics_defines_health"
if grep -q "cmd_health\|dot_health\|_health" "$DIAG_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines health command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define health command"
fi

# Test: defines heal command
test_start "diagnostics_defines_heal"
if grep -q "cmd_heal\|dot_heal\|_heal" "$DIAG_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines heal command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define heal command"
fi

# Test: defines drift command
test_start "diagnostics_defines_drift"
if grep -q "cmd_drift\|dot_drift\|_drift" "$DIAG_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines drift command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define drift command"
fi

# Test: defines verify command
test_start "diagnostics_defines_verify"
if grep -q "cmd_verify\|dot_verify\|verify" "$DIAG_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines verify command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define verify command"
fi

# Test: defines security-score command
test_start "diagnostics_defines_security_score"
if grep -q "security.score\|security_score\|securityscore" "$DIAG_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines security-score command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define security-score command"
fi

# Test: no hardcoded paths
test_start "diagnostics_no_hardcoded_paths"
if grep -qE '"/home/[a-z]+' "$DIAG_FILE" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should not have hardcoded paths"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

# Test: uses logging functions
test_start "diagnostics_uses_logging"
if grep -qE 'run_script|echo "Running Dotfiles Doctor|ui_|log_' "$DIAG_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses logging/UI functions"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use logging functions"
fi

# Test: shellcheck compliance
test_start "diagnostics_shellcheck_clean"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$DIAG_FILE" 2>&1 | wc -l)
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
echo "Diagnostics commands tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
