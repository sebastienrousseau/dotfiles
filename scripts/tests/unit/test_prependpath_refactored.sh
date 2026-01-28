#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091
# Unit tests for the refactored prependpath function (string match version)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/prependpath.sh"

echo "Testing refactored prependpath function..."

# Test: prependpath.sh has valid syntax
test_start "prependpath_syntax"
assert_exit_code 0 "bash -n '$FUNC_FILE'"

# Test: uses string match (not pipe chain)
test_start "prependpath_uses_string_match"
assert_file_contains "$FUNC_FILE" '":${PATH}:"' "should use string match pattern"

# Test: prependpath adds new directory
test_start "prependpath_adds_new"
result=$(bash -c '
  source "'"$FUNC_FILE"'"
  PATH="/usr/bin:/bin"
  prependpath "/opt/new"
  echo "$PATH"
')
if [[ "$result" == "/opt/new:/usr/bin:/bin" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: prepends new directory"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should prepend new directory"
  echo -e "    Actual: $result"
fi

# Test: prependpath does not duplicate existing directory
test_start "prependpath_no_duplicate"
result=$(bash -c '
  source "'"$FUNC_FILE"'"
  PATH="/usr/bin:/bin"
  prependpath "/usr/bin"
  echo "$PATH"
')
if [[ "$result" == "/usr/bin:/bin" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: does not duplicate existing path"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should not duplicate existing path"
  echo -e "    Actual: $result"
fi

# Test: prependpath handles path as substring correctly
test_start "prependpath_substring_not_matched"
result=$(bash -c '
  source "'"$FUNC_FILE"'"
  PATH="/usr/bin:/bin"
  prependpath "/usr/bi"
  echo "$PATH"
')
if [[ "$result" == "/usr/bi:/usr/bin:/bin" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: partial match not treated as duplicate"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: partial match should not be treated as duplicate"
  echo -e "    Actual: $result"
fi

# Test: prependpath handles empty PATH
test_start "prependpath_empty_path"
result=$(bash -c '
  source "'"$FUNC_FILE"'"
  PATH=""
  prependpath "/usr/bin"
  echo "$PATH"
')
if [[ "$result" == "/usr/bin:" ]]; then
  ((TESTS_PASSED++)) || true
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: handles empty PATH"
else
  ((TESTS_FAILED++)) || true
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should handle empty PATH"
  echo -e "    Actual: $result"
fi

print_summary
