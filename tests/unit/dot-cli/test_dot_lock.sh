#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# Per-domain locks (ADR-020 N17): lib/dot/lock.sh holds
# $XDG_STATE_HOME/dot/<domain>/lock, a symlink naming the holder's PID, for
# as long as the holder runs; a second run exits 75 naming it, or waits
# DOT_LOCK_WAIT seconds; a stale link is taken over. bin/dot takes the lock
# for write and destructive commands, never for read ones, help or the
# commands a manifest declares `lock = false`; the resolver
# (lib/dot/names.sh) tells it which domain a command line locks. The
# holders are real processes (sleep); each case runs in a child bash with
# its own state dir.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-lock.XXXXXX")"
HOLDERS=()
trap 'kill "${HOLDERS[@]}" 2>/dev/null; rm -rf "$WORK"' EXIT
S="$WORK/state"

# lock DOMAIN [ENV...]: run dot_lock DOMAIN in a child bash; sets RC and
# OUT (stderr), and PID to the child's PID.
lock() {
  local domain="$1"
  shift
  RC=0
  OUT="$(env "$@" XDG_STATE_HOME="$S" bash -c '
    set -euo pipefail
    source "$1/lib/dot/lock.sh"
    echo "$$" >"$2/pid"
    dot_lock "$3"
    printf "%s\n" "${DOT_LOCKED:-}" >"$2/locked"
  ' _ "$REPO_ROOT" "$WORK" "$domain" 2>&1)" || RC=$?
  PID="$(cat "$WORK/pid")"
}

# holder DOMAIN: a live process holding DOMAIN's lock; sets HOLDER.
holder() {
  mkdir -p "$S/dot/$1"
  sleep 30 &
  HOLDER=$!
  HOLDERS+=("$HOLDER")
  ln -sfn "$HOLDER" "$S/dot/$1/lock"
}

link() { readlink "$S/dot/$1/lock" 2>/dev/null || echo none; }

test_start "a_free_lock_is_taken"
lock theme
assert_equals "0|$PID|theme" "$RC|$(link theme)|$(cat "$WORK/locked")" \
  "the link names the taker, and DOT_LOCKED lists the domain"

test_start "a_held_lock_exits_75_naming_the_holder"
holder theme
lock theme
assert_equals "75" "$RC" "a second run exits 75"
assert_contains "PID $HOLDER holds $S/dot/theme/lock" "$OUT" "and says who holds the lock"
assert_equals "$HOLDER" "$(link theme)" "the holder keeps its lock"

test_start "a_stale_lock_is_taken_over"
sleep 0 &
dead=$!
wait "$dead"
ln -sfn "$dead" "$S/dot/theme/lock"
lock theme
assert_equals "0|$PID" "$RC|$(link theme)" "a link naming a dead PID is replaced"
assert_equals "0" "$(find "$S/dot/theme" -name 'lock.stale.*' | wc -l | tr -d ' ')" \
  "and the renamed stale link is removed"

test_start "a_forged_holder_is_not_alive"
# kill -0 -1 succeeds (it signals every process the user may): a link that
# is not a plain PID must not pass for a live holder.
ln -sfn -- "-1" "$S/dot/theme/lock"
lock theme
assert_equals "0|$PID" "$RC|$(link theme)" "a link naming -1 is stale"

test_start "another_users_holder_is_alive"
# kill -0 cannot signal a root process, but ps still sees it.
if [[ "$(id -u)" != 0 ]] && ps -p 1 >/dev/null 2>&1; then
  ln -sfn 1 "$S/dot/theme/lock"
  lock theme
  assert_equals "75|1" "$RC|$(link theme)" "PID 1 (root's) holds the lock"
else
  echo "  - SKIP another_users_holder_is_alive: running as root or no PID 1 visible"
fi

