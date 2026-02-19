#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/demo/record.sh"

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "demo record script should exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: syntax is valid"
else
  ((TESTS_FAILED++))
  echo -e "  ${RED}✗${NC} $CURRENT_TEST: syntax is invalid"
fi

test_start "script_has_output_message"
assert_output_contains "Saved demo to" "cat \"$SCRIPT_FILE\""

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
