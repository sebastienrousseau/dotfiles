#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for chezmoi-remove.sh - remove file from dotfiles tracking
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ops/chezmoi-remove.sh"

echo "Testing chezmoi-remove.sh..."

# Test: file exists
test_start "chezmoi_remove_exists"
assert_file_exists "$SCRIPT_FILE" "chezmoi-remove.sh should exist"

# Test: valid shell syntax
test_start "chezmoi_remove_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

# Test: has shebang
test_start "chezmoi_remove_shebang"
first_line=$(head -n 1 "$SCRIPT_FILE")
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash"
fi

# Test: uses set -euo pipefail
test_start "chezmoi_remove_strict_mode"
assert_file_contains "$SCRIPT_FILE" "set -euo pipefail" "should use strict mode"

# Test: shows usage without arguments
test_start "chezmoi_remove_usage"
assert_file_contains "$SCRIPT_FILE" "Usage:" "should show usage"

# Test: requires path argument
test_start "chezmoi_remove_requires_path"
if grep -qE '\$# -lt 1' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: requires path argument"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should require path argument"
fi

# Test: supports --source flag
test_start "chezmoi_remove_source_flag"
if grep -q -- '--source' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports --source flag"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support --source flag"
fi

# Test: supports --dry-run flag
test_start "chezmoi_remove_dry_run"
if grep -q -- '--dry-run' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: supports --dry-run flag"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should support --dry-run flag"
fi

# Test: confirms before removal
test_start "chezmoi_remove_confirmation"
assert_file_contains "$SCRIPT_FILE" "Proceed?" "should ask for confirmation"

# Test: uses read for confirmation
test_start "chezmoi_remove_read_confirm"
assert_file_contains "$SCRIPT_FILE" "read -r" "should use read for confirmation"

# Test: supports abort
test_start "chezmoi_remove_abort"
assert_file_contains "$SCRIPT_FILE" "Aborted" "should support abort"

# Test: uses --keep-source by default
test_start "chezmoi_remove_keep_source"
if grep -q -- '--keep-source' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses --keep-source by default"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use --keep-source by default"
fi

# Test: calls chezmoi remove
test_start "chezmoi_remove_calls_chezmoi"
assert_file_contains "$SCRIPT_FILE" "chezmoi remove" "should call chezmoi remove"

# Test: shows command before execution
test_start "chezmoi_remove_shows_command"
assert_file_contains "$SCRIPT_FILE" "About to run" "should show command before execution"

# Test: handles paths array
test_start "chezmoi_remove_paths_array"
assert_file_contains "$SCRIPT_FILE" "paths=" "should handle paths array"

# Test: checks for empty paths
test_start "chezmoi_remove_empty_paths_check"
assert_file_contains "$SCRIPT_FILE" "No path provided" "should check for empty paths"

echo ""
echo "chezmoi-remove.sh tests completed."
print_summary
