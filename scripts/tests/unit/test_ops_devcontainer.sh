#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for devcontainer.sh - dev container configuration generator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ops/devcontainer.sh"

echo "Testing devcontainer.sh..."

# Test: file exists
test_start "devcontainer_exists"
assert_file_exists "$SCRIPT_FILE" "devcontainer.sh should exist"

# Test: valid shell syntax
test_start "devcontainer_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

# Test: has shebang
test_start "devcontainer_shebang"
first_line=$(head -n 1 "$SCRIPT_FILE")
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash"
fi

# Test: uses set -euo pipefail
test_start "devcontainer_strict_mode"
assert_file_contains "$SCRIPT_FILE" "set -euo pipefail" "should use strict mode"

# Test: sources ui library
test_start "devcontainer_ui_lib"
assert_file_contains "$SCRIPT_FILE" "ui.sh" "should source ui library"

# Test: supports init mode
test_start "devcontainer_init"
if grep -q -- '--init' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports --init mode"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support --init mode"
fi

# Test: supports codespaces mode
test_start "devcontainer_codespaces"
if grep -q -- '--codespaces' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports --codespaces mode"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support --codespaces mode"
fi

# Test: supports gitpod mode
test_start "devcontainer_gitpod"
if grep -q -- '--gitpod' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports --gitpod mode"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support --gitpod mode"
fi

# Test: defines show_help function
test_start "devcontainer_show_help"
assert_file_contains "$SCRIPT_FILE" "show_help()" "should define show_help function"

# Test: has help option
test_start "devcontainer_help_option"
if grep -q -- '--help' "$SCRIPT_FILE" || grep -q -- '-h' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has help option"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have help option"
fi

# Test: supports custom image
test_start "devcontainer_custom_image"
if grep -q -- '--image' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports custom image"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support custom image"
fi

# Test: supports custom repo
test_start "devcontainer_custom_repo"
if grep -q -- '--repo' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports custom repo"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support custom repo"
fi

# Test: defines default image
test_start "devcontainer_default_image"
assert_file_contains "$SCRIPT_FILE" "IMAGE=" "should define default image"

# Test: defines dotfiles repo
test_start "devcontainer_dotfiles_repo"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_REPO=" "should define dotfiles repo"

# Test: defines output directory
test_start "devcontainer_output_dir"
assert_file_contains "$SCRIPT_FILE" "OUTPUT_DIR=" "should define output directory"

# Test: uses devcontainer path
test_start "devcontainer_path"
assert_file_contains "$SCRIPT_FILE" ".devcontainer" "should use .devcontainer path"

# Test: defines mode variable
test_start "devcontainer_mode"
assert_file_contains "$SCRIPT_FILE" "MODE=" "should define mode variable"

# Test: uses ui_init
test_start "devcontainer_ui_init"
assert_file_contains "$SCRIPT_FILE" "ui_init" "should initialize ui"

echo ""
echo "devcontainer.sh tests completed."
print_summary
