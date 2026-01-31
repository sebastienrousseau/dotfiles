#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for Wave 2: dot new Python pre-flight guard
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

DOT_CLI="$REPO_ROOT/dot_local/bin/executable_dot"

echo "Testing Wave 2: dot new Python pre-flight guard..."

test_start "dot_cli_exists"
assert_file_exists "$DOT_CLI" "executable_dot should exist"

test_start "dot_cli_syntax"
assert_exit_code 0 "bash -n '$DOT_CLI'"

# The Python check should appear BEFORE any mkdir/cp operations in the new) case
test_start "python_check_before_filesystem_ops"
# Extract the new) case block and verify python check comes first
new_block=$(sed -n '/^[[:space:]]*new)/,/^[[:space:]]*;;/p' "$DOT_CLI")
python_line=$(echo "$new_block" | grep -n 'python3\|PYTHON_CMD' | head -1 | cut -d: -f1)
mkdir_line=$(echo "$new_block" | grep -n 'mkdir' | head -1 | cut -d: -f1)

if [[ -n "$python_line" && -n "$mkdir_line" ]]; then
  if [[ "$python_line" -lt "$mkdir_line" ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: Python check (line $python_line) before mkdir (line $mkdir_line)"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: Python check should come before mkdir"
  fi
elif [[ -n "$python_line" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: Python check present in new block"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: Python check not found in new block"
fi

test_start "python_error_to_stderr"
# The error message should go to stderr
if grep -q 'python3.*>&2\|PYTHON_CMD.*>&2\|Python.*>&2' "$DOT_CLI"; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: Python error redirected to stderr"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: Python error should go to stderr"
fi

test_start "dot_new_no_args_usage"
set +e
output=$(bash "$DOT_CLI" new 2>&1)
ec=$?
set -e
if [[ "$output" == *"Usage:"* ]] && [[ $ec -ne 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: dot new with no args shows usage"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: dot new with no args should show usage (ec=$ec)"
fi

echo ""
echo "Wave 2 dot new Python guard tests completed."
print_summary
