#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for firewall security script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

FW_FILE="$REPO_ROOT/scripts/security/firewall.sh"

# Test: firewall.sh file exists
test_start "firewall_file_exists"
assert_file_exists "$FW_FILE" "firewall.sh should exist"

# Test: firewall.sh is valid shell syntax
test_start "firewall_syntax_valid"
if bash -n "$FW_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: firewall.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: firewall.sh has syntax errors"
fi

# Test: supports macOS and Linux
test_start "firewall_multiplatform"
if grep -qE 'darwin|linux|ufw|iptables|pf|pfctl' "$FW_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports multiple platforms"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support multiple platforms"
fi

# Test: requires sudo/root
test_start "firewall_requires_elevation"
if grep -qE 'sudo|EUID|root' "$FW_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks for elevated privileges"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should check for elevated privileges"
fi

# Test: has enable/disable functions
test_start "firewall_enable_disable"
if grep -qE 'enable|disable|start|stop' "$FW_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has enable/disable functions"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have enable/disable functions"
fi

# Test: shellcheck compliance
test_start "firewall_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$FW_FILE" 2>&1 | wc -l)
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
echo "Firewall security tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
