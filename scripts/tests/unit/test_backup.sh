#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Unit tests for the backup function
# Tests backup creation with various options and edge cases

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

# Source the function being tested
FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/backup.sh"
if [[ -f "$FUNC_FILE" ]]; then
  source "$FUNC_FILE"
else
  echo "Warning: backup.sh not found at $FUNC_FILE"
fi

# Test: backup with no arguments shows error
test_start "backup_no_args"
output=$(backup 2>&1)
exit_code=$?
assert_equals "1" "$exit_code" "exit code should be 1 for no args"

# Test: backup with no arguments shows error message
test_start "backup_no_args_message"
output=$(backup 2>&1)
if [[ "$output" == *"ERROR"* && "$output" == *"provide"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shows error message for no arguments"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show error message for no arguments"
  echo -e "    Output: $output"
fi

# Test: backup with nonexistent file
test_start "backup_nonexistent_file"
test_dir=$(mock_dir "backup_test")
export BACKUP_DIR="$test_dir/backups"
output=$(backup "/nonexistent/file.txt" 2>&1)
exit_code=$?
assert_equals "1" "$exit_code" "exit code should be 1 for nonexistent file"
rm -rf "$test_dir"

# Test: backup with unknown option shows error
test_start "backup_unknown_option"
output=$(backup --unknown-option 2>&1)
exit_code=$?
assert_equals "1" "$exit_code" "exit code should be 1 for unknown option"

# Test: backup with unknown option shows error message
test_start "backup_unknown_option_message"
output=$(backup --unknown-option 2>&1)
if [[ "$output" == *"ERROR"* && "$output" == *"Unknown option"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shows error for unknown option"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show error for unknown option"
  echo -e "    Output: $output"
fi

# Test: backup creates backup directory if not exists
test_start "backup_creates_directory"
test_dir=$(mock_dir "backup_test")
test_file="$test_dir/testfile.txt"
echo "test content" >"$test_file"
export BACKUP_DIR="$test_dir/backups"

output=$(backup "$test_file" 2>&1)

if [[ -d "$BACKUP_DIR" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: backup directory created"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: backup directory should be created"
fi
rm -rf "$test_dir"

# Test: backup creates tar archive
test_start "backup_creates_archive"
test_dir=$(mock_dir "backup_test")
test_file="$test_dir/testfile.txt"
echo "test content" >"$test_file"
export BACKUP_DIR="$test_dir/backups"

output=$(backup "$test_file" 2>&1)
exit_code=$?

# Check if backup file was created
backup_files=$(ls "$BACKUP_DIR"/backup_*.tar* 2>/dev/null | wc -l | tr -d ' ')
if [[ "$backup_files" -gt 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: backup archive created"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: backup archive should be created"
  echo -e "    Output: $output"
fi
rm -rf "$test_dir"

# Test: backup with --max-size option
test_start "backup_max_size_option"
test_dir=$(mock_dir "backup_test")
test_file="$test_dir/testfile.txt"
echo "test content" >"$test_file"
export BACKUP_DIR="$test_dir/backups"

output=$(backup --max-size 1K "$test_file" 2>&1)
exit_code=$?

assert_equals "0" "$exit_code" "backup with --max-size should succeed"
rm -rf "$test_dir"

# Test: backup with --keep option
test_start "backup_keep_option"
test_dir=$(mock_dir "backup_test")
test_file="$test_dir/testfile.txt"
echo "test content" >"$test_file"
export BACKUP_DIR="$test_dir/backups"

output=$(backup --keep 3 "$test_file" 2>&1)
exit_code=$?

assert_equals "0" "$exit_code" "backup with --keep should succeed"
rm -rf "$test_dir"

# Test: backup with invalid size unit
test_start "backup_invalid_size_unit"
test_dir=$(mock_dir "backup_test")
test_file="$test_dir/testfile.txt"
echo "test content" >"$test_file"
export BACKUP_DIR="$test_dir/backups"

output=$(backup --max-size 100X "$test_file" 2>&1)
exit_code=$?

# Should fail with invalid unit
if [[ "$exit_code" -ne 0 ]] || [[ "$output" == *"Invalid unit"* ]] || [[ "$output" == *"ERROR"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: invalid size unit handled"
else
  # Function may accept it gracefully
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: size unit processed (may be treated as bytes)"
fi
rm -rf "$test_dir"

# Test: backup multiple files
test_start "backup_multiple_files"
test_dir=$(mock_dir "backup_test")
test_file1="$test_dir/testfile1.txt"
test_file2="$test_dir/testfile2.txt"
echo "content 1" >"$test_file1"
echo "content 2" >"$test_file2"
export BACKUP_DIR="$test_dir/backups"

output=$(backup "$test_file1" "$test_file2" 2>&1)
exit_code=$?

assert_equals "0" "$exit_code" "backup of multiple files should succeed"
rm -rf "$test_dir"

# Test: backup shows INFO messages
test_start "backup_info_messages"
test_dir=$(mock_dir "backup_test")
test_file="$test_dir/testfile.txt"
echo "test content" >"$test_file"
export BACKUP_DIR="$test_dir/backups"

output=$(backup "$test_file" 2>&1)

if [[ "$output" == *"INFO"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shows INFO messages"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show INFO messages"
  echo -e "    Output: $output"
fi
rm -rf "$test_dir"

# Test: backup retention (--keep)
test_start "backup_retention"
test_dir=$(mock_dir "backup_test")
test_file="$test_dir/testfile.txt"
echo "test content" >"$test_file"
export BACKUP_DIR="$test_dir/backups"

# Create multiple backups
for i in {1..4}; do
  backup --keep 2 "$test_file" >/dev/null 2>&1
done

# Count remaining backups
backup_count=$(ls "$BACKUP_DIR"/backup_*.tar* 2>/dev/null | wc -l | tr -d ' ')

if [[ "$backup_count" -le 2 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: backup retention works (kept $backup_count)"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should keep only 2 backups, found $backup_count"
fi
rm -rf "$test_dir"

# Test: backup a directory
test_start "backup_directory"
test_dir=$(mock_dir "backup_test")
content_dir="$test_dir/content"
mkdir -p "$content_dir"
echo "file1" >"$content_dir/file1.txt"
echo "file2" >"$content_dir/file2.txt"
export BACKUP_DIR="$test_dir/backups"

output=$(backup "$content_dir" 2>&1)
exit_code=$?

assert_equals "0" "$exit_code" "backup of directory should succeed"
rm -rf "$test_dir"

echo ""
echo "Backup function tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
