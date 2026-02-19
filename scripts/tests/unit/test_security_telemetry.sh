#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for telemetry-kill security script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

TEL_FILE="$REPO_ROOT/scripts/security/telemetry-kill.sh"

# Test: telemetry-kill.sh file exists
test_start "telemetry_file_exists"
assert_file_exists "$TEL_FILE" "telemetry-kill.sh should exist"

# Test: telemetry-kill.sh is valid shell syntax
test_start "telemetry_syntax_valid"
if bash -n "$TEL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: telemetry-kill.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: telemetry-kill.sh has syntax errors"
fi

# Test: disables telemetry
test_start "telemetry_disables"
if grep -qE 'telemetry|tracking|analytics|disable' "$TEL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: disables telemetry"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should disable telemetry"
fi

# Test: handles multiple applications
test_start "telemetry_multiple_apps"
if grep -cE 'ubuntu|whoopsie|apport|analytics|telemetry|popularity-contest' "$TEL_FILE" 2>/dev/null | grep -qE '^[2-9]|^[0-9]{2,}'; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: handles multiple applications"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should handle multiple applications"
fi

# Test: shellcheck compliance
test_start "telemetry_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$TEL_FILE" 2>&1 | wc -l)
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
echo "Telemetry tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
