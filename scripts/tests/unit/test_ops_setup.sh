#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for setup.sh - interactive setup wizard
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ops/setup.sh"

echo "Testing setup.sh..."

# Test: file exists
test_start "setup_exists"
assert_file_exists "$SCRIPT_FILE" "setup.sh should exist"

# Test: valid shell syntax
test_start "setup_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

# Test: has shebang
test_start "setup_shebang"
first_line=$(head -n 1 "$SCRIPT_FILE")
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash"
fi

# Test: uses set -euo pipefail
test_start "setup_strict_mode"
assert_file_contains "$SCRIPT_FILE" "set -euo pipefail" "should use strict mode"

# Test: sources ui library
test_start "setup_ui_lib"
assert_file_contains "$SCRIPT_FILE" "ui.sh" "should source ui library"

# Test: supports quick mode
test_start "setup_quick_mode"
if grep -q -- '--quick' "$SCRIPT_FILE" || grep -q "QUICK_MODE" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports quick mode"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support quick mode"
fi

# Test: defines choose function
test_start "setup_choose_function"
assert_file_contains "$SCRIPT_FILE" "choose()" "should define choose function"

# Test: defines confirm function
test_start "setup_confirm_function"
assert_file_contains "$SCRIPT_FILE" "confirm()" "should define confirm function"

# Test: defines input function
test_start "setup_input_function"
assert_file_contains "$SCRIPT_FILE" "input()" "should define input function"

# Test: defines spin function
test_start "setup_spin_function"
assert_file_contains "$SCRIPT_FILE" "spin()" "should define spin function"

# Test: uses gum when available
test_start "setup_gum_integration"
assert_file_contains "$SCRIPT_FILE" "gum" "should use gum when available"

# Test: falls back without gum
test_start "setup_fallback"
if grep -q "command -v gum" "$SCRIPT_FILE" && grep -q "else" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: falls back without gum"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should fall back without gum"
fi

# Test: configures chezmoi
test_start "setup_chezmoi_config"
assert_file_contains "$SCRIPT_FILE" "chezmoi.toml" "should configure chezmoi"

# Test: uses XDG config home
test_start "setup_xdg"
assert_file_contains "$SCRIPT_FILE" "XDG_CONFIG_HOME" "should use XDG config home"

# Test: tracks setup steps
test_start "setup_steps"
if grep -q "CURRENT_STEP" "$SCRIPT_FILE" && grep -q "TOTAL_STEPS" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: tracks setup steps"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should track setup steps"
fi

# Test: defines config directory
test_start "setup_config_dir"
assert_file_contains "$SCRIPT_FILE" "CONFIG_DIR=" "should define config directory"

# Test: creates config directory
test_start "setup_mkdir"
assert_file_contains "$SCRIPT_FILE" "mkdir -p" "should create config directory"

# Test: uses ui_init
test_start "setup_ui_init"
assert_file_contains "$SCRIPT_FILE" "ui_init" "should initialize ui"

# Test: defines progress bar
test_start "setup_progress_bar"
assert_file_contains "$SCRIPT_FILE" "progress_bar" "should define progress bar"

echo ""
echo "setup.sh tests completed."
print_summary
