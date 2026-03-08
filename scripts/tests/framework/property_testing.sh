#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC2034,SC2207
# =============================================================================
# Property-Based Testing Framework for Shell Scripts
# Generates test inputs and verifies invariants
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test_framework.sh"

# Property testing configuration
PROPERTY_ITERATIONS="${PROPERTY_ITERATIONS:-100}"
PROPERTY_SEED="${PROPERTY_SEED:-$(date +%s)}"
PROPERTY_MAX_SIZE="${PROPERTY_MAX_SIZE:-1000}"

# Random number generator state
declare -i RNG_STATE="$PROPERTY_SEED"

# Generate pseudo-random number using LCG
random_int() {
  local max="${1:-32767}"
  RNG_STATE=$(((RNG_STATE * 1664525 + 1013904223) % 4294967296))
  echo $((RNG_STATE % (max + 1)))
}

# Generate random string of specified length
generate_string() {
  local length="${1:-10}"
  local charset="${2:-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789}"
  local result=""

  for ((i = 0; i < length; i++)); do
    local char_idx
    char_idx=$(random_int $((${#charset} - 1)))
    result+="${charset:$char_idx:1}"
  done

  echo "$result"
}

# Generate random filename (safe characters only)
generate_filename() {
  local length="${1:-10}"
  local charset="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-."
  generate_string "$length" "$charset"
}

# Generate random path-safe string
generate_path() {
  local components="${1:-3}"
  local path=""

  for ((i = 0; i < components; i++)); do
    [[ $i -gt 0 ]] && path+="/"
    path+="$(generate_filename $(($(random_int 8) + 3)))"
  done

  echo "$path"
}

# Generate random integer within range
generate_int() {
  local min="${1:-0}"
  local max="${2:-100}"
  echo $((min + $(random_int $((max - min)))))
}

# Generate random boolean (0 or 1)
generate_bool() {
  random_int 1
}

# Generate edge case strings
generate_edge_string() {
  local edge_cases=(
    ""                    # empty string
    " "                   # single space
    "\t"                  # tab
    "\n"                  # newline
    "'"                   # single quote
    "\""                  # double quote
    "\\"                  # backslash
    "\$"                  # dollar sign
    ";"                   # semicolon
    "|"                   # pipe
    "&"                   # ampersand
    ">"                   # redirect
    "<"                   # redirect
    "*"                   # glob
    "?"                   # glob
    "["                   # bracket
    "]"                   # bracket
    "{"                   # brace
    "}"                   # brace
    "$(echo test)"        # command substitution
    "\$(malicious)"       # potential injection
    "../../../etc/passwd" # path traversal
    "/dev/null"           # special file
    "-rf /"               # dangerous flag combo
    "--help"              # help flag
    "-"                   # stdin indicator
  )

  local idx
  idx=$(random_int $((${#edge_cases[@]} - 1)))
  echo "${edge_cases[$idx]}"
}

# Generate Unicode test strings
generate_unicode_string() {
  local unicode_cases=(
    "café"   # Latin with accents
    "你好"     # Chinese
    "🚀✨"     # Emojis
    "Ω≠∞"    # Mathematical symbols
    "ﷺ"      # Arabic
    "Привет" # Cyrillic
    "🏳️‍🌈"   # Complex emoji sequence
  )

  local idx
  idx=$(random_int $((${#unicode_cases[@]} - 1)))
  echo "${unicode_cases[$idx]}"
}

# Property test runner
run_property_test() {
  local test_name="$1"
  local property_function="$2"
  local generator_function="$3"
  local iterations="${4:-$PROPERTY_ITERATIONS}"

  log_info "Running property test: $test_name ($iterations iterations)"

  local passed=0 failed=0
  local failures=()

  for ((i = 0; i < iterations; i++)); do
    # Generate test input
    local test_input
    test_input=$($generator_function)

    # Run property test
    local result=0
    local output
    output=$($property_function "$test_input" 2>&1) || result=$?

    if [[ $result -eq 0 ]]; then
      ((passed++))
    else
      ((failed++))
      failures+=("Input: '$test_input' | Output: $output")

      # Show first few failures immediately
      if [[ ${#failures[@]} -le 3 ]]; then
        log_error "Property violation #${#failures[@]}: Input='$test_input'"
        [[ -n "$output" ]] && echo "  Output: $output"
      fi
    fi

    # Early termination on too many failures
    if [[ $failed -gt $((iterations / 10)) ]]; then
      log_error "Too many failures ($failed), terminating early"
      break
    fi
  done

  # Report results
  echo
  echo "Property Test Results for: $test_name"
  echo "======================================"
  echo "Total iterations: $((passed + failed))"
  echo "Passed: $passed"
  echo "Failed: $failed"

  if [[ $failed -eq 0 ]]; then
    assert_true true "$test_name property holds for all generated inputs"
    return 0
  else
    assert_true false "$test_name property violated in $failed cases"

    # Show summary of failures
    echo
    echo "Failure Summary:"
    local max_show=5
    for ((i = 0; i < ${#failures[@]} && i < max_show; i++)); do
      echo "  $((i + 1)). ${failures[$i]}"
    done
    [[ ${#failures[@]} -gt $max_show ]] && echo "  ... and $((${#failures[@]} - max_show)) more"

    return 1
  fi
}

# Shrinking function to find minimal failing case
shrink_input() {
  local property_function="$1"
  local failing_input="$2"

  log_info "Shrinking failing input: '$failing_input'"

  local current="$failing_input"
  local shrunk=true

  while [[ "$shrunk" == "true" ]]; do
    shrunk=false
    local current_len=${#current}

    # Try removing characters from the end
    for ((len = 1; len < current_len; len++)); do
      local candidate="${current:0:$len}"
      if ! $property_function "$candidate" >/dev/null 2>&1; then
        current="$candidate"
        shrunk=true
        log_info "Shrunk to: '$current'"
        break
      fi
    done

    # Try removing characters from the middle
    if [[ "$shrunk" == "false" && $current_len -gt 2 ]]; then
      for ((i = 1; i < current_len - 1; i++)); do
        local candidate="${current:0:$i}${current:$((i + 1))}"
        if ! $property_function "$candidate" >/dev/null 2>&1; then
          current="$candidate"
          shrunk=true
          log_info "Shrunk to: '$current'"
          break
        fi
      done
    fi
  done

  echo "Minimal failing input: '$current'"
  return 1
}

# Test invariants for serialization functions
test_serialization_roundtrip() {
  local input="$1"

  # Test encode64/decode64 roundtrip
  if command -v encode64 >/dev/null 2>&1; then
    local encoded decoded
    encoded=$(echo "$input" | encode64) || return 1
    decoded=$(echo "$encoded" | decode64) || return 1

    [[ "$input" == "$decoded" ]] || {
      echo "Roundtrip failed: '$input' != '$decoded'"
      return 1
    }
  fi

  return 0
}

# Test path manipulation invariants
test_path_safety() {
  local path="$1"

  # Test that path manipulation doesn't create dangerous paths
  if [[ "$path" =~ \.\./\.\./\.\. ]]; then
    echo "Path traversal detected: $path"
    return 1
  fi

  if [[ "$path" =~ ^/etc/|^/usr/|^/var/|^/root/ ]]; then
    echo "System path detected: $path"
    return 1
  fi

  return 0
}

# Test parser invariants
test_parser_invariant() {
  local input="$1"

  # Test that parser doesn't crash on any input
  local result=0
  bash -n <(echo "$input") 2>/dev/null || result=$?

  # Syntax errors are expected and OK
  return 0
}

# Test mathematical properties
test_math_property() {
  local input="$1"

  # Test that numeric operations are commutative
  if [[ "$input" =~ ^[0-9]+$ ]]; then
    local a="$input"
    local b=42

    # a + b = b + a
    [[ $((a + b)) -eq $((b + a)) ]] || return 1

    # a * b = b * a
    [[ $((a * b)) -eq $((b * a)) ]] || return 1
  fi

  return 0
}

# Example usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  echo "Property-Based Testing Framework Demo"
  echo "====================================="

  # Test string generator
  echo "Sample generated strings:"
  for i in {1..5}; do
    echo "  $(generate_string 10)"
  done

  echo
  echo "Sample edge case strings:"
  for i in {1..5}; do
    echo "  '$(generate_edge_string)'"
  done

  echo
  echo "Sample Unicode strings:"
  for i in {1..3}; do
    echo "  '$(generate_unicode_string)'"
  done
fi
