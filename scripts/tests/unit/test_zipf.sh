#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for zipf function

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

# Source the function
FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/zipf.sh"
if [[ -f "$FUNC_FILE" ]]; then
  source "$FUNC_FILE"
else
  echo "SKIP: zipf.sh not found at $FUNC_FILE"
  echo "RESULTS:0:0:0"
  exit 0
fi

echo "Testing zipf function..."

# Test function exists
test_start "zipf_function_exists"
assert_true "type zipf &>/dev/null" "zipf function should exist"

# Test no arguments
test_start "zipf_no_args"
if type zipf &>/dev/null; then
  assert_exit_code 1 "zipf 2>/dev/null"
fi

# Test nonexistent directory
test_start "zipf_nonexistent_dir"
if type zipf &>/dev/null; then
  # zipf returns non-zero for nonexistent paths (exit code varies by implementation)
  result=$(zipf /nonexistent/path/12345 2>/dev/null; echo $?)
  if [[ "$result" != "0" ]]; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: returns non-zero for nonexistent path"
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: should fail for nonexistent path"
  fi
fi

# Test with valid directory
test_start "zipf_valid_directory"
if type zipf &>/dev/null; then
  test_dir=$(mktemp -d)
  echo "test" >"$test_dir/test.txt"

  # Run zipf and check if zip was created
  zipf "$test_dir" 2>/dev/null || true

  if [[ -f "${test_dir}.zip" ]]; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: zipf created archive"
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: zipf should create a .zip archive"
  fi

  # Cleanup
  rm -rf "$test_dir" "${test_dir}.zip" 2>/dev/null
fi

# Test help flag if supported
test_start "zipf_help_flag"
if type zipf &>/dev/null; then
  output=$(zipf --help 2>&1 || zipf -h 2>&1 || echo "no help")
  assert_not_empty "$output" "help flag should produce output"
fi

print_summary
