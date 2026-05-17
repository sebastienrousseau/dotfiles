#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/tools/docs/check-manual.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "check-manual.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "validates_structure"
assert_file_contains "$SCRIPT_FILE" "check_structure" "must validate directory structure"

test_start "validates_links"
assert_file_contains "$SCRIPT_FILE" "check_links" "must validate internal links"

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
