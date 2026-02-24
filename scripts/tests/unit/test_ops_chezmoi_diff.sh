#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for chezmoi-diff.sh - dotfiles diff wrapper
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ops/chezmoi-diff.sh"

echo "Testing chezmoi-diff.sh..."

# Test: file exists
test_start "chezmoi_diff_exists"
assert_file_exists "$SCRIPT_FILE" "chezmoi-diff.sh should exist"

# Test: valid shell syntax
test_start "chezmoi_diff_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

# Test: has shebang
test_start "chezmoi_diff_shebang"
first_line=$(head -n 1 "$SCRIPT_FILE")
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash"
fi

# Test: uses set -euo pipefail
test_start "chezmoi_diff_strict_mode"
assert_file_contains "$SCRIPT_FILE" "set -euo pipefail" "should use strict mode"

# Test: uses chezmoi diff command
test_start "chezmoi_diff_uses_chezmoi"
assert_file_contains "$SCRIPT_FILE" "chezmoi diff" "should call chezmoi diff"

# Test: has default excludes
test_start "chezmoi_diff_default_excludes"
assert_file_contains "$SCRIPT_FILE" "excludes=" "should define default excludes"

# Test: supports custom excludes
test_start "chezmoi_diff_custom_excludes"
assert_file_contains "$SCRIPT_FILE" "DOTFILES_CHEZMOI_DIFF_EXCLUDES" "should support custom excludes env var"

# Test: passes arguments through
test_start "chezmoi_diff_pass_args"
if grep -q '"\$@"' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: passes through arguments"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should pass through arguments"
fi

# Test: uses --exclude flag
test_start "chezmoi_diff_exclude_flag"
if grep -q -- '--exclude' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: uses --exclude flag"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should use --exclude flag"
fi

# Test: excludes scripts by default
test_start "chezmoi_diff_excludes_scripts"
assert_file_contains "$SCRIPT_FILE" "scripts" "should exclude scripts by default"

# Test: uses IFS for parsing
test_start "chezmoi_diff_ifs_parsing"
assert_file_contains "$SCRIPT_FILE" "IFS=" "should use IFS for parsing excludes"

# Test: iterates over excludes
test_start "chezmoi_diff_iterate_excludes"
assert_file_contains "$SCRIPT_FILE" 'for ex in' "should iterate over excludes"

echo ""
echo "chezmoi-diff.sh tests completed."
print_summary
