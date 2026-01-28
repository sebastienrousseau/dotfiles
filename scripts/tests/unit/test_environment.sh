#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2016
# Unit tests for .chezmoitemplates/functions/environment.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/environment.sh"

echo "Testing environment function..."

# Test: environment.sh exists
test_start "environment_file_exists"
assert_file_exists "$FUNC_FILE" "environment.sh should exist"

# Test: environment.sh has valid syntax
test_start "environment_syntax"
assert_exit_code 0 "bash -n '$FUNC_FILE'"

# Source the function
if [[ -f "$FUNC_FILE" ]]; then
  source "$FUNC_FILE"
fi

# Test: environment returns non-empty result
test_start "environment_returns_value"
result=$(environment 2>/dev/null)
assert_not_empty "$result" "environment should return a value"

# Test: environment returns one of the expected values
test_start "environment_valid_output"
result=$(environment 2>/dev/null)
if [[ "$result" == "mac" || "$result" == "linux" || "$result" == "win" || "$result" == "other" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: returns valid OS ($result)"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should return mac/linux/win/other"
  echo -e "    Actual: $result"
fi

# Test: environment --help shows help
test_start "environment_help"
output=$(environment --help 2>&1)
if [[ "$output" == *"Environment Detector"* ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: --help shows help text"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: --help should show help text"
fi

# Test: environment uses case statement (no repeated uname calls)
test_start "environment_single_uname"
assert_file_contains "$FUNC_FILE" 'case "$os_name"' "should use case statement for single uname call"

# Test: on macOS, environment returns "mac"
test_start "environment_macos_detection"
if [[ "$(uname -s)" == "Darwin" ]]; then
  result=$(environment 2>/dev/null)
  assert_equals "mac" "$result" "should return 'mac' on macOS"
else
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (not macOS)"
fi

# Test: on Linux, environment returns "linux"
test_start "environment_linux_detection"
if [[ "$(uname -s)" == "Linux" ]]; then
  result=$(environment 2>/dev/null)
  assert_equals "linux" "$result" "should return 'linux' on Linux"
else
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: skipped (not Linux)"
fi

print_summary
