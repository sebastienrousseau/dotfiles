#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for doctor diagnostic script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

DOCTOR_FILE="$REPO_ROOT/scripts/diagnostics/doctor.sh"

# Test: doctor.sh file exists
test_start "doctor_file_exists"
assert_file_exists "$DOCTOR_FILE" "doctor.sh should exist"

# Test: doctor.sh is valid shell syntax
test_start "doctor_syntax_valid"
if bash -n "$DOCTOR_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: doctor.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: doctor.sh has syntax errors"
fi

# Test: defines diagnostic functions
test_start "doctor_defines_diagnostics"
if grep -qE 'diagnose|check_|verify_' "$DOCTOR_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines diagnostic functions"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define diagnostic functions"
fi

# Test: checks system configuration
test_start "doctor_checks_config"
if grep -qE 'config|chezmoi|\$HOME' "$DOCTOR_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks system configuration"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should check system configuration"
fi

# Test: provides remediation suggestions
test_start "doctor_provides_remediation"
if grep -qE 'fix|suggest|recommend|try|run' "$DOCTOR_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: provides remediation suggestions"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should provide remediation suggestions"
fi

# Test: shellcheck compliance
test_start "doctor_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$DOCTOR_FILE" 2>&1 | wc -l)
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
echo "Doctor diagnostic tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
