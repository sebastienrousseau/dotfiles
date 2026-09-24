#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Direct behavioural coverage for lib/dot/theme-transaction.sh: lock
# contention and reclamation, begin/snapshot failure clean-up, restore
# integrity failures, journal escaping, pruning and the exit guard. Faults
# are injected by shadowing commands with shell functions in subshells.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../../framework/assertions.sh"

LIB="$REPO_ROOT/lib/dot/theme-transaction.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/theme-txn-cov.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
export XDG_STATE_HOME="$HOME/.local/state"
export DOT_THEME_STATE_DIR="$WORK/state"
export DOT_THEME_LOCK_ROOT="$WORK/locks"
mkdir -p "$HOME" "$WORK/targets"
source "$LIB"
LOCK_DIR="$DOT_THEME_LOCK_ROOT/dot-theme-${UID:-$(id -u)}.lock.d"

# A PID that is certainly dead: a finished background job.
sleep 0 &
DEAD_PID=$!
wait "$DEAD_PID" 2>/dev/null || true

reset_state() {
  rm -rf "$DOT_THEME_STATE_DIR" "$DOT_THEME_LOCK_ROOT"
  THEME_TXN_ACTIVE=0
  THEME_TXN_FINALIZED=0
  THEME_TXN_LOCK_DIR=""
}

test_start "txn_json_escape_control_chars"
got="$(_theme_txn_json_escape "a\\b\"c"$'\n'"d"$'\r'"e"$'\t'"f")"
assert_equals 'a\\b\"c\nd\re\tf' "$got" "backslash, quote, newline, CR, tab escaped"

test_start "txn_state_and_lock_root_defaults"
got="$(env -u DOT_THEME_STATE_DIR -u DOT_THEME_LOCK_ROOT -u XDG_RUNTIME_DIR TMPDIR=/tmpx \
  bash -c 'source "$1"; printf "%s|%s" "$(_theme_txn_state_root)" "$(_theme_txn_lock_root)"' _ "$LIB")"
assert_equals "$XDG_STATE_HOME/dot/theme-transactions|/tmpx" "$got" "fallback roots"

test_start "txn_hash_missing_file_is_empty"
assert_equals "" "$(_theme_txn_hash "$WORK/nope")" "no hash for a missing path"

