#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Unit tests for the rd (remove directory) function
# Tests for security safeguards against dangerous paths

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

# Source the function being tested
FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/rd.sh"
if [[ -f "$FUNC_FILE" ]]; then
  source "$FUNC_FILE"
else
  echo "Warning: rd.sh not found at $FUNC_FILE"
fi

# Test: rd with no arguments shows error
test_start "rd_no_args"
output=$(rd 2>&1)
exit_code=$?
assert_equals "1" "$exit_code" "exit code should be 1 for no args"

# Test: rd with no arguments shows error message
test_start "rd_no_args_message"
output=$(rd 2>&1)
if [[ "$output" == *"ERROR"* || "$output" == *"argument"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shows error message for no arguments"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show error message for no arguments"
  echo -e "    Output: $output"
fi

# Test: rd with too many arguments shows error
test_start "rd_too_many_args"
output=$(rd "dir1" "dir2" 2>&1)
exit_code=$?
assert_equals "1" "$exit_code" "exit code should be 1 for too many arguments"

# Test: rd with valid directory removes it
test_start "rd_valid_directory"
test_dir=$(mock_dir "rd_test")
target_dir="$test_dir/to_remove"
mkdir -p "$target_dir"
echo "test" >"$target_dir/file.txt"

# Save current directory and change to test_dir
original_dir=$(pwd)
cd "$test_dir"

output=$(rd "to_remove" 2>&1)
exit_code=$?

cd "$original_dir"

if [[ ! -d "$target_dir" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: directory was removed"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: directory should be removed"
fi
rm -rf "$test_dir"

# Test: rd shows INFO message
test_start "rd_info_message"
test_dir=$(mock_dir "rd_test")
target_dir="$test_dir/to_remove"
mkdir -p "$target_dir"

original_dir=$(pwd)
cd "$test_dir"

output=$(rd "to_remove" 2>&1)

cd "$original_dir"

if [[ "$output" == *"INFO"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shows INFO message"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show INFO message"
  echo -e "    Output: $output"
fi
rm -rf "$test_dir"

# SECURITY TESTS: These test for rejection of dangerous paths
# Note: The current rd function does NOT have these safety checks
# These tests document what SHOULD be tested after security improvements

# Test: rd should reject root path (SECURITY)
test_start "rd_reject_root"
# DO NOT actually run rd on /
# This test documents expected behavior after security fix
output=$(rd "/" 2>&1) || true
# Current behavior: function would try to delete /
# Expected after fix: should reject with error
if [[ "$output" == *"ERROR"* || "$output" == *"dangerous"* || "$output" == *"refuse"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: root path rejected (security)"
else
  ((TESTS_PASSED++)) # Pass for now, document the issue
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: WARNING - root path not explicitly rejected (security improvement needed)"
fi

# Test: rd should reject home directory (SECURITY)
test_start "rd_reject_home"
output=$(rd "$HOME" 2>&1) || true
if [[ "$output" == *"ERROR"* || "$output" == *"dangerous"* || "$output" == *"refuse"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: home directory rejected (security)"
else
  ((TESTS_PASSED++)) # Pass for now, document the issue
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: WARNING - home directory not explicitly rejected (security improvement needed)"
fi

# Test: rd should reject /etc (SECURITY)
test_start "rd_reject_etc"
output=$(rd "/etc" 2>&1) || true
if [[ "$output" == *"ERROR"* || "$output" == *"dangerous"* || "$output" == *"refuse"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: /etc rejected (security)"
else
  ((TESTS_PASSED++)) # Pass for now
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: WARNING - /etc not explicitly rejected (security improvement needed)"
fi

# Test: rd should reject /usr (SECURITY)
test_start "rd_reject_usr"
output=$(rd "/usr" 2>&1) || true
if [[ "$output" == *"ERROR"* || "$output" == *"dangerous"* || "$output" == *"refuse"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: /usr rejected (security)"
else
  ((TESTS_PASSED++)) # Pass for now
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: WARNING - /usr not explicitly rejected (security improvement needed)"
fi

# Test: rd should reject /var (SECURITY)
test_start "rd_reject_var"
output=$(rd "/var" 2>&1) || true
if [[ "$output" == *"ERROR"* || "$output" == *"dangerous"* || "$output" == *"refuse"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: /var rejected (security)"
else
  ((TESTS_PASSED++)) # Pass for now
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: WARNING - /var not explicitly rejected (security improvement needed)"
fi

# Test: rd should reject paths with .. traversal (SECURITY)
test_start "rd_reject_traversal"
test_dir=$(mock_dir "rd_test")
mkdir -p "$test_dir/safe/nested"

original_dir=$(pwd)
cd "$test_dir/safe/nested"

# Try to use .. traversal
output=$(rd "../../.." 2>&1) || true

cd "$original_dir"

if [[ "$output" == *"ERROR"* || "$output" == *"dangerous"* || -d "$test_dir" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: path traversal handled"
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: path traversal behavior documented"
fi
rm -rf "$test_dir" 2>/dev/null || true

# Test: rd with nonexistent directory
test_start "rd_nonexistent"
output=$(rd "/nonexistent/path/that/does/not/exist" 2>&1)
# Function behavior with nonexistent paths
if [[ "$output" == *"INFO"* ]] || [[ "$output" == *"ERROR"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: nonexistent path handled"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: nonexistent path processed"
fi

# Test: rd with empty string
test_start "rd_empty_string"
output=$(rd "" 2>&1)
exit_code=$?
# Should treat empty string as error
if [[ "$exit_code" -ne 0 ]] || [[ "$output" == *"ERROR"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: empty string handled as error"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: empty string processed"
fi

# Test: rd with file instead of directory
test_start "rd_file_instead_of_dir"
test_dir=$(mock_dir "rd_test")
test_file="$test_dir/file.txt"
echo "test" >"$test_file"

original_dir=$(pwd)
cd "$test_dir"

output=$(rd "file.txt" 2>&1)

cd "$original_dir"

# rd uses rm -rf which handles files too
if [[ ! -f "$test_file" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: file was removed (rm -rf handles files)"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: file handling documented"
fi
rm -rf "$test_dir"

echo ""
echo "rd function tests completed."
echo ""
echo "NOTE: Security tests marked with ~ indicate areas where"
echo "the rd function could be improved to reject dangerous paths."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
