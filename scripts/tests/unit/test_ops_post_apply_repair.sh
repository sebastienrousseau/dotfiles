#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for post-apply-repair.sh - post-apply cleanup and validation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ops/post-apply-repair.sh"

echo "Testing post-apply-repair.sh..."

# Test: file exists
test_start "post_apply_repair_exists"
assert_file_exists "$SCRIPT_FILE" "post-apply-repair.sh should exist"

# Test: valid shell syntax
test_start "post_apply_repair_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

# Test: has shebang
test_start "post_apply_repair_shebang"
first_line=$(head -n 1 "$SCRIPT_FILE")
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash"
fi

# Test: uses set -euo pipefail
test_start "post_apply_repair_strict_mode"
assert_file_contains "$SCRIPT_FILE" "set -euo pipefail" "should use strict mode"

# Test: sources ui library
test_start "post_apply_repair_ui_lib"
assert_file_contains "$SCRIPT_FILE" "ui.sh" "should source ui library"

# Test: defines repair_zwc_cache function
test_start "post_apply_repair_zwc_cache"
assert_file_contains "$SCRIPT_FILE" "repair_zwc_cache()" "should define repair_zwc_cache function"

# Test: defines validate_dot_cli function
test_start "post_apply_repair_validate_dot_cli"
assert_file_contains "$SCRIPT_FILE" "validate_dot_cli()" "should define validate_dot_cli function"

# Test: defines resolve_zsh_bin function
test_start "post_apply_repair_resolve_zsh"
assert_file_contains "$SCRIPT_FILE" "resolve_zsh_bin()" "should define resolve_zsh_bin function"

# Test: handles .zwc files
test_start "post_apply_repair_zwc_files"
assert_file_contains "$SCRIPT_FILE" ".zwc" "should handle .zwc files"

# Test: uses find for cache files
test_start "post_apply_repair_find"
assert_file_contains "$SCRIPT_FILE" "find" "should use find for cache files"

# Test: checks dot CLI binary
test_start "post_apply_repair_dot_bin"
assert_file_contains "$SCRIPT_FILE" "dot_bin" "should check dot CLI binary"

# Test: validates dot resolution
test_start "post_apply_repair_dot_resolution"
assert_file_contains "$SCRIPT_FILE" "dot CLI resolution" "should validate dot resolution"

# Test: detects alias collision
test_start "post_apply_repair_alias_collision"
assert_file_contains "$SCRIPT_FILE" "alias collision" "should detect alias collision"

# Test: defines main function
test_start "post_apply_repair_main"
assert_file_contains "$SCRIPT_FILE" "main()" "should define main function"

# Test: uses ui_init
test_start "post_apply_repair_ui_init"
assert_file_contains "$SCRIPT_FILE" "ui_init" "should initialize ui"

# Test: uses ui_header
test_start "post_apply_repair_ui_header"
assert_file_contains "$SCRIPT_FILE" "ui_header" "should use ui_header"

# Test: uses ui_ok
test_start "post_apply_repair_ui_ok"
assert_file_contains "$SCRIPT_FILE" "ui_ok" "should use ui_ok"

# Test: uses ui_err
test_start "post_apply_repair_ui_err"
assert_file_contains "$SCRIPT_FILE" "ui_err" "should use ui_err"

# Test: uses ui_warn
test_start "post_apply_repair_ui_warn"
assert_file_contains "$SCRIPT_FILE" "ui_warn" "should use ui_warn"

# Test: supports testing mode
test_start "post_apply_repair_testing_mode"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_POST_APPLY_TESTING" "should support testing mode"

# Test: supports custom ZWC cache dirs
test_start "post_apply_repair_custom_dirs"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_ZWC_CACHE_DIRS" "should support custom cache dirs"

# Test: supports custom zsh binary
test_start "post_apply_repair_custom_zsh"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_ZSH_BIN" "should support custom zsh binary"

echo ""
echo "post-apply-repair.sh tests completed."
print_summary
