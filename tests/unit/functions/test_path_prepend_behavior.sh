#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioral tests for path_prepend from 00-core-paths.sh.tmpl.
# Tests idempotence, ordering, non-existent-dir skipping, and deduplication.
#
# NOTE: 00-core-paths.sh.tmpl contains Go template directives that make it
# unsuitable for direct bash-sourcing. We extract and test only the
# path_prepend function definition, which contains no template syntax.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

# Inline the path_prepend function exactly as defined in 00-core-paths.sh.tmpl
# so this test file runs without Go template expansion.
path_prepend() {
  local dir="$1"
  [[ -n "$dir" && -d "$dir" ]] || return 0
  # Remove existing entry (if any) then prepend — ensures correct precedence
  PATH="${PATH/#"$dir:"/}"        # leading
  PATH="${PATH/%":$dir"/}"        # trailing
  PATH="${PATH//":$dir:"/:}"      # middle
  [[ "$PATH" == "$dir" ]] && PATH=""  # sole entry
  PATH="$dir${PATH:+:$PATH}"
}

# Save original PATH to restore after each test.
_ORIG_PATH="$PATH"

# ──────────────────────────────────────────────────────────────────────────────
# 1. path_prepend adds a new directory to the front of PATH
# ──────────────────────────────────────────────────────────────────────────────
test_start "path_prepend_adds_new_dir"
test_dir=$(mktemp -d)
PATH="$_ORIG_PATH"
path_prepend "$test_dir"
assert_contains "$test_dir" "$PATH" "new dir should appear in PATH"
# Verify it is at the front
first_entry="${PATH%%:*}"
assert_equals "$test_dir" "$first_entry" "new dir should be first entry"
PATH="$_ORIG_PATH"
rmdir "$test_dir"

# ──────────────────────────────────────────────────────────────────────────────
# 2. Calling path_prepend twice with the same dir does not duplicate it
# ──────────────────────────────────────────────────────────────────────────────
test_start "path_prepend_idempotent_no_duplicate"
test_dir=$(mktemp -d)
PATH="/usr/bin"
path_prepend "$test_dir"
path_prepend "$test_dir"
count=$(printf '%s\n' "${PATH//:/$'\n'}" | grep -cxF "$test_dir" || true)
assert_equals "1" "$count" "same dir prepended twice should appear exactly once"
PATH="$_ORIG_PATH"
rmdir "$test_dir"

# ──────────────────────────────────────────────────────────────────────────────
# 3. path_prepend with a dir already in the middle moves it to the front
# ──────────────────────────────────────────────────────────────────────────────
test_start "path_prepend_moves_to_front"
test_dir=$(mktemp -d)
PATH="/usr/bin:$test_dir:/usr/local/bin"
path_prepend "$test_dir"
first_entry="${PATH%%:*}"
assert_equals "$test_dir" "$first_entry" "dir already in middle should move to front"
# Should not be duplicated
count=$(printf '%s\n' "${PATH//:/$'\n'}" | grep -cxF "$test_dir" || true)
assert_equals "1" "$count" "dir moved to front should not be duplicated"
PATH="$_ORIG_PATH"
rmdir "$test_dir"

# ──────────────────────────────────────────────────────────────────────────────
# 4. path_prepend skips a non-existent directory (no error, PATH unchanged)
# ──────────────────────────────────────────────────────────────────────────────
test_start "path_prepend_skips_nonexistent_dir"
PATH="/usr/bin:/bin"
saved_path="$PATH"
path_prepend "/no/such/dir/xyzzy_$$"
assert_equals "$saved_path" "$PATH" "non-existent dir should not modify PATH"

# ──────────────────────────────────────────────────────────────────────────────
# 5. path_prepend ignores an empty argument
# ──────────────────────────────────────────────────────────────────────────────
test_start "path_prepend_ignores_empty_arg"
PATH="/usr/bin"
saved_path="$PATH"
path_prepend ""
assert_equals "$saved_path" "$PATH" "empty argument should not modify PATH"

# ──────────────────────────────────────────────────────────────────────────────
# 6. Multiple sequential path_prepend calls produce correct front ordering
#    (last call wins front position)
# ──────────────────────────────────────────────────────────────────────────────
test_start "path_prepend_ordering_last_wins_front"
dir_a=$(mktemp -d)
dir_b=$(mktemp -d)
PATH="/usr/bin"
path_prepend "$dir_a"   # PATH: dir_a:/usr/bin
path_prepend "$dir_b"   # PATH: dir_b:dir_a:/usr/bin
first_entry="${PATH%%:*}"
assert_equals "$dir_b" "$first_entry" "last prepended dir should be at front"
PATH="$_ORIG_PATH"
rmdir "$dir_a" "$dir_b"

# ──────────────────────────────────────────────────────────────────────────────
# 7. path_prepend correctly handles dir at the trailing position
# ──────────────────────────────────────────────────────────────────────────────
test_start "path_prepend_removes_from_tail"
test_dir=$(mktemp -d)
PATH="/usr/bin:/bin:$test_dir"
path_prepend "$test_dir"
# Should be at front, not at back
first_entry="${PATH%%:*}"
assert_equals "$test_dir" "$first_entry" "dir from tail should move to front"
count=$(printf '%s\n' "${PATH//:/$'\n'}" | grep -cxF "$test_dir" || true)
assert_equals "1" "$count" "dir from tail should not be duplicated after move"
PATH="$_ORIG_PATH"
rmdir "$test_dir"

# ──────────────────────────────────────────────────────────────────────────────
# 8. path_prepend as sole entry then re-prepend yields single entry
# ──────────────────────────────────────────────────────────────────────────────
test_start "path_prepend_sole_entry_no_duplicate"
test_dir=$(mktemp -d)
PATH="$test_dir"
path_prepend "$test_dir"
assert_equals "$test_dir" "$PATH" "sole-entry re-prepend should leave PATH unchanged"
PATH="$_ORIG_PATH"
rmdir "$test_dir"

mock_cleanup

echo ""
echo "path_prepend behavioral tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