test_start "txn_hash_falls_back_to_shasum"
if command -v shasum >/dev/null 2>&1; then
  mkdir -p "$WORK/shabin"
  for tool in shasum awk perl; do
    src="$(command -v "$tool" 2>/dev/null || true)"
    [[ -n "$src" && "$src" == /* ]] && ln -sf "$src" "$WORK/shabin/$tool"
  done
  printf 'abc' >"$WORK/abc.txt"
  got="$(PATH="$WORK/shabin" _theme_txn_hash "$WORK/abc.txt")"
  assert_equals "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad" "$got" "shasum path hashes correctly"
else
  ((TESTS_PASSED++)) || true
  printf '  %s: skipped (no shasum)\n' "$CURRENT_TEST"
fi

test_start "txn_lock_rejects_invalid_timeout"
reset_state
out="$(_theme_txn_acquire_lock "1x" 2>&1)"
rc=$?
assert_equals "2|dot-theme-sync: invalid lock timeout: 1x" "$rc|$out" "non-numeric timeout rejected"

test_start "txn_lock_reclaims_dead_owner"
reset_state
got="$(
  mkdir -p "$LOCK_DIR"
  printf 'pid=%s\n' "$DEAD_PID" >"$LOCK_DIR/owner"
  _theme_txn_acquire_lock 0 && sed -n 's/^pid=//p' "$THEME_TXN_LOCK_DIR/owner"
)"
assert_equals "$$" "$got" "stale lock from a dead PID is taken over"

test_start "txn_lock_reclaims_ownerless_dir_after_timeout"
reset_state
got="$(
  mkdir -p "$LOCK_DIR"
  _theme_txn_acquire_lock 0 && printf 'acquired'
)"
assert_equals "acquired" "$got" "empty ownerless lock dir reclaimed at timeout"

test_start "txn_lock_times_out_on_live_owner"
reset_state
mkdir -p "$LOCK_DIR"
printf 'pid=%s\n' "$$" >"$LOCK_DIR/owner"
out="$(_theme_txn_acquire_lock 0 2>&1)"
rc=$?
assert_equals "1|dot-theme-sync: theme operation is locked by PID $$" "$rc|$out" "live owner blocks until timeout"

# Deterministic wait: the shadowed `sleep` stands in for the live owner
# finishing, so the retry loop is exercised without depending on wall-clock
# timing on a loaded machine.
test_start "txn_lock_waits_for_live_owner_then_acquires"
reset_state
mkdir -p "$LOCK_DIR"
printf 'pid=%s\n' "$$" >"$LOCK_DIR/owner"
got="$(
  sleep() {
    printf 'slept;'
    rm -f "$LOCK_DIR/owner"
    rmdir "$LOCK_DIR"
  }
  _theme_txn_acquire_lock 30 && printf 'acquired'
)"
assert_equals "slept;acquired" "$got" "lock retried after sleeping and then taken"

test_start "txn_lock_times_out_on_populated_ownerless_dir"
reset_state
mkdir -p "$LOCK_DIR"
: >"$LOCK_DIR/other"
out="$(_theme_txn_acquire_lock 0 2>&1)"
rc=$?
assert_equals "1|dot-theme-sync: theme operation is locked" "$rc|$out" "no PID named when ownerless"

test_start "txn_release_noop_without_lock"
reset_state
_theme_txn_release_lock
assert_equals "0|" "$?|$THEME_TXN_LOCK_DIR" "release without a lock is a no-op"

test_start "txn_release_leaves_foreign_lock"
reset_state
mkdir -p "$LOCK_DIR"
printf 'pid=%s\n' "$DEAD_PID" >"$LOCK_DIR/owner"
THEME_TXN_LOCK_DIR="$LOCK_DIR"
_theme_txn_release_lock
assert_equals "yes|" "$([[ -f "$LOCK_DIR/owner" ]] && echo yes)|$THEME_TXN_LOCK_DIR" "another PID's lock is not removed"

test_start "txn_begin_rejects_invalid_operation_id"
reset_state
out="$(DOT_THEME_OPERATION_ID='bad id!' _theme_txn_begin a b c 0 2>&1)"
rc=$?
assert_equals "2|dot-theme-sync: invalid operation ID" "$rc|$out" "unsafe operation IDs rejected"

test_start "txn_begin_propagates_lock_failure"
reset_state
out="$(DOT_THEME_OPERATION_ID=op-lock _theme_txn_begin a b c bad 2>&1)"
assert_equals "2" "$?" "lock error status returned"

test_start "txn_begin_state_root_unwritable"
reset_state
: >"$WORK/blocker"
got="$(
  DOT_THEME_STATE_DIR="$WORK/blocker/state"
  DOT_THEME_OPERATION_ID=op-root _theme_txn_begin a b c 0 2>/dev/null
  printf '%s|%s' "$?" "$([[ -d "$LOCK_DIR" ]] && echo locked || echo released)"
)"
assert_equals "1|released" "$got" "lock released when the state root cannot be created"

test_start "txn_begin_existing_operation_dir"
reset_state
mkdir -p "$DOT_THEME_STATE_DIR/op-dup"
got="$(
  DOT_THEME_OPERATION_ID=op-dup _theme_txn_begin a b c 0 2>&1
  printf '|%s|%s' "$?" "$([[ -d "$LOCK_DIR" ]] && echo locked || echo released)"
)"
assert_equals "dot-theme-sync: operation directory already exists: $DOT_THEME_STATE_DIR/op-dup"$'\n'"|1|released" "$got" "duplicate operation directory refused"

test_start "txn_begin_snapshot_dir_failure"
reset_state
got="$(
  mkdir() {
    [[ "${!#}" == */snapshots ]] && return 1
    command mkdir "$@"
  }
  DOT_THEME_OPERATION_ID=op-snapdir _theme_txn_begin a b c 0
  printf '%s|%s|%s' "$?" "$([[ -e "$DOT_THEME_STATE_DIR/op-snapdir" ]] && echo left || echo gone)" \
    "$([[ -d "$LOCK_DIR" ]] && echo locked || echo released)"
)"
assert_equals "1|gone|released" "$got" "operation dir removed and lock released"

