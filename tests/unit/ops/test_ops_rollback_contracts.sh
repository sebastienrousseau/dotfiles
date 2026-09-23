#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural contracts for `dot rollback` that the mutation run showed
# unprotected: every refusal has an exact exit status and message, a
# confirmation prompt treats anything but y/Y as "no", pruning keeps
# exactly the newest ten backups, and the AI hand-off runs only when
# asked for. All state lives in a mktemp HOME with fixed backup names.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ROLLBACK="$REPO_ROOT/scripts/ops/rollback.sh"
unset VERBOSE # the caller's own setting must not leak in
WORK="$(mktemp -d "${TMPDIR:-/tmp}/rb-contract.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

H="$WORK/home"
BKROOT="$H/.local/share/dotfiles/backups"
mkdir -p "$WORK/stubs" "$WORK/run"
printf '#!/bin/sh\nexit 0\n' >"$WORK/stubs/chezmoi"
# `dot` stub: records the AI hand-off instead of calling a model.
printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"%s/dot.calls"\n' "$WORK" >"$WORK/stubs/dot"
chmod +x "$WORK/stubs/chezmoi" "$WORK/stubs/dot"

reset_home() {
  rm -rf "$H" "$WORK/dot.calls"
  mkdir -p "$BKROOT"
}
backup() { # backup <stamp> <bashrc-content>
  mkdir -p "$BKROOT/backup_$1"
  printf '%s\n' "$2" >"$BKROOT/backup_$1/.bashrc"
  : >"$BKROOT/backup_$1/.backup_meta"
}
rb() { # rb <stdin> <args...>
  local input="$1"
  shift
  printf '%b' "$input" | HOME="$H" XDG_DATA_HOME="$H/.local/share" XDG_STATE_HOME="$H/.local/state" \
    XDG_RUNTIME_DIR="$WORK/run" PATH="$WORK/stubs:$PATH" bash "$ROLLBACK" "$@" >"$WORK/out" 2>&1
}

# ── restore refusals ────────────────────────────────────────────────
test_start "restore_without_backups"
reset_home
rb '' restore .bashrc
assert_equals "1" "$?" "exit 1"
assert_file_contains "$WORK/out" "No backups available" "says why"

test_start "restore_file_missing_from_backup_lists_what_exists"
reset_home
backup 20260101_000000 v1
rb '' restore .zshrc
assert_equals "1" "$?" "exit 1"
assert_file_contains "$WORK/out" "File not found in backup: .zshrc" "names the file"
assert_file_contains "$WORK/out" ".bashrc" "lists the files that can be restored"
assert_output_not_contains ".backup_meta" "cat '$WORK/out'"

test_start "restore_directory_missing_from_backup_is_not_a_traversal"
rb '' restore .config/nvim/init.lua
assert_equals "1" "$?" "exit 1"
assert_file_contains "$WORK/out" "File not found in backup: .config/nvim/init.lua" "plain not-found"
assert_output_not_contains "Path traversal" "cat '$WORK/out'"

test_start "restore_dry_run_changes_nothing"
printf 'current\n' >"$H/.bashrc"
rb '' --dry-run restore .bashrc
assert_equals "0" "$?" "exit 0"
assert_file_contains "$WORK/out" "[DRY-RUN] Would restore: .bashrc" "reports the plan"
assert_equals "current" "$(cat "$H/.bashrc")" "file untouched"
assert_equals "0" "$(find "$H" -maxdepth 1 -name '.bashrc.rollback.*' | wc -l | tr -d ' ')" "no safety copy made"

test_start "restore_without_a_file_argument"
rb '' restore
assert_equals "1" "$?" "exit 1"
assert_file_contains "$WORK/out" "Please specify a file to restore" "usage error"

# ── rollback confirmation ───────────────────────────────────────────
test_start "rollback_without_backups"
reset_home
rb '' rollback --force
assert_equals "1" "$?" "exit 1"
assert_file_contains "$WORK/out" "No backups available for rollback" "says why"

test_start "rollback_prompt_nay_is_a_decline"
reset_home
backup 20260101_000000 v1
printf 'current\n' >"$H/.bashrc"
rb 'nay\n' rollback
assert_equals "0" "$?" "declining exits 0"
assert_equals "current" "$(cat "$H/.bashrc")" "nothing restored"

test_start "rollback_prompt_y_restores"
rb 'y\n' rollback
assert_equals "0" "$?" "exit 0"
assert_equals "v1" "$(cat "$H/.bashrc")" "latest backup restored"

test_start "rollback_to_prompt_nay_is_a_decline"
reset_home
backup 20260101_000000 v1
printf 'current\n' >"$H/.bashrc"
rb 'nay\n' rollback-to 1
assert_equals "0" "$?" "declining exits 0"
assert_equals "current" "$(cat "$H/.bashrc")" "nothing restored"

test_start "rollback_to_missing_index"
rb '' rollback-to 5 --force
assert_equals "1" "$?" "exit 1"
assert_file_contains "$WORK/out" "Backup #5 not found" "names the index"

test_start "rollback_to_picks_the_numbered_backup"
backup 20260102_000000 v2
rb '' rollback-to 2 --force
assert_equals "0" "$?" "exit 0"
assert_equals "v1" "$(cat "$H/.bashrc")" "#2 is the older backup (newest first)"

# ── AI hand-off ─────────────────────────────────────────────────────
test_start "rollback_ai_handoff_off_by_default"
reset_home
backup 20260101_000000 v1
rb '' rollback --force
assert_equals "0" "$?" "exit 0"
assert_file_not_exists "$WORK/dot.calls" "dot ai not called"

test_start "rollback_ai_handoff_when_enabled"
reset_home
backup 20260101_000000 v1
printf 'y\n' | HOME="$H" XDG_DATA_HOME="$H/.local/share" XDG_STATE_HOME="$H/.local/state" \
  XDG_RUNTIME_DIR="$WORK/run" PATH="$WORK/stubs:$PATH" DOTFILES_AI=1 \
  bash "$ROLLBACK" rollback --force >"$WORK/out" 2>&1
assert_equals "0" "$?" "exit 0"
assert_file_contains "$WORK/dot.calls" "ai claude --style hardener System rollback was triggered from backup_20260101_000000." "prompt names the backup"

# ── pruning keeps the newest ten ────────────────────────────────────
test_start "clean_at_ten_backups_removes_nothing"
reset_home
for i in 01 02 03 04 05 06 07 08 09 10; do backup "202601${i}_000000" "v$i"; done
rb '' clean
assert_equals "0" "$?" "exit 0"
assert_equals "10" "$(find "$BKROOT" -maxdepth 1 -name 'backup_*' | wc -l | tr -d ' ')" "ten kept"
assert_output_not_contains "Cleaning up" "cat '$WORK/out'"

test_start "clean_at_eleven_removes_the_oldest"
backup 20260111_000000 v11
rb '' clean
assert_equals "0" "$?" "exit 0"
assert_equals "10" "$(find "$BKROOT" -maxdepth 1 -name 'backup_*' | wc -l | tr -d ' ')" "ten kept"
assert_dir_not_exists "$BKROOT/backup_20260101_000000" "oldest removed"
assert_dir_exists "$BKROOT/backup_20260111_000000" "newest kept"
assert_file_contains "$WORK/out" "Cleaning up 1 old backup(s)" "reports the count"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
