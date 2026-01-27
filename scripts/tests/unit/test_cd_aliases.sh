#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for cd aliases and navigation functions
# Tests directory navigation, bookmarks, and helper functions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

# Source the aliases file being tested
ALIAS_FILE="$REPO_ROOT/.chezmoitemplates/aliases/cd/cd.aliases.sh"
if [[ -f "$ALIAS_FILE" ]]; then
  # Reset some variables to avoid side effects
  RESTORE_LAST_DIR=false
  AUTO_LIST_AFTER_CD=false
  source "$ALIAS_FILE"
else
  echo "Warning: cd.aliases.sh not found at $ALIAS_FILE"
fi

# Test: safe_write_file function exists
test_start "safe_write_file_exists"
if declare -f safe_write_file >/dev/null 2>&1; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: safe_write_file function exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: safe_write_file function should exist"
fi

# Test: safe_write_file creates file
test_start "safe_write_file_creates"
if declare -f safe_write_file >/dev/null 2>&1; then
  test_dir=$(mock_dir "cd_test")
  test_file="$test_dir/test_file.txt"
  safe_write_file "$test_file" "test content"

  if [[ -f "$test_file" ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: safe_write_file creates file"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: file should be created"
  fi
  rm -rf "$test_dir"
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: skipped (function not available)"
fi

# Test: safe_write_file writes content
test_start "safe_write_file_content"
if declare -f safe_write_file >/dev/null 2>&1; then
  test_dir=$(mock_dir "cd_test")
  test_file="$test_dir/test_file.txt"
  safe_write_file "$test_file" "expected content"

  content=$(cat "$test_file" 2>/dev/null)
  if [[ "$content" == "expected content" ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: correct content written"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: content should match"
  fi
  rm -rf "$test_dir"
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: skipped (function not available)"
fi

# Test: safe_write_file append mode
test_start "safe_write_file_append"
if declare -f safe_write_file >/dev/null 2>&1; then
  test_dir=$(mock_dir "cd_test")
  test_file="$test_dir/test_file.txt"
  safe_write_file "$test_file" "line1"
  safe_write_file "$test_file" "line2" "a"

  line_count=$(wc -l <"$test_file" | tr -d ' ')
  if [[ "$line_count" -eq 2 ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: append mode works"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: should have 2 lines"
  fi
  rm -rf "$test_dir"
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: skipped (function not available)"
fi

# Test: count_dir_items function exists
test_start "count_dir_items_exists"
if declare -f count_dir_items >/dev/null 2>&1; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: count_dir_items function exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: count_dir_items function should exist"
fi

# Test: count_dir_items counts correctly
test_start "count_dir_items_count"
if declare -f count_dir_items >/dev/null 2>&1; then
  test_dir=$(mock_dir "cd_test")
  touch "$test_dir/file1.txt"
  touch "$test_dir/file2.txt"
  touch "$test_dir/file3.txt"

  count=$(count_dir_items "$test_dir")
  if [[ "$count" -eq 3 ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: counts 3 items correctly"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: should count 3, got $count"
  fi
  rm -rf "$test_dir"
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: skipped (function not available)"
fi

# Test: mkcd function exists
test_start "mkcd_exists"
if declare -f mkcd >/dev/null 2>&1; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: mkcd function exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: mkcd function should exist"
fi

# Test: mkcd with no arguments shows error
test_start "mkcd_no_args"
if declare -f mkcd >/dev/null 2>&1; then
  output=$(mkcd 2>&1)
  exit_code=$?
  if [[ "$exit_code" -eq 1 ]] || [[ "$output" == *"Usage"* ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: mkcd shows usage with no args"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show usage"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: skipped (function not available)"
fi

# Test: mkcd creates directory
test_start "mkcd_creates_dir"
if declare -f mkcd >/dev/null 2>&1; then
  test_dir=$(mock_dir "cd_test")
  new_dir="$test_dir/new_directory"

  (mkcd "$new_dir" >/dev/null 2>&1)

  if [[ -d "$new_dir" ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: mkcd creates directory"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: directory should be created"
  fi
  rm -rf "$test_dir"
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: skipped (function not available)"
fi

# Test: bookmark function exists
test_start "bookmark_exists"
if declare -f bookmark >/dev/null 2>&1; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: bookmark function exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: bookmark function should exist"
fi

# Test: bookmark with no args shows list/usage
test_start "bookmark_no_args"
if declare -f bookmark >/dev/null 2>&1; then
  output=$(
    set +u
    bookmark 2>&1
  )
  if [[ "$output" == *"Usage"* ]] || [[ "$output" == *"bookmark"* ]] || [[ "$output" == *"No bookmarks"* ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: bookmark shows usage/list"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show usage or list"
    echo -e "    Output: $output"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: skipped (function not available)"
fi

# Test: bookmark rejects invalid names
test_start "bookmark_invalid_name"
if declare -f bookmark >/dev/null 2>&1; then
  output=$(bookmark "invalid name with spaces" 2>&1)
  exit_code=$?
  if [[ "$exit_code" -ne 0 ]] || [[ "$output" == *"Error"* ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: rejects invalid bookmark names"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: should reject invalid names"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: skipped (function not available)"
fi

# Test: goto function exists
test_start "goto_exists"
if declare -f goto >/dev/null 2>&1; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: goto function exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: goto function should exist"
fi

# Test: goto with no args shows usage
test_start "goto_no_args"
if declare -f goto >/dev/null 2>&1; then
  output=$(goto 2>&1)
  exit_code=$?
  if [[ "$exit_code" -eq 1 ]] || [[ "$output" == *"Usage"* ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: goto shows usage with no args"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show usage"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: skipped (function not available)"
fi

# Test: goto with nonexistent bookmark shows error
test_start "goto_nonexistent"
if declare -f goto >/dev/null 2>&1; then
  output=$(goto "nonexistent_bookmark_12345" 2>&1)
  exit_code=$?
  if [[ "$exit_code" -ne 0 ]] || [[ "$output" == *"not found"* ]] || [[ "$output" == *"No bookmarks"* ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: goto handles nonexistent bookmark"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: should handle nonexistent bookmark"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: skipped (function not available)"
fi

# Test: proj function exists
test_start "proj_exists"
if declare -f proj >/dev/null 2>&1; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: proj function exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: proj function should exist"
fi

# Test: cd_with_history validates directory
test_start "cd_with_history_validates"
if declare -f cd_with_history >/dev/null 2>&1; then
  output=$(cd_with_history "/nonexistent/directory" 2>&1)
  exit_code=$?
  if [[ "$exit_code" -ne 0 ]] || [[ "$output" == *"Error"* ]] || [[ "$output" == *"not found"* ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: validates directory exists"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: should validate directory"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: skipped (function not available)"
fi

# Test: cd_aliases_help function exists
test_start "cd_aliases_help_exists"
if declare -f cd_aliases_help >/dev/null 2>&1; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: cd_aliases_help function exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: cd_aliases_help function should exist"
fi

# Test: cd_aliases_help shows documentation
test_start "cd_aliases_help_output"
if declare -f cd_aliases_help >/dev/null 2>&1; then
  output=$(cd_aliases_help 2>&1)
  if [[ "$output" == *"NAVIGATION"* ]] || [[ "$output" == *"BOOKMARK"* ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: help shows documentation"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show documentation"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: skipped (function not available)"
fi

# Test: cd_aliases_version function exists
test_start "cd_aliases_version_exists"
if declare -f cd_aliases_version >/dev/null 2>&1; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: cd_aliases_version function exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: cd_aliases_version function should exist"
fi

# Test: cd_aliases_version shows version
test_start "cd_aliases_version_output"
if declare -f cd_aliases_version >/dev/null 2>&1; then
  output=$(cd_aliases_version 2>&1)
  if [[ "$output" == *"v"* ]] || [[ "$output" =~ [0-9]+\.[0-9]+ ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: version shows version number"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: should show version"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${YELLOW}~${NC} $CURRENT_TEST: skipped (function not available)"
fi

# Test: DOTFILES_VERSION is set
test_start "dotfiles_version_set"
if [[ -n "${DOTFILES_VERSION:-}" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: DOTFILES_VERSION is set ($DOTFILES_VERSION)"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: DOTFILES_VERSION should be set"
fi

# Test: OS detection works
test_start "os_detection"
if [[ -n "${DOTFILES_OS:-}" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: OS detected ($DOTFILES_OS)"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: DOTFILES_OS should be set"
fi

echo ""
echo "CD aliases tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
