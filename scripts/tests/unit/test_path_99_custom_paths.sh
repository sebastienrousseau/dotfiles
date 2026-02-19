#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

PATH_FILE="$REPO_ROOT/.chezmoitemplates/paths/99-custom.paths.sh"

test_start "path_file_exists"
assert_file_exists "$PATH_FILE" "path file should exist"

test_start "path_valid_syntax"
if bash -n "$PATH_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)); echo -e "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)); echo -e "  ${RED}✗${NC} $CURRENT_TEST"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
