#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioral tests for encode64 / decode64.
# Tests argument mode, stdin mode, roundtrip fidelity, and edge cases.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/text/encode64.sh"
if [[ ! -f "$FUNC_FILE" ]]; then
  echo "SKIP: encode64.sh not found at $FUNC_FILE"
  echo "RESULTS:0:0:0"
  exit 0
fi
# The file also defines aliases; tolerate alias errors in non-interactive shell.
source "$FUNC_FILE" 2>/dev/null || source "$FUNC_FILE"

# ──────────────────────────────────────────────────────────────────────────────
# 1. encode64 with argument produces the correct base64 value
# ──────────────────────────────────────────────────────────────────────────────
test_start "encode64_arg_hello"
result=$(encode64 "hello")
assert_equals "aGVsbG8=" "$result" "encode64 'hello' should produce 'aGVsbG8='"

# ──────────────────────────────────────────────────────────────────────────────
# 2. encode64 via stdin produces the same result
# ──────────────────────────────────────────────────────────────────────────────
test_start "encode64_stdin_hello"
result=$(printf '%s' "hello" | encode64)
assert_equals "aGVsbG8=" "$result" "encode64 via stdin should match argument mode"

# ──────────────────────────────────────────────────────────────────────────────
# 3. decode64 with argument decodes the known value
# ──────────────────────────────────────────────────────────────────────────────
test_start "decode64_arg_hello"
result=$(decode64 "aGVsbG8=")
assert_equals "hello" "$result" "decode64 'aGVsbG8=' should produce 'hello'"

# ──────────────────────────────────────────────────────────────────────────────
# 4. decode64 via stdin decodes the known value
# ──────────────────────────────────────────────────────────────────────────────
test_start "decode64_stdin_hello"
result=$(printf '%s\n' "aGVsbG8=" | decode64)
assert_equals "hello" "$result" "decode64 via stdin should match argument mode"

# ──────────────────────────────────────────────────────────────────────────────
# 5. Roundtrip: encode then decode preserves the original string (argument mode)
# ──────────────────────────────────────────────────────────────────────────────
test_start "encode64_decode64_roundtrip_arg"
original="Hello, World! 42"
encoded=$(encode64 "$original")
decoded=$(decode64 "$encoded")
assert_equals "$original" "$decoded" "roundtrip should preserve original string"

# ──────────────────────────────────────────────────────────────────────────────
# 6. Roundtrip: stdin encode then decode preserves original
# ──────────────────────────────────────────────────────────────────────────────
test_start "encode64_decode64_roundtrip_stdin"
original="pipeline test with spaces"
encoded=$(printf '%s' "$original" | encode64)
decoded=$(printf '%s\n' "$encoded" | decode64)
assert_equals "$original" "$decoded" "stdin roundtrip should preserve original string"

# ──────────────────────────────────────────────────────────────────────────────
# 7. Encoding produces only valid base64 characters
# ──────────────────────────────────────────────────────────────────────────────
test_start "encode64_valid_base64_chars"
result=$(encode64 "test string")
# Valid base64: A-Z a-z 0-9 + / = (with optional trailing newline stripped)
result_stripped="${result%$'\n'}"
if [[ "$result_stripped" =~ ^[A-Za-z0-9+/=]+$ ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: output contains only valid base64 chars"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: output should contain only valid base64 chars"
  printf '%b\n' "    Actual: '$result_stripped'"
fi

# ──────────────────────────────────────────────────────────────────────────────
# 8. Special characters survive the roundtrip
# ──────────────────────────────────────────────────────────────────────────────
test_start "encode64_special_chars_roundtrip"
original='!@#$%^&*()_+-=[]{}|;:,.<>?'
encoded=$(encode64 "$original")
decoded=$(decode64 "$encoded")
assert_equals "$original" "$decoded" "special characters should survive roundtrip"

# ──────────────────────────────────────────────────────────────────────────────
# 9. encode64 --help exits 0 and includes relevant content
# ──────────────────────────────────────────────────────────────────────────────
test_start "encode64_help_flag"
output=$(encode64 --help 2>&1)
assert_equals "0" "$?" "encode64 --help should exit 0"
assert_contains "encode64" "$output" "encode64 --help should mention 'encode64'"

# ──────────────────────────────────────────────────────────────────────────────
# 10. decode64 --help exits 0 and includes relevant content
# ──────────────────────────────────────────────────────────────────────────────
test_start "decode64_help_flag"
output=$(decode64 --help 2>&1)
assert_equals "0" "$?" "decode64 --help should exit 0"
assert_contains "decode64" "$output" "decode64 --help should mention 'decode64'"

echo ""
echo "encode64/decode64 behavioral tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
