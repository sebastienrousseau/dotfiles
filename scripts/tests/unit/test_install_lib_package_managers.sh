#!/usr/bin/env bash
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

LIB_FILE="$REPO_ROOT/install/lib/package_managers.sh"

test_start "lib_exists"
assert_file_exists "$LIB_FILE" "package_managers.sh should exist"

test_start "lib_valid_syntax"
if bash -n "$LIB_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)); echo -e "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)); echo -e "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "lib_shellcheck"
if command -v shellcheck &>/dev/null; then
  errors=$(shellcheck -S error "$LIB_FILE" 2>&1 | wc -l)
  [[ "$errors" -eq 0 ]] && { ((TESTS_PASSED++)); echo -e "  ${GREEN}✓${NC} $CURRENT_TEST"; } || { ((TESTS_FAILED++)); echo -e "  ${RED}✗${NC} $CURRENT_TEST"; }
else
  ((TESTS_PASSED++)); echo -e "  ${GREEN}✓${NC} $CURRENT_TEST: skipped"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
