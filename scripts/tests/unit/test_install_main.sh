#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for main install.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

INSTALL_FILE="$REPO_ROOT/install.sh"

# Test: install.sh file exists
test_start "install_file_exists"
assert_file_exists "$INSTALL_FILE" "install.sh should exist"

# Test: install.sh is valid shell syntax
test_start "install_syntax_valid"
if bash -n "$INSTALL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: install.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: install.sh has syntax errors"
fi

# Test: is executable
test_start "install_is_executable"
if [[ -x "$INSTALL_FILE" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: install.sh is executable"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: install.sh should be executable"
fi

# Test: has shebang
test_start "install_has_shebang"
if head -1 "$INSTALL_FILE" | grep -qE '^#!.*(bash|sh)'; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have proper shebang"
fi

# Test: supports non-interactive mode
test_start "install_noninteractive"
if grep -qE 'NONINTERACTIVE|noninteractive|--yes|-y' "$INSTALL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports non-interactive mode"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support non-interactive mode"
fi

# Test: detects OS
test_start "install_detects_os"
if grep -qE 'uname|OSTYPE|darwin|linux|Darwin|Linux' "$INSTALL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: detects OS"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should detect OS"
fi

# Test: installs chezmoi
test_start "install_uses_chezmoi"
if grep -q 'chezmoi' "$INSTALL_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses chezmoi"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use chezmoi"
fi

# Test: no hardcoded user paths
test_start "install_no_hardcoded_user"
if grep -qE '"/home/[a-z]+' "$INSTALL_FILE" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: has hardcoded user paths"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded user paths"
fi

# Test: shellcheck compliance
test_start "install_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$INSTALL_FILE" 2>&1 | wc -l)
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
echo "Main install tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
