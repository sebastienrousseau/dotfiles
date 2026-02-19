#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for fonts scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

FONTS_DIR="$REPO_ROOT/scripts/fonts"

# Test: fonts directory exists
test_start "fonts_dir_exists"
assert_dir_exists "$FONTS_DIR" "fonts directory should exist"

# Test: install-nerd-fonts.sh exists
test_start "fonts_nerd_install_exists"
if [[ -f "$FONTS_DIR/install-nerd-fonts.sh" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: install-nerd-fonts.sh exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: install-nerd-fonts.sh should exist"
fi

# Test: install-nerd-fonts.sh valid syntax
test_start "fonts_nerd_install_syntax"
if [[ -f "$FONTS_DIR/install-nerd-fonts.sh" ]] && bash -n "$FONTS_DIR/install-nerd-fonts.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

# Test: uses official nerd fonts source
test_start "fonts_official_source"
if [[ -f "$FONTS_DIR/install-nerd-fonts.sh" ]] && grep -qE 'nerd-fonts|ryanoasis' "$FONTS_DIR/install-nerd-fonts.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses official nerd fonts source"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use official source"
fi

# Test: supports multiple platforms
test_start "fonts_multiplatform"
if [[ -f "$FONTS_DIR/install-nerd-fonts.sh" ]] && grep -qE 'darwin|linux|macos|Linux' "$FONTS_DIR/install-nerd-fonts.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports multiple platforms"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support multiple platforms"
fi

# Test: installs to proper directory
test_start "fonts_proper_directory"
if [[ -f "$FONTS_DIR/install-nerd-fonts.sh" ]] && grep -qE 'fonts|\.local/share/fonts|Library/Fonts' "$FONTS_DIR/install-nerd-fonts.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: installs to proper font directory"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use proper font directory"
fi

echo ""
echo "Fonts scripts tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
