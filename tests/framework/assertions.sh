#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC2034
# Assertion library for shell tests
# Provides a comprehensive set of assertion functions for testing shell scripts
#
# Security note: This file uses eval to execute test commands and conditions.
# This is intentional and necessary for the test assertion framework to work.
# These functions are only used in test code and should never be called with
# untrusted input. All eval calls carry a shellcheck disable directive.

# Re-source guard: re-sourcing would reset the TESTS_* counters mid-run.
[[ "${_DOT_LIB_ASSERTIONS_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_ASSERTIONS_LOADED=1

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

# Portable `timeout` shim. GNU coreutils ships `timeout`, but stock
# macOS does not (only `gtimeout`, and only after `brew install
# coreutils`). The macOS reliability runners don't install coreutils,
# so tests that wrap commands in `timeout <secs> <cmd>` otherwise fail
# with "timeout: command not found" (rc 127) on every invocation.
# Prefer real `timeout`, then `gtimeout`, else run the command without
# the hang-guard (losing only the timeout, not correctness). All test
# usages are the simple `timeout <duration> <command…>` form.
if ! command -v timeout >/dev/null 2>&1; then
  if command -v gtimeout >/dev/null 2>&1; then
    timeout() { gtimeout "$@"; }
  else
    # Fallback: strip any leading options (e.g. `--kill-after=5`, `-k 5`,
    # `-s TERM`) and the DURATION operand, then run the command unguarded.
    # Handles both `timeout 15 cmd` and `timeout --kill-after=5 60 cmd`.
    timeout() {
      while [[ "${1:-}" == -* ]]; do
        case "$1" in
          -k | --kill-after | -s | --signal) shift 2 ;; # option takes a value
          *) shift ;;                                   # bare flag or --opt=val
        esac
      done
      shift # drop the DURATION operand
      "$@"
    }
  fi
fi

# Start a new test case
test_start() {
  CURRENT_TEST="$1"
  ((TESTS_RUN++)) || true
}