test_start "txn_begin_snapshot_copy_failure"
reset_state
printf 'x\n' >"$WORK/targets/f"
got="$(
  cp() { return 1; }
  DOT_THEME_OPERATION_ID=op-cp _theme_txn_begin a b c 0 "$WORK/targets/f"
  printf '%s|%s|%s' "$?" "$([[ -e "$DOT_THEME_STATE_DIR/op-cp" ]] && echo left || echo gone)" \
    "$([[ -d "$LOCK_DIR" ]] && echo locked || echo released)"
)"
assert_equals "1|gone|released" "$got" "failed snapshot rolls the begin back"

test_start "txn_begin_snapshot_readlink_failure"
reset_state
ln -sfn "$WORK/targets/f" "$WORK/targets/l"
got="$(
  readlink() { return 1; }
  DOT_THEME_OPERATION_ID=op-rl _theme_txn_begin a b c 0 "$WORK/targets/l"
  printf '%s' "$?"
)"
assert_equals "1" "$got" "unreadable symlink aborts begin"

test_start "txn_full_cycle_restores_file_symlink_and_absent"
reset_state
printf 'orig\n' >"$WORK/targets/file"
printf 'link-target\n' >"$WORK/targets/lt"
ln -sfn "$WORK/targets/lt" "$WORK/targets/link"
rm -f "$WORK/targets/new"
got="$(
  DOT_THEME_OPERATION_ID=op-cycle _theme_txn_begin prev next dark 0 \
    "$WORK/targets/file" "" "$WORK/targets/link" "$WORK/targets/new" || exit 9
  printf 'mutated\n' >"$WORK/targets/file"
  rm -f "$WORK/targets/link"
  printf 'x\n' >"$WORK/targets/link"
  printf 'created\n' >"$WORK/targets/new"
  _theme_txn_rollback "bad \"apply\""
  printf '%s|%s|%s|%s' "$?" "$(cat "$WORK/targets/file")" "$(readlink "$WORK/targets/link")" \
    "$([[ -e "$WORK/targets/new" ]] && echo present || echo absent)"
)"
journal="$DOT_THEME_STATE_DIR/op-cycle/journal.json"
assert_equals "0|orig|$WORK/targets/lt|absent|yes" "$got|$(grep -q '"status": "rolled_back"' "$journal" && grep -q 'bad \\"apply\\"' "$journal" && echo yes)" "rollback restores every target and journals it"

run_restore_case() {
  # $1 = manifest line to append, $2 = snapshot action
  reset_state
  (
    DOT_THEME_OPERATION_ID="op-$3" _theme_txn_begin a b c 0 "$WORK/targets/file" || exit 9
    eval "$2"
    printf '%s\n' "$1" >>"$THEME_TXN_MANIFEST"
    _theme_txn_rollback "case $3"
    printf '%s|%s' "$?" "$(grep -o '"status": "[a-z_]*"' "$THEME_TXN_OPERATION_DIR/journal.json")"
  )
}

test_start "txn_restore_missing_file_snapshot_fails"
printf 'orig\n' >"$WORK/targets/file"
got="$(run_restore_case "" 'rm -f "$THEME_TXN_OPERATION_DIR/snapshots/1"' nosnap)"
assert_equals '1|"status": "rollback_failed"' "$got" "missing file snapshot marks rollback_failed"

test_start "txn_restore_hash_mismatch_fails"
got="$(run_restore_case "" 'printf "tampered\n" >"$THEME_TXN_OPERATION_DIR/snapshots/1"' hash)"
assert_equals '1|"status": "rollback_failed"' "$got" "snapshot not matching recorded hash fails"

