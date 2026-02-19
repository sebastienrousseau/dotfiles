#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for the test framework itself (assertions.sh edge cases)
# Ensures assertion functions handle empty strings, special chars, etc.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

echo "Testing assertion framework edge cases..."

# ============ assert_equals edge cases ============

test_start "assert_equals_empty_strings"
# Both empty strings should be equal
assert_equals "" "" "empty strings should be equal"

test_start "assert_equals_special_chars"
assert_equals "hello\nworld" "hello\nworld" "strings with backslash-n should match"

test_start "assert_equals_spaces"
assert_equals "hello world" "hello world" "strings with spaces should match"

test_start "assert_equals_tabs"
assert_equals "hello	world" "hello	world" "strings with tabs should match"

# ============ assert_not_equals edge cases ============

test_start "assert_not_equals_different"
assert_not_equals "hello" "world" "different strings should not be equal"

test_start "assert_not_equals_empty_vs_nonempty"
assert_not_equals "" "hello" "empty and non-empty should differ"

# ============ assert_empty / assert_not_empty edge cases ============

test_start "assert_empty_with_empty"
assert_empty "" "empty string should be empty"

test_start "assert_not_empty_with_value"
assert_not_empty "hello" "non-empty string should not be empty"

test_start "assert_not_empty_with_space"
assert_not_empty " " "space should not be empty"

# ============ assert_file_exists / assert_file_not_exists ============

test_start "assert_file_exists_real_file"
test_file=$(mock_file "test content")
assert_file_exists "$test_file" "mock file should exist"

test_start "assert_file_not_exists_missing"
assert_file_not_exists "/nonexistent/file_99999.txt" "nonexistent file should not exist"

# ============ assert_dir_exists / assert_dir_not_exists ============

test_start "assert_dir_exists_real_dir"
test_dir=$(mock_dir "framework_test")
assert_dir_exists "$test_dir" "mock directory should exist"
rm -rf "$test_dir"

test_start "assert_dir_not_exists_missing"
assert_dir_not_exists "/nonexistent/dir_99999" "nonexistent directory should not exist"

# ============ assert_file_contains edge cases ============

test_start "assert_file_contains_literal_dots"
test_file=$(mock_file "version=1.2.3")
assert_file_contains "$test_file" "1.2.3" "should find literal dots (not regex)"

test_start "assert_file_contains_special_chars"
test_file=$(mock_file 'hello [world] (test)')
assert_file_contains "$test_file" "[world]" "should find literal brackets"

# ============ assert_exit_code edge cases ============

test_start "assert_exit_code_success"
assert_exit_code 0 "true"

test_start "assert_exit_code_failure"
assert_exit_code 1 "false"

# ============ assert_output_contains edge cases ============

test_start "assert_output_contains_simple"
assert_output_contains "hello" "echo hello world"

test_start "assert_output_contains_stderr"
assert_output_contains "error" "echo error >&2"

# ============ assert_output_not_contains ============

test_start "assert_output_not_contains_simple"
assert_output_not_contains "xyz" "echo hello world"

# ============ assert_output_matches ============

test_start "assert_output_matches_regex"
assert_output_matches "[0-9]+" "echo 'test123'"

# ============ print_summary validation ============

test_start "test_counters_consistent"
# test_start already incremented TESTS_RUN for this test, so account for it
# TESTS_RUN should equal TESTS_PASSED + TESTS_FAILED + 1 (current unresolved)
expected_total=$((TESTS_PASSED + TESTS_FAILED + 1))
assert_equals "$TESTS_RUN" "$expected_total" "TESTS_RUN should equal PASSED + FAILED + 1 (current)"

echo ""
echo "Framework edge case tests completed."
print_summary
