#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for chezmoi-update.sh - dotfiles update wrapper
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ops/chezmoi-update.sh"

echo "Testing chezmoi-update.sh..."

# Test: file exists
test_start "chezmoi_update_exists"
assert_file_exists "$SCRIPT_FILE" "chezmoi-update.sh should exist"

# Test: valid shell syntax
test_start "chezmoi_update_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

# Test: has shebang
test_start "chezmoi_update_shebang"
first_line=$(head -n 1 "$SCRIPT_FILE")
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash"
fi

# Test: uses set -euo pipefail
test_start "chezmoi_update_strict_mode"
assert_file_contains "$SCRIPT_FILE" "set -euo pipefail" "should use strict mode"

# Test: uses chezmoi update command
test_start "chezmoi_update_uses_chezmoi"
assert_file_contains "$SCRIPT_FILE" "chezmoi update" "should call chezmoi update"

# Test: supports custom flags
test_start "chezmoi_update_custom_flags"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_CHEZMOI_UPDATE_FLAGS" "should support custom flags env var"

# Test: supports verbose mode
test_start "chezmoi_update_verbose"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_CHEZMOI_VERBOSE" "should support verbose mode"

# Test: supports async mode
test_start "chezmoi_update_async"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_ASYNC_UPDATE" "should support async update env var"

# Test: supports --async flag
test_start "chezmoi_update_async_flag"
if grep -q -- '--async' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports --async flag"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support --async flag"
fi

# Test: creates state directory
test_start "chezmoi_update_state_dir"
assert_file_contains "$SCRIPT_FILE" "STATE_DIR=" "should define state directory"

# Test: logs output
test_start "chezmoi_update_log_file"
assert_file_contains "$SCRIPT_FILE" "LOG_FILE=" "should define log file"

# Test: tracks status
test_start "chezmoi_update_status_file"
assert_file_contains "$SCRIPT_FILE" "STATUS_FILE=" "should define status file"

# Test: supports notice file
test_start "chezmoi_update_notice_file"
assert_file_contains "$SCRIPT_FILE" "NOTICE_FILE=" "should define notice file"

# Test: defines run_update function
test_start "chezmoi_update_run_function"
assert_file_contains "$SCRIPT_FILE" "run_update()" "should define run_update function"

# Test: uses disown for background
test_start "chezmoi_update_disown"
assert_file_contains "$SCRIPT_FILE" "disown" "should use disown for background process"

# Test: writes timestamp for async
test_start "chezmoi_update_timestamp"
assert_file_contains "$SCRIPT_FILE" "date -u" "should write timestamp for async updates"

# Test: uses XDG state home
test_start "chezmoi_update_xdg"
assert_file_contains "$SCRIPT_FILE" "XDG_STATE_HOME" "should use XDG state home"

# Test: creates state directory
test_start "chezmoi_update_mkdir"
assert_file_contains "$SCRIPT_FILE" "mkdir -p" "should create state directory"

# Test: writes status code
test_start "chezmoi_update_status_code"
if grep -q 'echo \$?' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: writes status code"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should write status code"
fi

echo ""
echo "chezmoi-update.sh tests completed."
print_summary
