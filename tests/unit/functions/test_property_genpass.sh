#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091
# Property-based tests for genpass function

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/property_testing.sh"

# Source the function under test
FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/security/genpass.sh"
if [[ -f "$FUNC_FILE" ]]; then
  source "$FUNC_FILE"
else
  echo "SKIP: genpass.sh not found at $FUNC_FILE"
  echo "RESULTS:0:0:0"
  exit 0
fi

# Require openssl — genpass depends on it
if ! command -v openssl >/dev/null 2>&1; then
  echo "SKIP: openssl not available"
  echo "RESULTS:0:0:0"
  exit 0
fi

echo "Property tests for genpass..."

# genpass constants
readonly BLOCK_SIZE=12

# ---------------------------------------------------------------------------
# Generator: random valid block counts (1-6 to keep tests fast)
# ---------------------------------------------------------------------------
gen_block_count() {
  generate_int 1 6
}

# Generator: block counts as strings (what genpass receives)
gen_block_count_str() {
  printf '%d' "$(generate_int 1 6)"
}

# Generator: single fixed block count "3" (default)
gen_default_blocks() {
  echo "3"
}

# ---------------------------------------------------------------------------
# Helper: extract password text from genpass output
# genpass emits "[INFO] Generated password: <password>"
# ---------------------------------------------------------------------------
_extract_password() {
  local output="$1"
  printf '%s' "$output" | grep 'Generated password:' | sed 's/.*Generated password: //'
}

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

# Property 1: output length matches num_blocks * block_size + (num_blocks-1) separators
# Default separator is '-' (1 char). Total = num_blocks*12 + (num_blocks-1)*1
prop_output_length_matches_blocks() {
  local num_blocks="$1"
  local output password expected_len actual_len sep_count

  output=$(genpass "$num_blocks" 2>/dev/null) || {
    echo "genpass failed for num_blocks=$num_blocks"
    return 1
  }

  password=$(_extract_password "$output")
  if [[ -z "$password" ]]; then
    echo "Could not extract password from output: $output"
    return 1
  fi

  # Expected: num_blocks * BLOCK_SIZE chars + (num_blocks-1) separator chars
  expected_len=$(( num_blocks * BLOCK_SIZE + (num_blocks - 1) ))
  actual_len=${#password}

  if [[ "$actual_len" -eq "$expected_len" ]]; then
    return 0
  else
    echo "Length mismatch: num_blocks=$num_blocks expected=$expected_len actual=$actual_len password='$password'"
    return 1
  fi
}

# Property 2: password contains only printable ASCII characters
# The CHARSET used by genpass is entirely printable ASCII (0x20-0x7E range plus separators)
prop_output_printable_only() {
  local num_blocks="$1"
  local output password unprintable

  output=$(genpass "$num_blocks" 2>/dev/null) || return 1

  password=$(_extract_password "$output")
  if [[ -z "$password" ]]; then
    echo "Could not extract password"
    return 1
  fi

  # Strip all printable ASCII (0x20-0x7E) — anything remaining is non-printable
  unprintable=$(printf '%s' "$password" | tr -d '[:print:]')

  if [[ -z "$unprintable" ]]; then
    return 0
  else
    echo "Password contains non-printable chars: $(printf '%s' "$unprintable" | xxd | head -1)"
    return 1
  fi
}

# Property 3: password with N blocks has exactly N-1 default separators ('-')
# when no custom separator is specified
prop_separator_count_matches_blocks() {
  local num_blocks="$1"
  local output password sep_count expected_seps

  output=$(genpass "$num_blocks" 2>/dev/null) || return 1

  password=$(_extract_password "$output")
  if [[ -z "$password" ]]; then
    echo "Could not extract password"
    return 1
  fi

  expected_seps=$(( num_blocks - 1 ))
  sep_count=$(printf '%s' "$password" | tr -cd '-' | wc -c | tr -d ' ')

  # The separator '-' is also in the CHARSET, so block chars could contain '-'.
  # We only assert that we have AT LEAST (num_blocks-1) separators.
  if [[ "$sep_count" -ge "$expected_seps" ]]; then
    return 0
  else
    echo "Separator count: expected>=$expected_seps actual=$sep_count password='$password'"
    return 1
  fi
}

# Property 4: each generated password is non-empty and non-whitespace
prop_output_nonempty() {
  local num_blocks="$1"
  local output password stripped

  output=$(genpass "$num_blocks" 2>/dev/null) || return 1

  password=$(_extract_password "$output")
  stripped=$(printf '%s' "$password" | tr -d ' \t\n')

  if [[ -n "$stripped" ]]; then
    return 0
  else
    echo "Password is empty or whitespace-only for num_blocks=$num_blocks"
    return 1
  fi
}

# Property 5: genpass always exits with status 0 for valid block counts
prop_exits_zero() {
  local num_blocks="$1"
  local exit_code=0

  genpass "$num_blocks" >/dev/null 2>&1 || exit_code=$?

  if [[ "$exit_code" -eq 0 ]]; then
    return 0
  else
    echo "genpass exited with non-zero status $exit_code for num_blocks=$num_blocks"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Run property tests
# ---------------------------------------------------------------------------

test_start "prop_genpass_output_length"
run_property_test \
  "genpass output length matches num_blocks * block_size + separators" \
  prop_output_length_matches_blocks \
  gen_block_count_str \
  20

test_start "prop_genpass_printable_chars"
run_property_test \
  "genpass output contains only printable characters" \
  prop_output_printable_only \
  gen_block_count_str \
  20

test_start "prop_genpass_separator_count"
run_property_test \
  "genpass has at least num_blocks-1 default separators" \
  prop_separator_count_matches_blocks \
  gen_block_count_str \
  20

test_start "prop_genpass_nonempty_output"
run_property_test \
  "genpass always produces non-empty password" \
  prop_output_nonempty \
  gen_block_count_str \
  20

test_start "prop_genpass_exit_zero"
run_property_test \
  "genpass exits with status 0 for valid block counts" \
  prop_exits_zero \
  gen_block_count_str \
  20

echo ""
echo "genpass property tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
