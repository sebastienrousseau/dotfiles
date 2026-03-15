#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for ssh-cert security script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

CERT_FILE="$REPO_ROOT/scripts/security/ssh-cert.sh"

# Test: ssh-cert.sh file exists
test_start "ssh_cert_file_exists"
assert_file_exists "$CERT_FILE" "ssh-cert.sh should exist"

# Test: ssh-cert.sh is executable
test_start "ssh_cert_is_executable"
if [[ -x "$CERT_FILE" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: ssh-cert.sh is executable"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ssh-cert.sh should be executable"
fi

# Test: ssh-cert.sh is valid shell syntax
test_start "ssh_cert_syntax_valid"
if bash -n "$CERT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: ssh-cert.sh has valid syntax"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ssh-cert.sh has syntax errors"
fi

# Test: uses strict mode
test_start "ssh_cert_strict_mode"
if grep -q 'set -euo pipefail' "$CERT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses set -euo pipefail"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use set -euo pipefail"
fi

# Test: defines cmd_issue function
test_start "ssh_cert_defines_issue"
if grep -q 'cmd_issue' "$CERT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines cmd_issue function"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define cmd_issue function"
fi

# Test: defines cmd_status function
test_start "ssh_cert_defines_status"
if grep -q 'cmd_status' "$CERT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines cmd_status function"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define cmd_status function"
fi

# Test: defines cmd_revoke function
test_start "ssh_cert_defines_revoke"
if grep -q 'cmd_revoke' "$CERT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: defines cmd_revoke function"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should define cmd_revoke function"
fi

# Test: supports --ttl option
test_start "ssh_cert_ttl_option"
if grep -q -- '--ttl' "$CERT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports --ttl option"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should support --ttl option"
fi

# Test: supports --principal option
test_start "ssh_cert_principal_option"
if grep -q -- '--principal' "$CERT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports --principal option"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should support --principal option"
fi

# Test: respects SSH_CERT_CA_URL env var
test_start "ssh_cert_ca_url_env"
if grep -q 'SSH_CERT_CA_URL' "$CERT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: respects SSH_CERT_CA_URL env var"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should respect SSH_CERT_CA_URL"
fi

# Test: respects SSH_CERT_TTL env var
test_start "ssh_cert_ttl_env"
if grep -q 'SSH_CERT_TTL' "$CERT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: respects SSH_CERT_TTL env var"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should respect SSH_CERT_TTL"
fi

# Test: supports step-ca (Smallstep)
test_start "ssh_cert_step_ca_support"
if grep -qE 'step.*ssh|step-ca|ca-url' "$CERT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports step-ca integration"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should support step-ca"
fi

# Test: supports local CA key fallback
test_start "ssh_cert_local_ca_support"
if grep -q 'ca_key' "$CERT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: supports local CA key fallback"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should support local CA key"
fi

# Test: checks for missing SSH key
test_start "ssh_cert_checks_missing_key"
if grep -qE 'KEY_FILE.*not.*found|! -f.*KEY_FILE|error.*SSH key' "$CERT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: checks for missing SSH key"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should check for missing SSH key"
fi

# Test: help/usage output
test_start "ssh_cert_usage_output"
output=$(bash "$CERT_FILE" 2>&1 || true)
if echo "$output" | grep -qi 'usage\|ssh-cert'; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: shows usage when called without args"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should show usage without args"
fi

# Test: no dangerous commands
test_start "ssh_cert_no_dangerous_rm"
if grep -qE 'rm -rf /[^$]' "$CERT_FILE" 2>/dev/null; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: has dangerous rm -rf commands"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no dangerous rm commands"
fi

# Test: shellcheck compliance
test_start "ssh_cert_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error -e SC1091 "$CERT_FILE" 2>&1 | wc -l)
  if [[ "$errors" -eq 0 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: passes shellcheck"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: has shellcheck errors"
  fi
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: shellcheck not available, skipped"
fi

echo ""
echo "SSH certificate security tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
