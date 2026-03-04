#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for check-updates maintenance script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/mocks.sh"

UPDATE_SCRIPT="$REPO_ROOT/scripts/maintenance/check-updates.sh"

test_start "check_updates_script_exists"
assert_file_exists "$UPDATE_SCRIPT" "check-updates.sh should exist"

test_start "check_updates_syntax"
if bash -n "$UPDATE_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b
' "  ${RED}✗${NC} $CURRENT_TEST: syntax errors"
fi

test_start "check_updates_has_main"
assert_file_contains "$UPDATE_SCRIPT" "main()" "should define main function"

test_start "check_updates_report_dir"
assert_file_contains "$UPDATE_SCRIPT" "REPORT_DIR=" "should define report directory"

test_start "check_updates_has_github_actions_check"
assert_file_contains "$UPDATE_SCRIPT" "check_github_actions_updates" "should have github actions update check"

test_start "check_updates_has_chezmoi_check"
assert_file_contains "$UPDATE_SCRIPT" "check_chezmoi_updates" "should have chezmoi update check"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
