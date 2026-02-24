#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for suggest.sh - AI-powered suggestions for dotfiles optimization
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ops/suggest.sh"

echo "Testing suggest.sh..."

# Test: file exists
test_start "suggest_exists"
assert_file_exists "$SCRIPT_FILE" "suggest.sh should exist"

# Test: valid shell syntax
test_start "suggest_syntax"
assert_exit_code 0 "bash -n '$SCRIPT_FILE'"

# Test: has shebang
test_start "suggest_shebang"
first_line=$(head -n 1 "$SCRIPT_FILE")
if [[ "$first_line" == "#!/usr/bin/env bash" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: has proper shebang"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have #!/usr/bin/env bash"
fi

# Test: uses set -euo pipefail
test_start "suggest_strict_mode"
assert_file_contains "$SCRIPT_FILE" "set -euo pipefail" "should use strict mode"

# Test: sources ui library
test_start "suggest_ui_lib"
assert_file_contains "$SCRIPT_FILE" "ui.sh" "should source ui library"

# Test: sources platform library
test_start "suggest_platform_lib"
assert_file_contains "$SCRIPT_FILE" "platform.sh" "should source platform library"

# Test: defines HISTORY_FILE
test_start "suggest_history_file"
assert_file_contains "$SCRIPT_FILE" "HISTORY_FILE=" "should define history file"

# Test: defines MIN_FREQUENCY
test_start "suggest_min_frequency"
assert_file_contains "$SCRIPT_FILE" "MIN_FREQUENCY=" "should define minimum frequency"

# Test: defines MIN_LENGTH
test_start "suggest_min_length"
assert_file_contains "$SCRIPT_FILE" "MIN_LENGTH=" "should define minimum length"

# Test: defines MAX_SUGGESTIONS
test_start "suggest_max_suggestions"
assert_file_contains "$SCRIPT_FILE" "MAX_SUGGESTIONS=" "should define max suggestions"

# Test: defines analyze_history function
test_start "suggest_analyze_history"
assert_file_contains "$SCRIPT_FILE" "analyze_history()" "should define analyze_history function"

# Test: defines suggest_aliases function
test_start "suggest_aliases_function"
assert_file_contains "$SCRIPT_FILE" "suggest_aliases()" "should define suggest_aliases function"

# Test: handles zsh history format
test_start "suggest_zsh_format"
if grep -q ": \[0-9\]" "$SCRIPT_FILE" || grep -q "extended history" "$SCRIPT_FILE"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: handles zsh history format"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should handle zsh history format"
fi

# Test: uses uniq for frequency counting
test_start "suggest_frequency_count"
assert_file_contains "$SCRIPT_FILE" "uniq -c" "should use uniq -c for frequency counting"

# Test: uses sort for ranking
test_start "suggest_sort"
assert_file_contains "$SCRIPT_FILE" "sort -rn" "should use sort -rn for ranking"

# Test: uses HISTFILE
test_start "suggest_histfile"
assert_file_contains "$SCRIPT_FILE" "HISTFILE" "should use HISTFILE"

# Test: checks for existing aliases
test_start "suggest_existing_aliases"
assert_file_contains "$SCRIPT_FILE" "existing_aliases" "should check for existing aliases"

# Test: uses ui_header
test_start "suggest_ui_header"
assert_file_contains "$SCRIPT_FILE" "ui_header" "should use ui_header"

# Test: uses ui_warn
test_start "suggest_ui_warn"
assert_file_contains "$SCRIPT_FILE" "ui_warn" "should use ui_warn"

# Test: uses ui_init
test_start "suggest_ui_init"
assert_file_contains "$SCRIPT_FILE" "ui_init" "should initialize ui"

echo ""
echo "suggest.sh tests completed."
print_summary
