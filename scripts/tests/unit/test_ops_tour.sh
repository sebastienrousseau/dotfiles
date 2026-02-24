#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for tour.sh - interactive tour of dotfiles capabilities
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ops/tour.sh"

echo "Testing tour.sh..."

# Test: file exists
test_start "tour_exists"
assert_file_exists "$SCRIPT_FILE" "tour.sh should exist"

# Test: valid shell syntax
test_start "tour_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

# Test: has shebang
test_start "tour_shebang"
first_line=$(head -n 1 "$SCRIPT_FILE")
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash"
fi

# Test: uses set -euo pipefail
test_start "tour_strict_mode"
assert_file_contains "$SCRIPT_FILE" "set -euo pipefail" "should use strict mode"

# Test: sources ui library
test_start "tour_ui_lib"
assert_file_contains "$SCRIPT_FILE" "source.*ui.sh" "should source ui library"

# Test: defines PAGES array
test_start "tour_pages_array"
assert_file_contains "$SCRIPT_FILE" "PAGES=" "should define PAGES array"

# Test: tracks current page
test_start "tour_current_page"
assert_file_contains "$SCRIPT_FILE" "CURRENT_PAGE" "should track current page"

# Test: tracks total pages
test_start "tour_total_pages"
assert_file_contains "$SCRIPT_FILE" "TOTAL_PAGES" "should track total pages"

# Test: defines welcome page
test_start "tour_welcome_page"
assert_file_contains "$SCRIPT_FILE" "page_welcome()" "should define welcome page"

# Test: defines navigation page
test_start "tour_navigation_page"
assert_file_contains "$SCRIPT_FILE" "page_navigation()" "should define navigation page"

# Test: defines editing page
test_start "tour_editing_page"
assert_file_contains "$SCRIPT_FILE" "page_editing()" "should define editing page"

# Test: defines git page
test_start "tour_git_page"
assert_file_contains "$SCRIPT_FILE" "page_git()" "should define git page"

# Test: defines tools page
test_start "tour_tools_page"
assert_file_contains "$SCRIPT_FILE" "page_tools()" "should define tools page"

# Test: defines customization page
test_start "tour_customization_page"
assert_file_contains "$SCRIPT_FILE" "page_customization()" "should define customization page"

# Test: defines AI page
test_start "tour_ai_page"
assert_file_contains "$SCRIPT_FILE" "page_ai()" "should define AI page"

# Test: defines tips page
test_start "tour_tips_page"
assert_file_contains "$SCRIPT_FILE" "page_tips()" "should define tips page"

# Test: defines complete page
test_start "tour_complete_page"
assert_file_contains "$SCRIPT_FILE" "page_complete()" "should define complete page"

# Test: defines press_continue function
test_start "tour_press_continue"
assert_file_contains "$SCRIPT_FILE" "press_continue()" "should define press_continue function"

# Test: defines show_page_header function
test_start "tour_show_page_header"
assert_file_contains "$SCRIPT_FILE" "show_page_header()" "should define show_page_header function"

# Test: defines show_command function
test_start "tour_show_command"
assert_file_contains "$SCRIPT_FILE" "show_command()" "should define show_command function"

# Test: defines show_key function
test_start "tour_show_key"
assert_file_contains "$SCRIPT_FILE" "show_key()" "should define show_key function"

# Test: uses gum for TUI
test_start "tour_gum"
assert_file_contains "$SCRIPT_FILE" "gum" "should use gum for TUI"

# Test: mentions zoxide
test_start "tour_zoxide"
assert_file_contains "$SCRIPT_FILE" "zoxide" "should mention zoxide"

# Test: mentions fzf
test_start "tour_fzf"
assert_file_contains "$SCRIPT_FILE" "fzf" "should mention fzf"

# Test: mentions neovim
test_start "tour_neovim"
if grep -qi "nvim\|neovim" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: mentions Neovim"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should mention Neovim"
fi

# Test: defines main function
test_start "tour_main"
assert_file_contains "$SCRIPT_FILE" "main()" "should define main function"

echo ""
echo "tour.sh tests completed."
print_summary
