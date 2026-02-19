#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for case conversion functions:
#   snakecase, kebabcase, uppercase, lowercase, titlecase, sentencecase
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

FUNCS_DIR="$REPO_ROOT/.chezmoitemplates/functions"

# Source all case functions
for func_file in snakecase.sh kebabcase.sh uppercase.sh lowercase.sh titlecase.sh sentencecase.sh; do
  if [[ -f "$FUNCS_DIR/$func_file" ]]; then
    source "$FUNCS_DIR/$func_file"
  else
    echo "SKIP: $func_file not found at $FUNCS_DIR/$func_file"
  fi
done

echo "Testing case conversion functions..."

# ============ snakecase ============

test_start "snakecase_function_exists"
assert_true "type snakecase &>/dev/null" "snakecase function should exist"

test_start "snakecase_no_args"
set +e
output=$(snakecase 2>&1)
ec=$?
set -e
assert_equals "1" "$ec" "snakecase exit code should be 1 for no args"

test_start "snakecase_nonexistent_file"
set +e
output=$(snakecase "/nonexistent/file_12345.txt" 2>&1)
set -e
if [[ "$output" == *"ERROR"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: reports error for nonexistent file"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should report error for nonexistent file"
fi

test_start "snakecase_already_snake"
test_dir=$(mock_dir "case_test")
touch "$test_dir/already_snake.txt"
output=$(snakecase "$test_dir/already_snake.txt" 2>&1)
if [[ "$output" == *"already"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: skips already snake_case file"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should skip already snake_case file"
fi
rm -rf "$test_dir"

test_start "snakecase_converts"
test_dir=$(mock_dir "case_test")
touch "$test_dir/Hello World.txt"
snakecase "$test_dir/Hello World.txt" >/dev/null 2>&1
if [[ -f "$test_dir/hello_world.txt" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: converts 'Hello World.txt' to 'hello_world.txt'"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should convert to snake_case"
fi
rm -rf "$test_dir"

# ============ kebabcase ============

test_start "kebabcase_function_exists"
assert_true "type kebabcase &>/dev/null" "kebabcase function should exist"

test_start "kebabcase_no_args"
set +e
output=$(kebabcase 2>&1)
ec=$?
set -e
assert_equals "1" "$ec" "kebabcase exit code should be 1 for no args"

test_start "kebabcase_converts"
test_dir=$(mock_dir "case_test")
touch "$test_dir/Hello World.txt"
kebabcase "$test_dir/Hello World.txt" >/dev/null 2>&1
if [[ -f "$test_dir/hello-world.txt" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: converts 'Hello World.txt' to 'hello-world.txt'"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should convert to kebab-case"
fi
rm -rf "$test_dir"

# ============ uppercase ============

test_start "uppercase_function_exists"
assert_true "type uppercase &>/dev/null" "uppercase function should exist"

test_start "uppercase_no_args"
set +e
output=$(uppercase 2>&1)
ec=$?
set -e
assert_equals "1" "$ec" "uppercase exit code should be 1 for no args"

test_start "uppercase_converts"
test_dir=$(mock_dir "case_test")
touch "$test_dir/hello.txt"
uppercase "$test_dir/hello.txt" >/dev/null 2>&1
if [[ -f "$test_dir/HELLO.TXT" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: converts 'hello.txt' to 'HELLO.TXT'"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should convert to uppercase"
fi
rm -rf "$test_dir"

test_start "uppercase_already_upper"
test_dir=$(mock_dir "case_test")
touch "$test_dir/HELLO.TXT"
output=$(uppercase "$test_dir/HELLO.TXT" 2>&1)
if [[ "$output" == *"already"* ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: skips already uppercase file"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should skip already uppercase file"
fi
rm -rf "$test_dir"

# ============ lowercase ============

test_start "lowercase_function_exists"
assert_true "type lowercase &>/dev/null" "lowercase function should exist"

test_start "lowercase_no_args"
set +e
output=$(lowercase 2>&1)
ec=$?
set -e
assert_equals "1" "$ec" "lowercase exit code should be 1 for no args"

test_start "lowercase_converts"
test_dir=$(mock_dir "case_test")
touch "$test_dir/HELLO.TXT"
lowercase "$test_dir/HELLO.TXT" >/dev/null 2>&1
if [[ -f "$test_dir/hello.txt" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: converts 'HELLO.TXT' to 'hello.txt'"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should convert to lowercase"
fi
rm -rf "$test_dir"

# ============ titlecase ============

test_start "titlecase_function_exists"
assert_true "type titlecase &>/dev/null" "titlecase function should exist"

test_start "titlecase_no_args"
set +e
output=$(titlecase 2>&1)
ec=$?
set -e
assert_equals "1" "$ec" "titlecase exit code should be 1 for no args"

test_start "titlecase_converts"
test_dir=$(mock_dir "case_test")
touch "$test_dir/hello.txt"
titlecase "$test_dir/hello.txt" >/dev/null 2>&1
if [[ -f "$test_dir/Hello.txt" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: converts 'hello.txt' to 'Hello.txt'"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should convert to title case"
fi
rm -rf "$test_dir"

# ============ sentencecase ============

test_start "sentencecase_function_exists"
assert_true "type sentencecase &>/dev/null" "sentencecase function should exist"

test_start "sentencecase_no_args"
set +e
output=$(sentencecase 2>&1)
ec=$?
set -e
assert_equals "1" "$ec" "sentencecase exit code should be 1 for no args"

test_start "sentencecase_converts"
test_dir=$(mock_dir "case_test")
touch "$test_dir/hELLO.txt"
sentencecase "$test_dir/hELLO.txt" >/dev/null 2>&1
if [[ -f "$test_dir/Hello.txt" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: converts 'hELLO.txt' to 'Hello.txt'"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should convert to sentence case"
fi
rm -rf "$test_dir"

# ============ Cross-cutting: nonexistent file handling ============

test_start "case_funcs_handle_nonexistent"
all_ok=true
for func in snakecase kebabcase uppercase lowercase titlecase sentencecase; do
  if type "$func" &>/dev/null; then
    set +e
    output=$("$func" "/no/such/file_99999.txt" 2>&1)
    set -e
    if [[ "$output" != *"ERROR"* ]]; then
      all_ok=false
      echo "    $func did not report ERROR for nonexistent file"
    fi
  fi
done
if [[ "$all_ok" == true ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: all case functions report error for nonexistent files"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: some case functions did not report error"
fi

echo ""
echo "Case conversion function tests completed."
print_summary
