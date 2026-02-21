#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034,SC2016
# Unit tests for Wave 1: Eager/Lazy alias split (90/91 templates)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

EAGER_TMPL="$REPO_ROOT/dot_config/shell/90-ux-aliases.sh.tmpl"
LAZY_TMPL="$REPO_ROOT/dot_config/shell/91-ux-aliases-lazy.sh.tmpl"

echo "Testing Wave 1: Eager/Lazy alias split..."

# --- Eager template (90) ---

test_start "eager_template_exists"
assert_file_exists "$EAGER_TMPL" "90-ux-aliases.sh.tmpl should exist"

test_start "eager_template_has_shebang"
first_line=$(head -n 1 "$EAGER_TMPL")
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash shebang"
fi

test_start "eager_template_defines_core_categories"
assert_file_contains "$EAGER_TMPL" 'coreCategories' "should define coreCategories list"

test_start "eager_template_includes_cd"
assert_file_contains "$EAGER_TMPL" '"cd"' "should include cd in core categories"

test_start "eager_template_includes_git"
assert_file_contains "$EAGER_TMPL" '"git"' "should include git in core categories"

test_start "eager_template_includes_editor"
assert_file_contains "$EAGER_TMPL" '"editor"' "should include editor in core categories"

test_start "eager_template_includes_sudo"
assert_file_contains "$EAGER_TMPL" '"sudo"' "should include sudo in core categories"

test_start "eager_template_includes_modern"
assert_file_contains "$EAGER_TMPL" '"modern"' "should include modern in core categories"

test_start "eager_template_filters_isCore"
assert_file_contains "$EAGER_TMPL" 'if and $isCore' "should filter by isCore == true"

test_start "eager_template_excludes_macOS_inline"
assert_file_contains "$EAGER_TMPL" 'not (contains "/macOS/" $name)' "should exclude macOS aliases from main loop"

test_start "eager_template_has_macos_section"
assert_file_contains "$EAGER_TMPL" 'eq .chezmoi.os "darwin"' "should have OS-specific macOS section"

test_start "eager_template_uses_glob"
assert_file_contains "$EAGER_TMPL" 'glob $globPattern' "should discover aliases via glob"

test_start "eager_template_has_bash_compat"
assert_file_contains "$EAGER_TMPL" 'expand_aliases' "should enable expand_aliases for bash compatibility"

# Count expected core categories from list definition
test_start "eager_template_has_core_categories_count"
core_line=$(grep -m 1 'coreCategories' "$EAGER_TMPL")
core_count=$(printf "%s" "$core_line" | grep -oE '"[a-z-]+"' | wc -l)
if [[ $core_count -eq 18 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has 18 core categories"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: expected 18 core categories, found $core_count"
fi

# --- Lazy template (91) ---

test_start "lazy_template_exists"
assert_file_exists "$LAZY_TMPL" "91-ux-aliases-lazy.sh.tmpl should exist"

test_start "lazy_template_has_shebang"
first_line=$(head -n 1 "$LAZY_TMPL")
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash shebang"
fi

test_start "lazy_template_defines_core_categories"
assert_file_contains "$LAZY_TMPL" 'coreCategories' "should define coreCategories for exclusion"

test_start "lazy_template_excludes_core"
assert_file_contains "$LAZY_TMPL" 'not $isCore' "should filter by NOT isCore"

test_start "lazy_template_excludes_macOS"
assert_file_contains "$LAZY_TMPL" 'not (contains "/macOS/" $name)' "should exclude macOS aliases"

test_start "lazy_template_has_bash_compat"
assert_file_contains "$LAZY_TMPL" 'expand_aliases' "should enable expand_aliases for bash compatibility"

test_start "lazy_template_uses_glob"
assert_file_contains "$LAZY_TMPL" 'glob $globPattern' "should discover aliases via glob"

# Verify both templates use the same coreCategories list
test_start "templates_share_core_categories"
eager_cats=$(grep 'coreCategories' "$EAGER_TMPL" | head -1)
lazy_cats=$(grep 'coreCategories' "$LAZY_TMPL" | head -1)
if [[ "$eager_cats" == "$lazy_cats" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: eager and lazy templates use identical coreCategories"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: coreCategories differ between templates"
  echo -e "    Eager: $eager_cats"
  echo -e "    Lazy:  $lazy_cats"
fi

# Verify both templates use the same glob pattern
test_start "templates_share_glob_pattern"
eager_glob=$(grep 'globPattern' "$EAGER_TMPL" | head -1)
lazy_glob=$(grep 'globPattern' "$LAZY_TMPL" | head -1)
if [[ "$eager_glob" == "$lazy_glob" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: eager and lazy templates use identical globPattern"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: globPattern differs between templates"
fi

echo ""
echo "Wave 1 alias split tests completed."
print_summary
