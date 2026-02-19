#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI security commands
# Tests: backup, firewall, telemetry, dns-doh, encrypt-check, lock-screen, usb-safety

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SEC_FILE="$REPO_ROOT/scripts/dot/commands/security.sh"

# Test: security.sh file exists
test_start "security_cmd_file_exists"
assert_file_exists "$SEC_FILE" "security.sh should exist"

# Test: security.sh is valid shell syntax
test_start "security_cmd_syntax_valid"
if bash -n "$SEC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: security.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: security.sh has syntax errors"
fi

# Test: defines firewall command
test_start "security_cmd_defines_firewall"
if grep -q "cmd_firewall\|_firewall\|firewall" "$SEC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines firewall command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define firewall command"
fi

# Test: defines backup command
test_start "security_cmd_defines_backup"
if grep -q "cmd_backup\|_backup\|backup" "$SEC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines backup command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define backup command"
fi

# Test: defines telemetry command
test_start "security_cmd_defines_telemetry"
if grep -q "cmd_telemetry\|telemetry" "$SEC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines telemetry command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define telemetry command"
fi

# Test: defines encrypt-check command
test_start "security_cmd_defines_encrypt_check"
if grep -q "encrypt.check\|encrypt_check\|encryptcheck" "$SEC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines encrypt-check command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define encrypt-check command"
fi

# Test: no dangerous commands
test_start "security_cmd_no_dangerous_rm"
if grep -qE 'rm -rf /[^$]' "$SEC_FILE" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: has dangerous rm -rf commands"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no dangerous rm commands"
fi

# Test: requires confirmation for destructive actions
test_start "security_cmd_confirms_destructive"
if grep -qE 'confirm|read -[rp]|yes/no|Y/n' "$SEC_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has confirmation prompts"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have confirmation for destructive actions"
fi

# Test: uses sudo appropriately
test_start "security_cmd_sudo_usage"
if grep -q "sudo" "$SEC_FILE" 2>/dev/null; then
  # Check if sudo is used with proper checks
  if grep -qE 'command -v sudo|which sudo|\$EUID' "$SEC_FILE" 2>/dev/null; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: sudo usage has proper checks"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: sudo should have availability check"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no sudo usage (OK)"
fi

# Test: shellcheck compliance
test_start "security_cmd_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$SEC_FILE" 2>&1 | wc -l)
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
echo "Security commands tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