# Assert two values are equal
assert_equals() {
  local expected="$1" actual="$2" msg="${3:-values should be equal}"
  if [[ "$expected" == "$actual" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    printf '%b\n' "    Expected: '$expected'"
    printf '%b\n' "    Actual:   '$actual'"
    return 1
  fi
}

# Assert two values are not equal
assert_not_equals() {
  local unexpected="$1" actual="$2" msg="${3:-values should differ}"
  if [[ "$unexpected" != "$actual" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    printf '%b\n' "    Unexpected: '$unexpected'"
    printf '%b\n' "    Actual:     '$actual'"
    return 1
  fi
}

# Assert a command exits with expected code
assert_exit_code() {
  local expected="$1"
  shift
  local cmd="$*"
  local actual

  # Save the caller's errexit state rather than assuming it was on.
  # This unconditionally ran `set -e` on the way out, which switched
  # errexit ON for suites that deliberately run without it (the
  # assert_* helpers return non-zero on failure, so `set -e` would
  # abort the suite at the first failed assertion instead of tallying
  # it). The leak meant the next command that legitimately returned
  # non-zero — `files=$(rg ...)` with no matches, say — killed the
  # suite between test_start and its assertion, leaving
  # RUN != PASSED+FAILED and tripping the framework-invariant check.
  local _had_errexit=0
  case "$-" in
    *e*) _had_errexit=1 ;;
  esac

  set +e
  # shellcheck disable=SC2086
  eval "$cmd" </dev/null >/dev/null 2>&1
  actual=$?
  ((_had_errexit)) && set -e

  assert_equals "$expected" "$actual" "exit code for: $cmd"
}

# Assert command output contains expected string
assert_output_contains() {
  local needle="$1"
  shift
  local cmd="$*"
  local output
  # shellcheck disable=SC2086
  output=$(eval "$cmd" 2>&1) || true
  if [[ "$output" == *"$needle"* ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: output contains '$needle'"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: output should contain '$needle'"
    printf '%b\n' "    Actual output: $output"
    return 1
  fi
}

# Assert command output does NOT contain a string
assert_output_not_contains() {
  local needle="$1"
  shift
  local cmd="$*"
  local output
  # shellcheck disable=SC2086
  output=$(eval "$cmd" 2>&1) || true
  if [[ "$output" != *"$needle"* ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: output does not contain '$needle'"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: output should not contain '$needle'"
    printf '%b\n' "    Actual output: $output"
    return 1
  fi
}

# Assert command output matches regex pattern
assert_output_matches() {
  local pattern="$1"
  shift
  local cmd="$*"
  local output
  # shellcheck disable=SC2086
  output=$(eval "$cmd" 2>&1) || true
  if [[ "$output" =~ $pattern ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: output matches pattern '$pattern'"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: output should match pattern '$pattern'"
    printf '%b\n' "    Actual output: $output"
    return 1
  fi
}

# Assert file exists
assert_file_exists() {
  local file="$1" msg="${2:-file should exist}"
  if [[ -f "$file" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg ($file not found)"
    return 1
  fi
}

# Assert file does not exist
assert_file_not_exists() {
  local file="$1" msg="${2:-file should not exist}"
  if [[ ! -f "$file" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg ($file exists)"
    return 1
  fi
}

# Assert directory exists
assert_dir_exists() {
  local dir="$1" msg="${2:-directory should exist}"
  if [[ -d "$dir" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg ($dir not found)"
    return 1
  fi
}

# Assert directory does not exist
assert_dir_not_exists() {
  local dir="$1" msg="${2:-directory should not exist}"
  if [[ ! -d "$dir" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg ($dir exists)"
    return 1
  fi
}

# Assert a condition is true
assert_true() {
  local condition="$1" msg="${2:-condition should be true}"
  # shellcheck disable=SC2086
  if eval "$condition"; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    return 1
  fi
}

# Assert a condition is false
assert_false() {
  local condition="$1" msg="${2:-condition should be false}"
  # shellcheck disable=SC2086
  if ! eval "$condition"; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    return 1
  fi
}

# Assert string is empty
assert_empty() {
  local value="$1" msg="${2:-value should be empty}"
  if [[ -z "$value" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    printf '%b\n' "    Actual: '$value'"
    return 1
  fi
}

# Assert string is not empty
assert_not_empty() {
  local value="$1" msg="${2:-value should not be empty}"
  if [[ -n "$value" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    return 1
  fi
}

# Assert file contains text (uses fixed-string matching for safety)
assert_file_contains() {
  local file="$1" needle="$2" msg="${3:-file should contain text}"
  if [[ -z "$file" ]]; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg (no file path provided)"
    return 1
  fi
  if [[ -f "$file" ]] && grep -qF -- "$needle" "$file"; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    return 1
  fi
}

# Assert string contains a substring
assert_contains() {
  local needle="$1" actual="$2" msg="${3:-string should contain substring}"
  if [[ "$actual" == *"$needle"* ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    printf '%b\n' "    Expected to contain: '$needle'"
    printf '%b\n' "    Actual string:      '$actual'"
    return 1
  fi
}

# Print test summary
print_summary() {
  local total_assertions=$((TESTS_PASSED + TESTS_FAILED))
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf '%b\n' "Test cases: $TESTS_RUN | Assertions: $total_assertions"
  printf '%b\n' "${GREEN}Passed: $TESTS_PASSED${NC}"
  printf '%b\n' "${RED}Failed: $TESTS_FAILED${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  # Output machine-readable results for test_runner.sh (assertions are the unit of pass/fail)
  echo "RESULTS:$total_assertions:$TESTS_PASSED:$TESTS_FAILED"

  if [[ $TESTS_FAILED -gt 0 ]]; then
    return 1
  fi
  return 0
}

# Alias for print_summary
test_summary() {
  print_summary
}
