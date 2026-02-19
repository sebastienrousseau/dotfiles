#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI secrets commands
# Tests: secrets, secrets-init, secrets-create, ssh-key

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SECRETS_FILE="$REPO_ROOT/scripts/dot/commands/secrets.sh"

# Test: secrets.sh file exists
test_start "secrets_cmd_file_exists"
assert_file_exists "$SECRETS_FILE" "secrets.sh should exist"

# Test: secrets.sh is valid shell syntax
test_start "secrets_cmd_syntax_valid"
if bash -n "$SECRETS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: secrets.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: secrets.sh has syntax errors"
fi

# Test: defines secrets command
test_start "secrets_cmd_defines_secrets"
if grep -q "cmd_secrets\|_secrets" "$SECRETS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines secrets command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define secrets command"
fi

# Test: defines secrets-init command
test_start "secrets_cmd_defines_init"
if grep -q "secrets.init\|secrets_init\|secretsinit" "$SECRETS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines secrets-init command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define secrets-init command"
fi

# Test: defines ssh-key command
test_start "secrets_cmd_defines_ssh_key"
if grep -q "ssh.key\|ssh_key\|sshkey" "$SECRETS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines ssh-key command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define ssh-key command"
fi

# Test: uses secure file permissions
test_start "secrets_cmd_secure_permissions"
if grep -qE 'chmod [0-7]*00|chmod 600|chmod 700' "$SECRETS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses secure file permissions"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use secure file permissions (600/700)"
fi

# Test: no secrets in plain text
test_start "secrets_cmd_no_plaintext_secrets"
if grep -qE '(password|secret|token)\s*=\s*["\047][^$][^"\047]+["\047]' "$SECRETS_FILE" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: may contain plaintext secrets"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no plaintext secrets"
fi

# Test: uses age for encryption
test_start "secrets_cmd_uses_age"
if grep -qE 'age|\.age|chezmoi.*encrypt' "$SECRETS_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses age encryption"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use age encryption"
fi

# Test: shellcheck compliance
test_start "secrets_cmd_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$SECRETS_FILE" 2>&1 | wc -l)
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
echo "Secrets commands tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
