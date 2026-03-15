#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091
# Property-based tests for encode64/decode64 roundtrip

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/property_testing.sh"

# Source the function under test
FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/text/encode64.sh"
if [[ -f "$FUNC_FILE" ]]; then
  source "$FUNC_FILE"
else
  echo "SKIP: encode64.sh not found at $FUNC_FILE"
  echo "RESULTS:0:0:0"
  exit 0
fi

echo "Property tests for encode64/decode64..."

# ---------------------------------------------------------------------------
# Generator: random alphanumeric strings of varying length
# ---------------------------------------------------------------------------
gen_alnum_string() {
  local len
  len=$(generate_int 1 64)
  generate_string "$len"
}

# Generator: short strings including spaces and common punctuation that
# survive the printf '%s' / base64 pipeline without binary artifacts
gen_printable_string() {
  local charset="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 !@#%-_=+.,"
  local len
  len=$(generate_int 1 40)
  generate_string "$len" "$charset"
}

# Generator: fixed-length strings (length 12, like a password block)
gen_fixed12_string() {
  generate_string 12
}

# Generator: path-like strings safe for base64 (no shell metacharacters)
gen_path_string() {
  generate_path 3
}

# Generator: single-character strings
gen_single_char() {
  generate_string 1
}

# ---------------------------------------------------------------------------
# Properties
# ---------------------------------------------------------------------------

# Property 1: roundtrip via argument form — encode64 arg | decode via arg
prop_roundtrip_arg() {
  local input="$1"
  local encoded decoded

  encoded=$(encode64 "$input" 2>/dev/null) || {
    echo "encode64 failed for input: $input"
    return 1
  }

  decoded=$(decode64 "$encoded" 2>/dev/null) || {
    echo "decode64 failed for encoded: $encoded"
    return 1
  }

  if [[ "$input" == "$decoded" ]]; then
    return 0
  else
    echo "Roundtrip failed: expected '$input', got '$decoded'"
    return 1
  fi
}

# Property 2: roundtrip via pipe form — echo -n | encode64 | decode64
prop_roundtrip_pipe() {
  local input="$1"
  local encoded decoded

  encoded=$(printf '%s' "$input" | encode64 2>/dev/null) || {
    echo "encode64 pipe failed"
    return 1
  }

  decoded=$(printf '%s' "$encoded" | decode64 2>/dev/null) || {
    echo "decode64 pipe failed"
    return 1
  }

  if [[ "$input" == "$decoded" ]]; then
    return 0
  else
    echo "Roundtrip (pipe) failed: expected '$input', got '$decoded'"
    return 1
  fi
}

# Property 3: encoded output is non-empty for non-empty input
prop_encoded_nonempty() {
  local input="$1"
  local encoded

  # Skip truly empty inputs for this property
  [[ -z "$input" ]] && return 0

  encoded=$(encode64 "$input" 2>/dev/null) || {
    echo "encode64 failed"
    return 1
  }

  if [[ -n "$encoded" ]]; then
    return 0
  else
    echo "encode64 returned empty output for non-empty input: '$input'"
    return 1
  fi
}

# Property 4: encoded output contains only valid base64 characters
# Base64 alphabet: A-Z a-z 0-9 + / = (and possibly newlines from folding)
prop_encoded_valid_base64() {
  local input="$1"
  local encoded stripped

  encoded=$(encode64 "$input" 2>/dev/null) || return 1

  # Strip whitespace/newlines that base64 may insert for line folding
  stripped=$(printf '%s' "$encoded" | tr -d '\n\r ')

  if [[ "$stripped" =~ ^[A-Za-z0-9+/=]*$ ]]; then
    return 0
  else
    echo "Encoded output contains non-base64 chars: '$stripped'"
    return 1
  fi
}

# Property 5: double encode then double decode returns original
prop_double_roundtrip() {
  local input="$1"
  local enc1 enc2 dec1 result

  enc1=$(encode64 "$input" 2>/dev/null) || return 1
  enc2=$(encode64 "$enc1" 2>/dev/null) || return 1
  dec1=$(decode64 "$enc2" 2>/dev/null) || return 1
  result=$(decode64 "$dec1" 2>/dev/null) || return 1

  if [[ "$input" == "$result" ]]; then
    return 0
  else
    echo "Double roundtrip failed: expected '$input', got '$result'"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Run property tests
# ---------------------------------------------------------------------------

test_start "prop_encode64_roundtrip_arg_alnum"
run_property_test \
  "encode64/decode64 roundtrip (arg form, alphanumeric)" \
  prop_roundtrip_arg \
  gen_alnum_string \
  50

test_start "prop_encode64_roundtrip_pipe_alnum"
run_property_test \
  "encode64/decode64 roundtrip (pipe form, alphanumeric)" \
  prop_roundtrip_pipe \
  gen_alnum_string \
  50

test_start "prop_encode64_roundtrip_printable"
run_property_test \
  "encode64/decode64 roundtrip (printable strings)" \
  prop_roundtrip_arg \
  gen_printable_string \
  50

test_start "prop_encode64_valid_base64_output"
run_property_test \
  "encode64 output is valid base64 alphabet" \
  prop_encoded_valid_base64 \
  gen_alnum_string \
  50

test_start "prop_encode64_nonempty_output"
run_property_test \
  "encode64 produces non-empty output for non-empty input" \
  prop_encoded_nonempty \
  gen_fixed12_string \
  30

echo ""
echo "encode64 property tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
