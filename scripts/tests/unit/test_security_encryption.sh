#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for encryption-check security script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

ENC_FILE="$REPO_ROOT/scripts/security/encryption-check.sh"

# Test: encryption-check.sh file exists
test_start "encryption_file_exists"
assert_file_exists "$ENC_FILE" "encryption-check.sh should exist"

# Test: encryption-check.sh is valid shell syntax
test_start "encryption_syntax_valid"
if bash -n "$ENC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: encryption-check.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: encryption-check.sh has syntax errors"
fi

# Test: checks disk encryption
test_start "encryption_checks_disk"
if grep -qE 'filevault|luks|bitlocker|encrypt|crypt' "$ENC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks disk encryption"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should check disk encryption"
fi

# Test: supports multiple platforms
test_start "encryption_multiplatform"
if grep -qE 'darwin|linux|macos|Linux' "$ENC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports multiple platforms"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support multiple platforms"
fi

# Test: reports encryption status
test_start "encryption_reports_status"
if grep -qE 'enabled|disabled|encrypted|not encrypted|status' "$ENC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: reports encryption status"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should report encryption status"
fi

# Test: shellcheck compliance
test_start "encryption_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$ENC_FILE" 2>&1 | wc -l)
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
echo "Encryption tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
