#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for tuning scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

TUNING_DIR="$REPO_ROOT/scripts/tuning"

# Test: tuning directory exists
test_start "tuning_dir_exists"
assert_dir_exists "$TUNING_DIR" "tuning directory should exist"

# Test: linux.sh exists
test_start "tuning_linux_exists"
if [[ -f "$TUNING_DIR/linux.sh" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: linux.sh exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: linux.sh should exist"
fi

# Test: linux.sh valid syntax
test_start "tuning_linux_syntax"
if [[ -f "$TUNING_DIR/linux.sh" ]] && bash -n "$TUNING_DIR/linux.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: linux.sh valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: linux.sh syntax errors"
fi

# Test: macos.sh exists
test_start "tuning_macos_exists"
if [[ -f "$TUNING_DIR/macos.sh" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: macos.sh exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: macos.sh should exist"
fi

# Test: macos.sh valid syntax
test_start "tuning_macos_syntax"
if [[ -f "$TUNING_DIR/macos.sh" ]] && bash -n "$TUNING_DIR/macos.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: macos.sh valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: macos.sh syntax errors"
fi

# Test: linux.sh requires sudo for system changes
test_start "tuning_linux_sudo"
if [[ -f "$TUNING_DIR/linux.sh" ]] && grep -qE 'sudo|EUID|root' "$TUNING_DIR/linux.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks for root/sudo"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should check for root"
fi

# Test: macos uses defaults command
test_start "tuning_macos_defaults"
if [[ -f "$TUNING_DIR/macos.sh" ]] && grep -q 'defaults' "$TUNING_DIR/macos.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses defaults command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use defaults command"
fi

echo ""
echo "Tuning scripts tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