test_start "reclaim_puts_back_a_link_it_did_not_expect"
# Between reading a dead holder and renaming the link, another run may have
# taken the lock: the renamed link names it, so it goes back.
holder theme
RC=0
XDG_STATE_HOME="$S" bash -c 'source "$1/lib/dot/lock.sh"; _dot_lock_reclaim "$2" 999999999' \
  _ "$REPO_ROOT" "$S/dot/theme/lock" || RC=$?
assert_equals "0|$HOLDER|0" "$RC|$(link theme)|$(find "$S/dot/theme" -name 'lock.stale.*' | wc -l | tr -d ' ')" \
  "the live holder's link is restored, and nothing is left behind"

test_start "other_domains_are_independent"
rm -f "$S/dot/theme/lock"
holder config
lock theme
assert_equals "0" "$RC" "a held config lock does not block theme"

test_start "a_child_of_the_holder_does_not_wait_on_it"
holder theme
lock theme DOT_LOCKED="config theme"
assert_equals "0|$HOLDER" "$RC|$(link theme)" "a domain in DOT_LOCKED is already held by a parent"

test_start "dot_lock_wait_waits_for_the_holder"
holder theme
(sleep 1 && kill "$HOLDER") &
lock theme DOT_LOCK_WAIT=10
assert_equals "0|$PID" "$RC|$(link theme)" "the lock is taken once the holder exits"

test_start "a_bad_wait_or_domain_is_not_fatal"
holder theme
lock theme DOT_LOCK_WAIT=soon
assert_equals "75" "$RC" "a DOT_LOCK_WAIT that is not a number means no wait"
(sleep 1 && kill "$HOLDER") &
lock theme DOT_LOCK_WAIT=+3
assert_equals "75" "$RC" "nor does a signed one: +3 does not wait for the holder to end"
lock "../escape"
assert_equals "64|none" "$RC|$(readlink "$WORK/escape/lock" 2>/dev/null || echo none)" \
  "a domain that is not a name is refused before any path is built"

# bin/dot in a sandboxed home: the command runs only when the lock is free.
H="$WORK/home"
mkdir -p "$H"
dot() {
  RC=0
  OUT="$(env -i HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$S" XDG_CACHE_HOME="$H/.cache" \
    XDG_CONFIG_HOME="$H/.config" XDG_DATA_HOME="$H/.local/share" NO_COLOR=1 TERM=dumb \
    "$@" 2>&1 </dev/null)" || RC=$?
}

test_start "dispatcher_locks_a_write_command"
rm -f "$S/dot/shell/lock"
holder shell
dot bash "$REPO_ROOT/bin/dot" shell clean
assert_equals "75" "$RC" "dot shell clean exits 75 while another shell command runs"
assert_contains "busy: PID $HOLDER" "$OUT" "naming the holder"
dot bash "$REPO_ROOT/bin/dot" shell status
assert_not_equals "75" "$RC" "a read command in the same domain is not locked"
dot bash "$REPO_ROOT/bin/dot" shell clean --help
assert_equals "0" "$RC" "help never takes the lock"

test_start "dispatcher_takes_and_leaves_the_lock"
kill "$HOLDER"
wait "$HOLDER" 2>/dev/null
dot bash "$REPO_ROOT/bin/dot" shell clean
assert_not_equals "75" "$RC" "with the holder gone, the command runs"
taker="$(link shell)"
assert_equals "true|false" "$([[ "$taker" =~ ^[0-9]+$ && "$taker" != "$HOLDER" ]] && echo true || echo false)|$(kill -0 "$taker" 2>/dev/null && echo true || echo false)" \
  "it took the stale lock under its own PID, which ended with it"

test_start "dispatcher_skips_a_lock_false_command"
holder ai
dot bash "$REPO_ROOT/bin/dot" ai run
assert_not_equals "75" "$RC" "dot ai run (lock = false) runs while ai is locked"
assert_equals "$HOLDER" "$(link ai)" "and leaves the holder's lock alone"

print_summary
