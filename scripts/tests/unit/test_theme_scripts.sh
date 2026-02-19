#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for theme scripts

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

THEME_DIR="$REPO_ROOT/scripts/theme"

# Test: theme directory exists
test_start "theme_dir_exists"
assert_dir_exists "$THEME_DIR" "theme directory should exist"

# Test: switch.sh exists and valid
test_start "theme_switch_exists"
if [[ -f "$THEME_DIR/switch.sh" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: switch.sh exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: switch.sh should exist"
fi

test_start "theme_switch_syntax"
if [[ -f "$THEME_DIR/switch.sh" ]] && bash -n "$THEME_DIR/switch.sh" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: switch.sh valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: switch.sh syntax errors"
fi

# Test: wallpaper scripts exist
test_start "theme_wallpaper_exists"
wallpaper_count=$(find "$THEME_DIR" -name "wallpaper*.sh" 2>/dev/null | wc -l)
if [[ "$wallpaper_count" -gt 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: wallpaper scripts exist ($wallpaper_count)"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: wallpaper scripts should exist"
fi

# Test: install-catppuccin-themes.sh exists
test_start "theme_catppuccin_exists"
if [[ -f "$THEME_DIR/install-catppuccin-themes.sh" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: catppuccin theme script exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: catppuccin script should exist"
fi

# Test: all theme scripts have valid syntax
test_start "theme_all_valid_syntax"
invalid=0
for script in "$THEME_DIR"/*.sh; do
  if [[ -f "$script" ]] && ! bash -n "$script" 2>/dev/null; then
    ((invalid++))
    echo "    Invalid: $(basename "$script")"
  fi
done
if [[ "$invalid" -eq 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: all theme scripts valid"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: $invalid scripts have errors"
fi

# Test: no hardcoded paths
test_start "theme_no_hardcoded_paths"
if grep -rqE '"/home/[a-z]+' "$THEME_DIR"/*.sh 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: has hardcoded paths"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

echo ""
echo "Theme scripts tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
