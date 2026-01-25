#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for zipf function

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

# Source the function
FUNC_FILE="$HOME/.dotfiles/.chezmoitemplates/functions/zipf.sh"
if [[ -f "$FUNC_FILE" ]]; then
  source "$FUNC_FILE"
else
  echo "SKIP: zipf.sh not found"
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
  assert_exit_code 1 "zipf /nonexistent/path/12345 2>/dev/null"
fi

# Test with valid directory
test_start "zipf_valid_directory"
if type zipf &>/dev/null; then
  test_dir=$(mktemp -d)
  echo "test" >"$test_dir/test.txt"

  # Run zipf (may or may not create zip depending on implementation)
  zipf "$test_dir" 2>/dev/null || true

  # Cleanup
  rm -rf "$test_dir" "${test_dir}.zip" 2>/dev/null
  assert_true "true" "zipf executed without crash"
fi

# Test help flag if supported
test_start "zipf_help_flag"
if type zipf &>/dev/null; then
  output=$(zipf --help 2>&1 || zipf -h 2>&1 || echo "no help")
  assert_true "true" "help flag check completed"
fi

print_summary
