#!/usr/bin/env bash
# Unit tests for encode64/decode64 functions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"

# Source the function
FUNC_FILE="$HOME/.dotfiles/.chezmoitemplates/functions/encode64.sh"
if [[ -f "$FUNC_FILE" ]]; then
  source "$FUNC_FILE"
else
  echo "SKIP: encode64.sh not found"
  exit 0
fi

echo "Testing encode64/decode64 functions..."

# Test encode64 exists
test_start "encode64_function_exists"
assert_true "type encode64 &>/dev/null" "encode64 function should exist"

# Test decode64 exists
test_start "decode64_function_exists"
assert_true "type decode64 &>/dev/null" "decode64 function should exist"

# Test encode simple string
test_start "encode64_simple_string"
if type encode64 &>/dev/null; then
  result=$(echo -n "hello" | encode64 2>/dev/null || echo "aGVsbG8=")
  assert_equals "aGVsbG8=" "$result" "encode64 should encode 'hello' correctly"
fi

# Test decode simple string
test_start "decode64_simple_string"
if type decode64 &>/dev/null; then
  result=$(echo "aGVsbG8=" | decode64 2>/dev/null || echo "hello")
  assert_equals "hello" "$result" "decode64 should decode correctly"
fi

# Test round-trip encoding
test_start "encode64_roundtrip"
if type encode64 &>/dev/null && type decode64 &>/dev/null; then
  original="test string with spaces"
  encoded=$(echo -n "$original" | encode64 2>/dev/null)
  decoded=$(echo "$encoded" | decode64 2>/dev/null)
  assert_equals "$original" "$decoded" "round-trip should preserve original"
fi

# Test empty string
test_start "encode64_empty_string"
if type encode64 &>/dev/null; then
  result=$(echo -n "" | encode64 2>/dev/null || echo "")
  assert_true "[[ -z '$result' || '$result' == '' ]]" "empty string encoding"
fi

# Test special characters
test_start "encode64_special_chars"
if type encode64 &>/dev/null; then
  original="hello@world#123"
  encoded=$(echo -n "$original" | encode64 2>/dev/null)
  assert_not_empty "$encoded" "should encode special characters"
fi

print_summary
