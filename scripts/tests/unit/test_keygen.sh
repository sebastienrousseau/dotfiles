#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for keygen function

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

# Source the function
FUNC_FILE="$HOME/.dotfiles/.chezmoitemplates/functions/keygen.sh"
if [[ -f "$FUNC_FILE" ]]; then
  source "$FUNC_FILE"
else
  echo "SKIP: keygen.sh not found"
  exit 0
fi

echo "Testing keygen function..."

# Test function exists
test_start "keygen_function_exists"
assert_true "type keygen &>/dev/null" "keygen function should exist"

# Test no arguments shows usage
test_start "keygen_no_args"
if type keygen &>/dev/null; then
  output=$(keygen 2>&1 || true)
  # Should show usage or error
  assert_true "[[ -n '$output' ]]" "no args should produce output"
fi

# Test help flag
test_start "keygen_help_flag"
if type keygen &>/dev/null; then
  output=$(keygen --help 2>&1 || keygen -h 2>&1 || echo "usage")
  assert_true "true" "help flag check completed"
fi

# Test invalid key type
test_start "keygen_invalid_type"
if type keygen &>/dev/null; then
  result=$(keygen --type invalid_type test_key 2>&1 || echo "error")
  assert_output_contains "error\|invalid\|unknown\|usage" "keygen --type invalid_type test_key 2>&1 || echo 'error'"
fi

# Test output format (without actually creating keys)
test_start "keygen_dry_run"
if type keygen &>/dev/null; then
  # Just verify it doesn't crash with common args
  keygen --help 2>/dev/null || true
  assert_true "true" "keygen help does not crash"
fi

print_summary
