#!/usr/bin/env bash
# shellcheck disable=SC2034
# Assertion library for shell tests
# Provides a comprehensive set of assertion functions for testing shell scripts
#
# Security note: This file uses eval to execute test commands and conditions.
# This is intentional and necessary for the test assertion framework to work.
# These functions are only used in test code and should never be called with
# untrusted input. All eval calls carry a shellcheck disable directive.

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
CURRENT_TEST=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

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
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    echo -e "    Expected: '$expected'"
    echo -e "    Actual:   '$actual'"
    return 1
  fi
}

# Assert two values are not equal
assert_not_equals() {
  local unexpected="$1" actual="$2" msg="${3:-values should differ}"
  if [[ "$unexpected" != "$actual" ]]; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    echo -e "    Unexpected: '$unexpected'"
    echo -e "    Actual:     '$actual'"
    return 1
  fi
}

# Assert a command exits with expected code
assert_exit_code() {
  local expected="$1"
  shift
  local cmd="$*"
  local actual
  set +e
  # shellcheck disable=SC2086
  eval "$cmd" </dev/null >/dev/null 2>&1
  actual=$?
  set -e
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
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: output contains '$needle'"
    return 0
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: output should contain '$needle'"
    echo -e "    Actual output: $output"
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
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: output does not contain '$needle'"
    return 0
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: output should not contain '$needle'"
    echo -e "    Actual output: $output"
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
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: output matches pattern '$pattern'"
    return 0
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: output should match pattern '$pattern'"
    echo -e "    Actual output: $output"
    return 1
  fi
}

# Assert file exists
assert_file_exists() {
  local file="$1" msg="${2:-file should exist}"
  if [[ -f "$file" ]]; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: $msg ($file not found)"
    return 1
  fi
}

# Assert file does not exist
assert_file_not_exists() {
  local file="$1" msg="${2:-file should not exist}"
  if [[ ! -f "$file" ]]; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: $msg ($file exists)"
    return 1
  fi
}

# Assert directory exists
assert_dir_exists() {
  local dir="$1" msg="${2:-directory should exist}"
  if [[ -d "$dir" ]]; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: $msg ($dir not found)"
    return 1
  fi
}

# Assert directory does not exist
assert_dir_not_exists() {
  local dir="$1" msg="${2:-directory should not exist}"
  if [[ ! -d "$dir" ]]; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: $msg ($dir exists)"
    return 1
  fi
}

# Assert a condition is true
assert_true() {
  local condition="$1" msg="${2:-condition should be true}"
  # shellcheck disable=SC2086
  if eval "$condition"; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    return 1
  fi
}

# Assert a condition is false
assert_false() {
  local condition="$1" msg="${2:-condition should be false}"
  # shellcheck disable=SC2086
  if ! eval "$condition"; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    return 1
  fi
}

# Assert string is empty
assert_empty() {
  local value="$1" msg="${2:-value should be empty}"
  if [[ -z "$value" ]]; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    echo -e "    Actual: '$value'"
    return 1
  fi
}

# Assert string is not empty
assert_not_empty() {
  local value="$1" msg="${2:-value should not be empty}"
  if [[ -n "$value" ]]; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    return 1
  fi
}

# Assert file contains text
assert_file_contains() {
  local file="$1" needle="$2" msg="${3:-file should contain text}"
  if [[ -f "$file" ]] && grep -q "$needle" "$file"; then
    ((TESTS_PASSED++)) || true
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: $msg"
    return 0
  else
    ((TESTS_FAILED++)) || true
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: $msg"
    return 1
  fi
}

# Print test summary
print_summary() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "Tests run: $TESTS_RUN"
  echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
  echo -e "${RED}Failed: $TESTS_FAILED${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  # Output machine-readable results for test_runner.sh
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"

  if [[ $TESTS_FAILED -gt 0 ]]; then
    return 1
  fi
  return 0
}
