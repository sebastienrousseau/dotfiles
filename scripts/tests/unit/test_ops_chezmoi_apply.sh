#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for chezmoi-apply.sh - dotfiles apply wrapper
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ops/chezmoi-apply.sh"

echo "Testing chezmoi-apply.sh..."

# Test: file exists
test_start "chezmoi_apply_exists"
assert_file_exists "$SCRIPT_FILE" "chezmoi-apply.sh should exist"

# Test: valid shell syntax
test_start "chezmoi_apply_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

# Test: has shebang
test_start "chezmoi_apply_shebang"
first_line=$(head -n 1 "$SCRIPT_FILE")
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash"
fi

# Test: uses set -euo pipefail
test_start "chezmoi_apply_strict_mode"
assert_file_contains "$SCRIPT_FILE" "set -euo pipefail" "should use strict mode"

# Test: sources ui library
test_start "chezmoi_apply_ui_lib"
assert_file_contains "$SCRIPT_FILE" "ui.sh" "should source ui library"

# Test: calls ui_init
test_start "chezmoi_apply_ui_init"
assert_file_contains "$SCRIPT_FILE" "ui_init" "should initialize ui"

# Test: uses chezmoi apply command
test_start "chezmoi_apply_uses_chezmoi"
assert_file_contains "$SCRIPT_FILE" "chezmoi apply" "should call chezmoi apply"

# Test: handles DOTFILES_CHEZMOI_APPLY_FLAGS
test_start "chezmoi_apply_custom_flags"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_CHEZMOI_APPLY_FLAGS" "should support custom flags env var"

# Test: handles verbose mode
test_start "chezmoi_apply_verbose"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_CHEZMOI_VERBOSE" "should support verbose mode"

# Test: handles keep-going mode
test_start "chezmoi_apply_keep_going"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_CHEZMOI_KEEP_GOING" "should support keep-going mode"

# Test: handles non-interactive mode
test_start "chezmoi_apply_noninteractive"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_NONINTERACTIVE" "should support non-interactive mode"

# Test: defines run_step function
test_start "chezmoi_apply_run_step"
assert_file_contains "$SCRIPT_FILE" "run_step()" "should define run_step function"

# Test: uses gum spinner
test_start "chezmoi_apply_gum_spinner"
assert_file_contains "$SCRIPT_FILE" "gum spin" "should use gum spinner for feedback"

# Test: calls ui_header
test_start "chezmoi_apply_header"
assert_file_contains "$SCRIPT_FILE" "ui_header" "should display header"

# Test: supports alias governance
test_start "chezmoi_apply_governance"
assert_file_contains "$SCRIPT_FILE" "alias-governance" "should support alias governance"

# Test: supports snapshot on apply
test_start "chezmoi_apply_snapshot"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_SNAPSHOT_ON_APPLY" "should support snapshot on apply"

# Test: checks AI CLI tools
test_start "chezmoi_apply_ai_checks"
if grep -q "claude" "$SCRIPT_FILE" && grep -q "gemini" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: checks AI CLI tools"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should check AI CLI tools"
fi

# Test: shows chezmoi status
test_start "chezmoi_apply_status"
assert_file_contains "$SCRIPT_FILE" "chezmoi status" "should show chezmoi status"

# Test: runs post-apply repair
test_start "chezmoi_apply_post_repair"
assert_file_contains "$SCRIPT_FILE" "post-apply-repair" "should run post-apply repair"

# Test: shows shell reload info
test_start "chezmoi_apply_reload_info"
assert_file_contains "$SCRIPT_FILE" "exec zsh" "should show shell reload instructions"

# Test: has_flag function defined
test_start "chezmoi_apply_has_flag"
assert_file_contains "$SCRIPT_FILE" "has_flag()" "should define has_flag function"

# Test: check_ai_cli function defined
test_start "chezmoi_apply_check_ai_cli"
assert_file_contains "$SCRIPT_FILE" "check_ai_cli()" "should define check_ai_cli function"

# Test: supports DOTFILES_CHEZMOI_STATUS
test_start "chezmoi_apply_status_flag"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_CHEZMOI_STATUS" "should support status display flag"

# Test: supports DOTFILES_POST_APPLY_REPAIR
test_start "chezmoi_apply_repair_flag"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_POST_APPLY_REPAIR" "should support post-apply repair flag"

echo ""
echo "chezmoi-apply.sh tests completed."
print_summary
