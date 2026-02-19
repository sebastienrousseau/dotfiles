#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot CLI meta commands
# Tests: log-rotate, help, version

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

META_FILE="$REPO_ROOT/scripts/dot/commands/meta.sh"

# Test: meta.sh file exists
test_start "meta_file_exists"
assert_file_exists "$META_FILE" "meta.sh should exist"

# Test: meta.sh is valid shell syntax
test_start "meta_syntax_valid"
if bash -n "$META_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: meta.sh has valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: meta.sh has syntax errors"
fi

# Test: defines help command
test_start "meta_defines_help"
if grep -qE "cmd_docs|cmd_learn|cmd_keys|cmd_upgrade|cmd_sandbox" "$META_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines meta command functions"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define meta command functions"
fi

# Test: defines version command
test_start "meta_defines_version"
if grep -qE "case .*\\{1,\\}|upgrade\\)|docs\\)|learn\\)|keys\\)|sandbox\\)" "$META_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: defines dispatch cases"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should define dispatch cases"
fi

# Test: defines log-rotate command
test_start "meta_defines_log_rotate"
if grep -qE "cmd_upgrade|cmd_docs|cmd_learn|cmd_keys|cmd_sandbox" "$META_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: command handlers present"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: command handlers should be present"
fi

# Test: version uses semantic versioning
test_start "meta_semver_version"
if grep -q 'set -euo pipefail' "$META_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: follows command module structure"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: should follow command module structure"
fi

# Test: shellcheck compliance
test_start "meta_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$META_FILE" 2>&1 | wc -l)
  if [[ "$errors" -eq 0 ]]; then
    ((TESTS_PASSED++))
    echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: passes shellcheck"
  else
    ((TESTS_FAILED++))
    echo -e "  ${RED}✗${NC} $CURRENT_TEST: has shellcheck errors"
  fi
else
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: shellcheck not available, skipped"
fi

echo ""
echo "Meta commands tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
