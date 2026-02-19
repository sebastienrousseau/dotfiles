#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for dot verify diagnostics script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

VERIFY_FILE="$REPO_ROOT/scripts/diagnostics/verify.sh"

test_start "verify_command_file_exists"
assert_file_exists "$VERIFY_FILE" "verify.sh should exist"

test_start "verify_command_syntax_valid"
if bash -n "$VERIFY_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

test_start "verify_runs_dot_doctor"
assert_file_contains "$VERIFY_FILE" "run_step \"dot doctor\"" "should run dot doctor"

test_start "verify_runs_dot_status"
assert_file_contains "$VERIFY_FILE" "run_step \"dot status\"" "should run dot status"

test_start "verify_runs_chezmoi_diff"
assert_file_contains "$VERIFY_FILE" "chezmoi diff" "should run chezmoi diff"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
