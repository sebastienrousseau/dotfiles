#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# `dot rollback restore` and `rollback-to` take user input that ends up in
# file paths and a sed script. Each guard is pinned by the exact outcome it
# prevents: an exit status, the refusal message, and no file written
# outside the sandbox. Found by mutation testing (R1, R4, R5): the guards
# were correct or broken without any test noticing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ROLLBACK="$REPO_ROOT/scripts/ops/rollback.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/rb-guards.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

H="$WORK/home"
BK="$H/.local/share/dotfiles/backups/backup_20260101_000000"
mkdir -p "$BK/evil" "$H" "$WORK/run" "$WORK/stubs" "$WORK/outside" "$WORK/secret" "$WORK/home-sibling"
printf '#!/bin/sh\nexit 0\n' >"$WORK/stubs/chezmoi"
chmod +x "$WORK/stubs/chezmoi"
printf 'from-backup\n' >"$BK/.bashrc"
printf 'payload\n' >"$BK/evil/x"
printf 'secret\n' >"$WORK/secret/file"
: >"$BK/.backup_meta"

rb() {
  HOME="$H" XDG_DATA_HOME="$H/.local/share" XDG_STATE_HOME="$H/.local/state" \
    XDG_RUNTIME_DIR="$WORK/run" PATH="$WORK/stubs:$PATH" \
    bash "$ROLLBACK" "$@" </dev/null >"$WORK/out" 2>&1
}

test_start "restore_rejects_dotdot_before_resolving"
rb restore ../outside/x
assert_equals "1" "$?" "exit 1"
assert_file_contains "$WORK/out" "Path traversal detected in file path" "the .. guard itself refuses"

test_start "restore_rejects_destination_symlinked_out_of_home"
ln -s "$WORK/outside" "$H/evil"
rb restore evil/x
assert_equals "1" "$?" "exit 1"
assert_file_contains "$WORK/out" "destination escapes HOME directory" "refusal names the destination"
assert_file_not_exists "$WORK/outside/x" "nothing written through the symlink"
rm "$H/evil"

test_start "restore_rejects_destination_in_a_home_prefixed_sibling"
# $HOME=/w/home must not accept /w/home-sibling just because it shares
# the prefix.
ln -s "$WORK/home-sibling" "$H/evil"
rb restore evil/x
assert_equals "1" "$?" "exit 1"
assert_file_not_exists "$WORK/home-sibling/x" "nothing written to the sibling"
rm "$H/evil"

test_start "restore_rejects_source_symlinked_out_of_the_backup"
ln -s "$WORK/secret" "$BK/sneaky"
rb restore sneaky/file
assert_equals "1" "$?" "exit 1"
assert_file_contains "$WORK/out" "resolved path escapes backup directory" "refusal names the source"
assert_file_not_exists "$H/sneaky/file" "the outside file was not copied into HOME"
rm "$BK/sneaky"

test_start "restore_happy_path_still_works"
printf 'current\n' >"$H/.bashrc"
rb restore .bashrc
assert_equals "0" "$?" "exit 0"
assert_equals "from-backup" "$(cat "$H/.bashrc")" "backup content restored"
assert_equals "current" "$(cat "$H"/.bashrc.rollback.*)" "previous content kept aside"

test_start "restore_into_a_missing_directory"
rm -rf "$H/evil"
rb restore evil/x
assert_equals "0" "$?" "a deleted parent directory is recreated inside HOME"
assert_equals "payload" "$(cat "$H/evil/x")" "file restored"

test_start "rollback_to_rejects_a_non_numeric_index"
# Unanchored, "1w FILE" would reach `sed -n "${index}p"` as a write command.
rb rollback-to "1w $WORK/pwned"
assert_equals "1" "$?" "exit 1"
assert_file_contains "$WORK/out" "Please specify a backup number" "rejected by the input check"
assert_file_not_exists "$WORK/pwnedp" "sed never ran the injected command"

test_start "rollback_to_rejects_a_suffixed_index"
rb rollback-to 1x
assert_equals "1" "$?" "exit 1"
assert_file_contains "$WORK/out" "Please specify a backup number" "rejected by the input check, not by lookup"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
