#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for install/lib/chezmoi.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

CHEZMOI_LIB="$REPO_ROOT/install/lib/chezmoi.sh"

# Test: chezmoi.sh file exists
test_start "chezmoi_lib_exists"
assert_file_exists "$CHEZMOI_LIB" "chezmoi.sh should exist"

# Test: chezmoi.sh is valid shell syntax
test_start "chezmoi_lib_syntax"
if bash -n "$CHEZMOI_LIB" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: valid shell syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

# Test: defines install function
test_start "chezmoi_lib_install_func"
if grep -qE 'install_chezmoi|chezmoi_install' "$CHEZMOI_LIB" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines install function"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define install function"
fi

# Test: uses official install method
test_start "chezmoi_lib_official_install"
if grep -qE 'get.chezmoi.io|chezmoi/chezmoi' "$CHEZMOI_LIB" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses official install method"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use official install"
fi

# Test: checks for existing installation
test_start "chezmoi_lib_checks_existing"
if grep -qE 'command -v chezmoi|which chezmoi' "$CHEZMOI_LIB" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks for existing installation"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should check existing install"
fi

# Test: shellcheck compliance
test_start "chezmoi_lib_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$CHEZMOI_LIB" 2>&1 | wc -l)
  if [[ "$errors" -eq 0 ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: passes shellcheck"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: has shellcheck errors"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shellcheck not available"
fi

echo ""
echo "Chezmoi library tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
