#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

HELPER_FILE="$REPO_ROOT/install/helpers/hide_menu_entries.sh"

test_start "helper_exists"
assert_file_exists "$HELPER_FILE" "helper should exist"

test_start "helper_valid_syntax"
if bash -n "$HELPER_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)); echo -e "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)); echo -e "  ${RED}✗${NC} $CURRENT_TEST"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
