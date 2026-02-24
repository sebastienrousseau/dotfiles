#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for errors.sh - CLI error handling library
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/lib/errors.sh"

echo "Testing dot/lib/errors.sh..."

# Test: file exists
test_start "errors_lib_exists"
assert_file_exists "$SCRIPT_FILE" "errors.sh should exist"

# Test: valid shell syntax
test_start "errors_lib_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

# Test: has documentation header
test_start "errors_lib_documentation"
if grep -q "^##" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has documentation header"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have documentation header"
fi

# Test: sources ui.sh
test_start "errors_lib_sources_ui"
assert_file_contains "$SCRIPT_FILE" "ui.sh" "should source ui.sh"

# Test: defines err function
test_start "errors_lib_err_function"
assert_file_contains "$SCRIPT_FILE" "err()" "should define err function"

# Test: defines die function
test_start "errors_lib_die_function"
assert_file_contains "$SCRIPT_FILE" "die()" "should define die function"

# Test: defines err_missing_command function
test_start "errors_lib_missing_command"
assert_file_contains "$SCRIPT_FILE" "err_missing_command()" "should define err_missing_command function"

# Test: defines err_file_not_found function
test_start "errors_lib_file_not_found"
assert_file_contains "$SCRIPT_FILE" "err_file_not_found()" "should define err_file_not_found function"

# Test: defines err_permission_denied function
test_start "errors_lib_permission_denied"
assert_file_contains "$SCRIPT_FILE" "err_permission_denied()" "should define err_permission_denied function"

# Test: defines err_config function
test_start "errors_lib_config"
assert_file_contains "$SCRIPT_FILE" "err_config()" "should define err_config function"

# Test: defines err_network function
test_start "errors_lib_network"
assert_file_contains "$SCRIPT_FILE" "err_network()" "should define err_network function"

# Test: defines err_git function
test_start "errors_lib_git"
assert_file_contains "$SCRIPT_FILE" "err_git()" "should define err_git function"

# Test: defines err_dependency function
test_start "errors_lib_dependency"
assert_file_contains "$SCRIPT_FILE" "err_dependency()" "should define err_dependency function"

# Test: defines err_invalid_arg function
test_start "errors_lib_invalid_arg"
assert_file_contains "$SCRIPT_FILE" "err_invalid_arg()" "should define err_invalid_arg function"

# Test: defines warn function
test_start "errors_lib_warn"
assert_file_contains "$SCRIPT_FILE" "warn()" "should define warn function"

# Test: defines warn_deprecated function
test_start "errors_lib_warn_deprecated"
assert_file_contains "$SCRIPT_FILE" "warn_deprecated()" "should define warn_deprecated function"

# Test: defines print_debug_info function
test_start "errors_lib_debug_info"
assert_file_contains "$SCRIPT_FILE" "print_debug_info()" "should define print_debug_info function"

# Test: defines suggest_doctor function
test_start "errors_lib_suggest_doctor"
assert_file_contains "$SCRIPT_FILE" "suggest_doctor()" "should define suggest_doctor function"

# Test: has install hints for common commands
test_start "errors_lib_install_hints"
hints_found=0
for cmd in "nvim" "chezmoi" "gum" "starship" "fzf"; do
  if grep -q "$cmd)" "$SCRIPT_FILE"; then
    ((hints_found++)) || true
  fi
done
if [[ $hints_found -ge 4 ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has install hints for common commands"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have install hints for common commands"
fi

# Test: handles git operations
test_start "errors_lib_git_operations"
ops_found=0
for op in "push" "pull" "clone" "commit"; do
  if grep -q "$op)" "$SCRIPT_FILE"; then
    ((ops_found++)) || true
  fi
done
if [[ $ops_found -ge 4 ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: handles git operations"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should handle git operations"
fi

# Test: provides suggestions
test_start "errors_lib_suggestions"
assert_file_contains "$SCRIPT_FILE" "Suggestion:" "should provide suggestions"

# Test: uses ui_err
test_start "errors_lib_uses_ui_err"
assert_file_contains "$SCRIPT_FILE" "ui_err" "should use ui_err"

# Test: uses ui_warn
test_start "errors_lib_uses_ui_warn"
assert_file_contains "$SCRIPT_FILE" "ui_warn" "should use ui_warn"

# Test: uses ui_section
test_start "errors_lib_uses_ui_section"
assert_file_contains "$SCRIPT_FILE" "ui_section" "should use ui_section"

# Test: uses ui_kv
test_start "errors_lib_uses_ui_kv"
assert_file_contains "$SCRIPT_FILE" "ui_kv" "should use ui_kv"

# Test: uses ui_init
test_start "errors_lib_uses_ui_init"
assert_file_contains "$SCRIPT_FILE" "ui_init" "should use ui_init"

# Test: handles color output
test_start "errors_lib_color"
assert_file_contains "$SCRIPT_FILE" "UI_COLOR" "should handle color output"

# Test: die exits with code
test_start "errors_lib_die_exit"
assert_file_contains "$SCRIPT_FILE" "exit" "die should exit with code"

# Test: print_debug_info shows system info
test_start "errors_lib_debug_system_info"
if grep -q "uname" "$SCRIPT_FILE" && grep -q "SHELL" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: print_debug_info shows system info"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show system info"
fi

# Test: shows DOTFILES_PROFILE in debug
test_start "errors_lib_debug_profile"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_PROFILE" "should show DOTFILES_PROFILE in debug"

echo ""
echo "errors.sh tests completed."
print_summary
