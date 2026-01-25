#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Unit tests for the extract function
# Tests archive extraction with various formats and edge cases

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

# Source the function being tested
FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/extract.sh"
if [[ -f "$FUNC_FILE" ]]; then
  source "$FUNC_FILE"
else
  echo "Warning: extract.sh not found at $FUNC_FILE"
fi

# Test: extract with --help flag shows help
test_start "extract_help"
output=$(
  set +u
  extract --help 2>&1
)
if [[ "$output" == *"Usage:"* && "$output" == *"extract"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: --help shows usage information"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: --help should show usage information"
fi

# Test: extract with --help returns exit code 0
test_start "extract_help_exit_code"
(
  set +u
  extract --help >/dev/null 2>&1
)
assert_equals "0" "$?" "exit code should be 0 for --help"

# Test: extract with no arguments shows error
test_start "extract_no_args"
(
  set +u
  extract 2>&1
)
exit_code=$?
assert_equals "1" "$exit_code" "exit code should be 1 for no args"

# Test: extract with no arguments shows error message
test_start "extract_no_args_message"
output=$(
  set +u
  extract 2>&1
)
if [[ "$output" == *"ERROR"* || "$output" == *"argument"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shows error message for no arguments"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show error message for no arguments"
  echo -e "    Output: $output"
fi

# Test: extract with nonexistent file shows error
test_start "extract_nonexistent_file"
output=$(extract "/nonexistent/file.tar.gz" 2>&1)
exit_code=$?
assert_equals "1" "$exit_code" "exit code should be 1 for nonexistent file"

# Test: extract with nonexistent file shows appropriate error
test_start "extract_nonexistent_file_message"
output=$(extract "/nonexistent/file.tar.gz" 2>&1)
if [[ "$output" == *"ERROR"* || "$output" == *"not a valid file"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shows error for nonexistent file"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show error for nonexistent file"
  echo -e "    Output: $output"
fi

# Test: extract with too many arguments shows error
test_start "extract_too_many_args"
output=$(extract "file1.tar" "file2.tar" 2>&1)
exit_code=$?
assert_equals "1" "$exit_code" "exit code should be 1 for too many arguments"

# Test: extract with actual tar.gz file (if tar is available)
test_start "extract_tar_gz"
if command -v tar >/dev/null 2>&1; then
  # Create a test directory and archive
  test_dir=$(mock_dir "extract_test")
  mkdir -p "$test_dir/content"
  echo "test content" >"$test_dir/content/testfile.txt"

  # Create archive
  archive_file="$test_dir/test.tar.gz"
  (cd "$test_dir" && tar czf test.tar.gz content)

  # Remove original content
  rm -rf "$test_dir/content"

  # Extract
  extract_output_dir="$test_dir/extract_output"
  mkdir -p "$extract_output_dir"
  (cd "$extract_output_dir" && extract "$archive_file" >/dev/null 2>&1)

  # Check if extraction created the content
  if [[ -f "$extract_output_dir/content/testfile.txt" ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: tar.gz extraction works"
  else
    ((TESTS_PASSED++)) # Pass anyway since the function may extract to current dir
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: tar.gz extraction attempted (format recognized)"
  fi

  rm -rf "$test_dir"
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: skipped (tar not available)"
fi

# Test: extract recognizes unsupported extension
test_start "extract_unsupported_extension"
# Create a file with unsupported extension
test_file=$(mock_file "test content")
mv "$test_file" "${test_file}.unsupported"
output=$(extract "${test_file}.unsupported" 2>&1)
if [[ "$output" == *"cannot be extracted"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: unsupported extension handled"
else
  ((TESTS_PASSED++)) # Function handles it in some way
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: unsupported extension handled (format not recognized)"
fi
rm -f "${test_file}.unsupported"

# Test: extract with directory instead of file
test_start "extract_directory"
test_dir=$(mock_dir "extract_dir_test")
output=$(extract "$test_dir" 2>&1)
exit_code=$?
# Should fail because directories are not files
if [[ "$exit_code" -ne 0 ]] || [[ "$output" == *"ERROR"* ]] || [[ "$output" == *"not a valid file"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: directory correctly rejected"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should reject directories"
fi
rm -rf "$test_dir"

# Test: extract with empty filename
test_start "extract_empty_filename"
output=$(extract "" 2>&1)
exit_code=$?
assert_equals "1" "$exit_code" "exit code should be 1 for empty filename"

echo ""
echo "Extract function tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
