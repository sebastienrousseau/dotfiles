#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for function templates

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

FUNCS_DIR="$REPO_ROOT/.chezmoitemplates/functions"

# Test: functions directory exists
test_start "functions_dir_exists"
assert_dir_exists "$FUNCS_DIR" "functions directory should exist"

# Test: count function files
test_start "functions_file_count"
count=$(find "$FUNCS_DIR" -name "*.sh" 2>/dev/null | wc -l)
if [[ "$count" -gt 5 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: found $count function files"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: expected >5 function files, found $count"
fi

# Test: all function files have valid syntax
test_start "functions_all_valid_syntax"
invalid=0
for script in $(find "$FUNCS_DIR" -name "*.sh" 2>/dev/null); do
  if ! bash -n "$script" 2>/dev/null; then
    ((invalid++))
  fi
done
if [[ "$invalid" -eq 0 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: all function files valid"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: $invalid files invalid"
fi

# Test: backup.sh function exists
test_start "functions_backup_exists"
if [[ -f "$FUNCS_DIR/backup.sh" ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: backup.sh exists"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: backup.sh should exist"
fi

# Test: functions define actual functions
test_start "functions_define_funcs"
defined=0
for script in $(find "$FUNCS_DIR" -name "*.sh" 2>/dev/null | head -10); do
  if grep -qE '^[a-z_]+\(\)\s*\{' "$script" 2>/dev/null; then
    ((defined++))
  fi
done
if [[ "$defined" -gt 3 ]]; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: $defined files define functions"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: only $defined define functions"
fi

# Test: no hardcoded paths
test_start "functions_no_hardcoded"
if grep -rqE '"/home/[a-z]+' "$FUNCS_DIR"/*.sh 2>/dev/null; then
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: has hardcoded paths"
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: no hardcoded paths"
fi

echo ""
echo "Functions templates tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