test_start "txn_restore_missing_symlink_snapshot_fails"
got="$(run_restore_case "$(printf '7\tsymlink\t-\t%s' "$WORK/targets/sl")" ':' nosl)"
assert_equals '1|"status": "rollback_failed"' "$got" "missing symlink snapshot fails"

test_start "txn_restore_unknown_type_fails"
got="$(run_restore_case "$(printf '8\tfifo\t-\t%s' "$WORK/targets/q")" ':' unknown)"
assert_equals '1|"status": "rollback_failed"' "$got" "unknown manifest type fails"

test_start "txn_restore_without_manifest_is_noop"
THEME_TXN_MANIFEST="$WORK/no-manifest.tsv"
_theme_txn_restore_files
assert_equals "0" "$?" "absent manifest restores nothing"

test_start "txn_finalize_and_rollback_noop_when_inactive"
THEME_TXN_ACTIVE=0
_theme_txn_finalize succeeded
r1=$?
_theme_txn_rollback
assert_equals "0|0" "$r1|$?" "inactive transactions are no-ops"

test_start "txn_finalize_writes_journal_and_prunes"
reset_state
mkdir -p "$DOT_THEME_STATE_DIR/theme-20000101T000000Z-1-1" "$DOT_THEME_STATE_DIR/theme-20000102T000000Z-1-1"
: >"$DOT_THEME_STATE_DIR/theme-file-not-dir"
got="$(
  DOT_THEME_TRANSACTION_RETENTION=0
  DOT_THEME_OPERATION_ID=theme-20990101T000000Z-1-1 _theme_txn_begin a b c 0 || exit 9
  _theme_txn_finalize
  printf '%s|%s' "$?" "$(cd "$DOT_THEME_STATE_DIR" && ls -d theme-*/ | tr -d '/' | tr '\n' ' ')"
)"
assert_equals "0|theme-20990101T000000Z-1-1 " "$got" "retention 0 keeps only the newest operation"

test_start "txn_prune_invalid_retention_defaults_to_20"
reset_state
mkdir -p "$DOT_THEME_STATE_DIR"
for i in $(seq -w 1 22); do mkdir -p "$DOT_THEME_STATE_DIR/theme-$i"; done
DOT_THEME_TRANSACTION_RETENTION=abc _theme_txn_prune
assert_equals "20|no" "$(find "$DOT_THEME_STATE_DIR" -mindepth 1 -maxdepth 1 -name 'theme-*' | wc -l | tr -d ' ')|$([[ -d "$DOT_THEME_STATE_DIR/theme-01" ]] && echo yes || echo no)" "oldest beyond 20 pruned"

test_start "txn_prune_missing_root_is_noop"
rm -rf "$DOT_THEME_STATE_DIR"
_theme_txn_prune
assert_equals "0" "$?" "missing state root is fine"

test_start "txn_exit_guard_rolls_back_active"
reset_state
printf 'orig\n' >"$WORK/targets/file"
got="$(
  DOT_THEME_OPERATION_ID=op-guard _theme_txn_begin a b c 0 "$WORK/targets/file" || exit 9
  printf 'changed\n' >"$WORK/targets/file"
  _theme_txn_exit_guard 3
  printf '%s|%s' "$(cat "$WORK/targets/file")" "$(grep -o 'process exited with status 3' "$DOT_THEME_STATE_DIR/op-guard/journal.json")"
)"
assert_equals "orig|process exited with status 3" "$got" "active transaction rolled back on exit"

test_start "txn_exit_guard_releases_lock_when_inactive"
reset_state
got="$(
  _theme_txn_acquire_lock 0 || exit 9
  _theme_txn_exit_guard
  printf '%s' "$([[ -d "$LOCK_DIR" ]] && echo locked || echo released)"
)"
assert_equals "released" "$got" "finished transaction just drops the lock"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
