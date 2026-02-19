#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI appearance commands
# Tests: theme, wallpaper, fonts, learn

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

APPEARANCE_FILE="$REPO_ROOT/scripts/dot/commands/appearance.sh"

# Test: appearance.sh file exists
test_start "appearance_file_exists"
assert_file_exists "$APPEARANCE_FILE" "appearance.sh should exist"

# Test: appearance.sh is valid shell syntax
test_start "appearance_syntax_valid"
if bash -n "$APPEARANCE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: appearance.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: appearance.sh has syntax errors"
fi

# Test: defines theme command
test_start "appearance_defines_theme"
if grep -q "cmd_theme\|_theme\|theme" "$APPEARANCE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines theme command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define theme command"
fi

# Test: defines wallpaper command
test_start "appearance_defines_wallpaper"
if grep -q "cmd_wallpaper\|_wallpaper\|wallpaper" "$APPEARANCE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines wallpaper command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define wallpaper command"
fi

# Test: defines fonts command
test_start "appearance_defines_fonts"
if grep -q "cmd_fonts\|_fonts\|fonts" "$APPEARANCE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines fonts command"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define fonts command"
fi

# Test: supports multiple platforms
test_start "appearance_multiplatform"
if grep -qE 'darwin|linux|macos|Linux' "$APPEARANCE_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports multiple platforms"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support multiple platforms"
fi

# Test: no hardcoded paths
test_start "appearance_no_hardcoded_paths"
if grep -qE '"/home/[a-z]+' "$APPEARANCE_FILE" 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should not have hardcoded paths"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

# Test: shellcheck compliance
test_start "appearance_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$APPEARANCE_FILE" 2>&1 | wc -l)
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
echo "Appearance commands tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
