#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for health-check.sh - comprehensive dotfiles health verification
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ops/health-check.sh"

echo "Testing health-check.sh..."

# Test: file exists
test_start "health_check_exists"
assert_file_exists "$SCRIPT_FILE" "health-check.sh should exist"

# Test: valid shell syntax
test_start "health_check_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

# Test: has shebang
test_start "health_check_shebang"
first_line=$(head -n 1 "$SCRIPT_FILE")
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash"
fi

# Test: uses set -euo pipefail
test_start "health_check_strict_mode"
assert_file_contains "$SCRIPT_FILE" "set -euo pipefail" "should use strict mode"

# Test: supports verbose mode
test_start "health_check_verbose"
if grep -q -- '--verbose' "$SCRIPT_FILE" || grep -q -- '-v' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports verbose mode"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support verbose mode"
fi

# Test: supports JSON output
test_start "health_check_json"
if grep -q -- '--json' "$SCRIPT_FILE" || grep -q "JSON_OUTPUT" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports JSON output"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support JSON output"
fi

# Test: checks chezmoi installation
test_start "health_check_chezmoi"
assert_file_contains "$SCRIPT_FILE" "chezmoi" "should check chezmoi"

# Test: checks dotfiles source
test_start "health_check_dotfiles_source"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_SOURCE" "should check dotfiles source"

# Test: checks critical files
test_start "health_check_critical_files"
if grep -q ".zshrc" "$SCRIPT_FILE" || grep -q ".bashrc" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks critical files"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should check critical files"
fi

# Test: defines log functions
test_start "health_check_log_functions"
if grep -q "log_pass()" "$SCRIPT_FILE" && grep -q "log_fail()" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines log functions"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define log functions"
fi

# Test: defines log_warn function
test_start "health_check_log_warn"
assert_file_contains "$SCRIPT_FILE" "log_warn()" "should define log_warn function"

# Test: adds results for JSON
test_start "health_check_add_result"
assert_file_contains "$SCRIPT_FILE" "add_result()" "should define add_result function"

# Test: has help option
test_start "health_check_help"
if grep -q -- '--help' "$SCRIPT_FILE" || grep -q -- '-h' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has help option"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have help option"
fi

# Test: uses XDG config home
test_start "health_check_xdg"
assert_file_contains "$SCRIPT_FILE" "XDG_CONFIG_HOME" "should use XDG config home"

# Test: defines chezmoi config dir
test_start "health_check_chezmoi_config"
assert_file_contains "$SCRIPT_FILE" "CHEZMOI_CONFIG_DIR" "should define chezmoi config directory"

# Test: respects NO_COLOR
test_start "health_check_no_color"
assert_file_contains "$SCRIPT_FILE" "NO_COLOR" "should respect NO_COLOR"

# Test: defines color variables
test_start "health_check_colors"
if grep -q "RED=" "$SCRIPT_FILE" && grep -q "GREEN=" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines color variables"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define color variables"
fi

# Test: tracks exit code
test_start "health_check_exit_code"
assert_file_contains "$SCRIPT_FILE" "EXIT_CODE" "should track exit code"

# Test: has documentation header
test_start "health_check_documentation"
if grep -q "^##" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has documentation header"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have documentation header"
fi

echo ""
echo "health-check.sh tests completed."
print_summary
