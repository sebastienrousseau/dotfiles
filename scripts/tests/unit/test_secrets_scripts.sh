#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for secrets scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SECRETS_DIR="$REPO_ROOT/scripts/secrets"

# Test: secrets directory exists
test_start "secrets_dir_exists"
assert_dir_exists "$SECRETS_DIR" "secrets directory should exist"

# Test: age-init.sh exists and valid
test_start "secrets_age_init_exists"
if [[ -f "$SECRETS_DIR/age-init.sh" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: age-init.sh exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: age-init.sh should exist"
fi

test_start "secrets_age_init_syntax"
if [[ -f "$SECRETS_DIR/age-init.sh" ]] && bash -n "$SECRETS_DIR/age-init.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

# Test: create-secrets-file.sh exists
test_start "secrets_create_exists"
if [[ -f "$SECRETS_DIR/create-secrets-file.sh" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: create-secrets-file.sh exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: create-secrets-file.sh should exist"
fi

# Test: encrypt-ssh-key.sh exists
test_start "secrets_encrypt_ssh_exists"
if [[ -f "$SECRETS_DIR/encrypt-ssh-key.sh" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: encrypt-ssh-key.sh exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: encrypt-ssh-key.sh should exist"
fi

# Test: uses age encryption
test_start "secrets_uses_age"
if grep -rqE 'age|\.age' "$SECRETS_DIR"/*.sh 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses age encryption"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use age encryption"
fi

# Test: uses secure permissions
test_start "secrets_secure_perms"
if grep -rqE 'chmod [0-7]*00|chmod 600|chmod 700' "$SECRETS_DIR"/*.sh 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses secure permissions"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use secure permissions"
fi

# Test: all scripts have valid syntax
test_start "secrets_all_valid_syntax"
invalid=0
for script in "$SECRETS_DIR"/*.sh; do
  if [[ -f "$script" ]] && ! bash -n "$script" 2>/dev/null; then
    ((invalid++))
  fi
done
if [[ "$invalid" -eq 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: all scripts valid"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: $invalid scripts invalid"
fi

echo ""
echo "Secrets scripts tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
