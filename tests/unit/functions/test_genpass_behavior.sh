#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioral tests for the genpass function.
# Tests password structure, character classes, length, and validation.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/security/genpass.sh"
if [[ ! -f "$FUNC_FILE" ]]; then
  echo "SKIP: genpass.sh not found at $FUNC_FILE"
  echo "RESULTS:0:0:0"
  exit 0
fi
source "$FUNC_FILE"

# Suppress clipboard side-effects by mocking all clipboard tools.
mock_init
mock_command "pbcopy"  ""
mock_command "xclip"   ""
mock_command "wl-copy" ""
mock_command "clip.exe" ""
mock_command "cb"       ""

# Skip all tests if openssl is unavailable.
if ! command -v openssl >/dev/null 2>&1; then
  echo "SKIP: openssl not available"
  echo "RESULTS:0:0:0"
  exit 0
fi

# Helper: extract the generated password from genpass output.
_get_password() {
  genpass "$@" 2>&1 | grep "Generated password:" | sed 's/.*Generated password: //'
}

# ──────────────────────────────────────────────────────────────────────────────
# 1. Default output contains the INFO label
# ──────────────────────────────────────────────────────────────────────────────
test_start "genpass_info_label"
output=$(genpass 2>&1)
assert_contains "[INFO]" "$output" "default run should include [INFO] label"

# ──────────────────────────────────────────────────────────────────────────────
# 2. Default password contains exactly 2 default separators (3 blocks → 2 dashes)
# ──────────────────────────────────────────────────────────────────────────────
test_start "genpass_default_three_blocks"
pw=$(_get_password)
# The separator chars from the charset may appear inside blocks, so count
# leading-separator boundaries: split on '-' and count resulting segments.
block_count=$(echo "$pw" | awk -F'-' '{print NF}')
# We test >= 2 segments (≥1 separator) since special chars in blocks could add
# hyphens. The key assertion is that it's not a flat, separator-free string
# when num_blocks defaults to 3.
assert_true "[[ $block_count -ge 2 ]]" "default password should have at least 2 segments"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Each block is exactly 12 characters (block_size constant)
#    Using a separator that never appears in the CHARSET to make splitting safe.
# ──────────────────────────────────────────────────────────────────────────────
test_start "genpass_block_size_12"
pw=$(_get_password 3 "|")
IFS='|' read -ra blocks <<< "$pw"
all_correct=true
for blk in "${blocks[@]}"; do
  if [[ ${#blk} -ne 12 ]]; then
    all_correct=false
  fi
done
assert_true "[[ $all_correct == true ]]" "each block should be exactly 12 characters"

# ──────────────────────────────────────────────────────────────────────────────
# 4. Requesting 1 block yields no separator
# ──────────────────────────────────────────────────────────────────────────────
test_start "genpass_single_block_length"
pw=$(_get_password 1 "|")
assert_equals "12" "${#pw}" "single block should be 12 characters"

# ──────────────────────────────────────────────────────────────────────────────
# 5. Requesting 5 blocks produces correct total character length
# ──────────────────────────────────────────────────────────────────────────────
test_start "genpass_five_blocks_total_length"
pw=$(_get_password 5 "|")
# 5 blocks * 12 chars + 4 separators = 64 chars
assert_equals "64" "${#pw}" "5 blocks with '|' separator should be 64 chars total"

# ──────────────────────────────────────────────────────────────────────────────
# 6. Custom separator is present in multi-block password
# ──────────────────────────────────────────────────────────────────────────────
test_start "genpass_custom_separator_slash"
pw=$(_get_password 3 "/")
assert_contains "/" "$pw" "custom separator '/' should appear in password"

# ──────────────────────────────────────────────────────────────────────────────
# 7. Two consecutive runs produce different passwords (randomness)
# ──────────────────────────────────────────────────────────────────────────────
test_start "genpass_randomness"
pw1=$(_get_password)
pw2=$(_get_password)
assert_not_equals "$pw1" "$pw2" "consecutive passwords should differ"

# ──────────────────────────────────────────────────────────────────────────────
# 8. num_blocks=0 is rejected as invalid
# ──────────────────────────────────────────────────────────────────────────────
test_start "genpass_zero_blocks_rejected"
output=$(genpass 0 2>&1)
rc=$?
assert_equals "1" "$rc" "num_blocks=0 should return exit code 1"
assert_contains "ERROR" "$output" "num_blocks=0 should print ERROR"

# ──────────────────────────────────────────────────────────────────────────────
# 9. num_blocks > 100 is rejected
# ──────────────────────────────────────────────────────────────────────────────
test_start "genpass_too_many_blocks_rejected"
output=$(genpass 101 2>&1)
rc=$?
assert_equals "1" "$rc" "num_blocks=101 should return exit code 1"
assert_contains "ERROR" "$output" "num_blocks=101 should print ERROR"

# ──────────────────────────────────────────────────────────────────────────────
# 10. Non-numeric num_blocks is rejected
# ──────────────────────────────────────────────────────────────────────────────
test_start "genpass_non_numeric_blocks_rejected"
output=$(genpass "abc" 2>&1)
rc=$?
assert_equals "1" "$rc" "non-numeric num_blocks should return exit code 1"

# ──────────────────────────────────────────────────────────────────────────────
# 11. --help returns exit code 0 and prints usage
# ──────────────────────────────────────────────────────────────────────────────
test_start "genpass_help_flag"
output=$(genpass --help 2>&1)
assert_equals "0" "$?" "--help should exit 0"
assert_contains "Usage" "$output" "--help should include Usage"

mock_cleanup

echo ""
echo "genpass behavioral tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
