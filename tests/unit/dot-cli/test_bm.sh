#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Tests for bookmark manager (executable_bm)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BM_FILE="$REPO_ROOT/dot_local/bin/executable_bm"

test_start "script_exists"
assert_file_exists "$BM_FILE" "executable_bm should exist"

test_start "valid_syntax"
if sh -n "$BM_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "shows_usage_with_no_args"
assert_file_contains "$BM_FILE" 'Usage: bm' "should show usage info"

test_start "add_creates_bookmark"
assert_file_contains "$BM_FILE" 'echo "$name $(pwd)" >>"$BOOKMARKS_FILE"' "add should append to bookmarks file"

test_start "list_shows_bookmarks"
assert_file_contains "$BM_FILE" 'list)' "should have list action"

test_start "remove_deletes_entry"
assert_file_contains "$BM_FILE" 'remove)' "should have remove action"

test_start "update_replaces_entry"
assert_file_contains "$BM_FILE" 'update)' "should have update action"

test_start "goto_outputs_path"
assert_file_contains "$BM_FILE" 'goto)' "should have goto action"

test_start "error_on_missing_bookmark"
assert_file_contains "$BM_FILE" "not found or invalid directory" "should error on missing bookmark"

test_start "cross_platform_sed_helper"
assert_file_contains "$BM_FILE" '_sed_i()' "should define cross-platform _sed_i helper"

test_start "no_sed_i_bak_residue"
# Ensure no bare sed -i.bak calls remain
if grep -q 'sed -i\.bak' "$BM_FILE"; then
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should not have sed -i.bak calls"
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no sed -i.bak calls found"
fi

test_start "uses_sed_i_helper"
# sed operations should use _sed_i instead of bare sed -i
if grep -c '_sed_i' "$BM_FILE" | grep -q '[2-9]'; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: uses _sed_i helper for sed operations"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should use _sed_i helper in multiple places"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
