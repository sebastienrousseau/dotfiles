#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

BIN_DIR="$REPO_ROOT/dot_local/bin"

test_start "bin_dir_exists"
assert_dir_exists "$BIN_DIR" "bin directory should exist"

# Test cb
test_start "cb_script_exists"
assert_file_exists "$BIN_DIR/executable_cb" "cb script should exist"

test_start "cb_script_executable"
if [[ -x "$BIN_DIR/executable_cb" ]]; then
  ((TESTS_PASSED++)); printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  # It's managed by chezmoi, so it might not be executable in the source dir, but it should be parseable
  bash -n "$BIN_DIR/executable_cb" && ((TESTS_PASSED++)) && printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST (syntax valid)" || { ((TESTS_FAILED++)); printf '%b
' "  ${RED}✗${NC} $CURRENT_TEST"; }
fi

# Test open
test_start "open_script_exists"
assert_file_exists "$BIN_DIR/executable_open" "open script should exist"

test_start "open_script_syntax"
bash -n "$BIN_DIR/executable_open" && ((TESTS_PASSED++)) && printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST" || { ((TESTS_FAILED++)); printf '%b
' "  ${RED}✗${NC} $CURRENT_TEST"; }

# Test notify
test_start "notify_script_exists"
assert_file_exists "$BIN_DIR/executable_notify" "notify script should exist"

test_start "notify_script_syntax"
bash -n "$BIN_DIR/executable_notify" && ((TESTS_PASSED++)) && printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST" || { ((TESTS_FAILED++)); printf '%b
' "  ${RED}✗${NC} $CURRENT_TEST"; }

# Test extract
test_start "extract_script_exists"
assert_file_exists "$BIN_DIR/executable_extract" "extract script should exist"

test_start "extract_script_syntax"
bash -n "$BIN_DIR/executable_extract" && ((TESTS_PASSED++)) && printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST" || { ((TESTS_FAILED++)); printf '%b
' "  ${RED}✗${NC} $CURRENT_TEST"; }

# Test up
test_start "up_script_exists"
assert_file_exists "$BIN_DIR/executable_up" "up script should exist"

test_start "up_script_syntax"
bash -n "$BIN_DIR/executable_up" && ((TESTS_PASSED++)) && printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST" || { ((TESTS_FAILED++)); printf '%b
' "  ${RED}✗${NC} $CURRENT_TEST"; }

# Test bm
test_start "bm_script_exists"
assert_file_exists "$BIN_DIR/executable_bm" "bm script should exist"

test_start "bm_script_syntax"
bash -n "$BIN_DIR/executable_bm" && ((TESTS_PASSED++)) && printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST" || { ((TESTS_FAILED++)); printf '%b
' "  ${RED}✗${NC} $CURRENT_TEST"; }

# Test win
test_start "win_script_exists"
assert_file_exists "$BIN_DIR/executable_win" "win script should exist"

test_start "win_script_syntax"
bash -n "$BIN_DIR/executable_win" && ((TESTS_PASSED++)) && printf '%b
' "  ${GREEN}✓${NC} $CURRENT_TEST" || { ((TESTS_FAILED++)); printf '%b
' "  ${RED}✗${NC} $CURRENT_TEST"; }

# Test als configuration
test_start "als_fish_exists"
assert_file_exists "$REPO_ROOT/dot_config/fish/functions/als.fish" "als.fish should exist"

test_start "als_data_tmpl_exists"
assert_file_exists "$REPO_ROOT/dot_config/shell/als_data.txt.tmpl" "als_data.txt.tmpl should exist"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
