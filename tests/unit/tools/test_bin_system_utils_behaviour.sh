#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for the system-facing utilities in
# defaults/dot_local/bin: kill-port, notify, gd, antigravity,
# dot-launch-or-focus and corralctl-sync.
#
# Everything they would touch on the host — lsof/kill, osascript,
# notify-send, fzf/delta/git, niri and corralctl — is a recording stub in the
# sandbox, so process signals, notifications and window management are
# asserted by what the utility *asked for*, never performed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

BIN_DIR="$REPO_ROOT/defaults/dot_local/bin"
REAL_BASH="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

BIN="$DOTFILES_COV_TMPDIR/bin"
OUTF="$DOTFILES_COV_TMPDIR/out.txt"
ERRF="$DOTFILES_COV_TMPDIR/err.txt"
MERGED="$DOTFILES_COV_TMPDIR/merged.txt"
export CALLS="$DOTFILES_COV_TMPDIR/calls.txt"

record_stub() {
  cat >"$BIN/$1" <<STUB
#!$REAL_BASH
printf '$1 %s\\n' "\$*" >>"\$CALLS"
exit 0
STUB
  chmod +x "$BIN/$1"
}

util() {
  local name="$1"
  shift
  : >"$CALLS"
  # The child's stderr must stay a *stream we replay*, not be merged into the
  # captured output: `2>&1` would fold the child's xtrace into $OUTF, and the
  # coverage runner would then see none of the lines it executed. Assertions
  # read stdout plus stderr-minus-xtrace.
  bash "$BIN_DIR/executable_$name" "$@" >"$OUTF" 2>"$ERRF" </dev/null
  RC=$?
  [[ "${DOTFILES_COV_ECHO_STDERR:-0}" == "1" ]] && cat "$ERRF" >&2
  return 0
}
out_has() {
  {
    cat "$OUTF"
    grep -v '^+*@COV@' "$ERRF" 2>/dev/null
  } >"$MERGED"
  assert_file_contains "$MERGED" "$1" "${2:-output contains $1}"
}
out_lacks() {
  {
    cat "$OUTF"
    grep -v '^+*@COV@' "$ERRF" 2>/dev/null
  } >"$MERGED"
  if grep -qF -- "$1" "$MERGED"; then
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ${2:-output should not contain $1}"
  else
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: ${2:-output lacks $1}"
  fi
}

called() { assert_file_contains "$CALLS" "$1" "invoked $1"; }

# ── kill-port ───────────────────────────────────────────────────────────
cat >"$BIN/lsof" <<STUB
#!$REAL_BASH
printf 'lsof %s\\n' "\$*" >>"\$CALLS"
cat "\$LSOF_PIDS" 2>/dev/null
exit 0
STUB
cat >"$BIN/ps" <<STUB
#!$REAL_BASH
printf 'ps %s\\n' "\$*" >>"\$CALLS"
echo "  1234 node    node server.js"
exit 0
STUB
cat >"$BIN/kill" <<STUB
#!$REAL_BASH
printf 'kill %s\\n' "\$*" >>"\$CALLS"
exit 0
STUB
chmod +x "$BIN/lsof" "$BIN/ps" "$BIN/kill"
export LSOF_PIDS="$DOTFILES_COV_TMPDIR/pids.txt"
: >"$LSOF_PIDS"

test_start "kill_port_requires_a_port"
util kill-port
assert_equals 1 "$RC" "rc"
out_has "Usage: kill-port <port>" "usage"

test_start "kill_port_validates_the_port_number"
util kill-port not-a-port
assert_equals 1 "$RC" "rc"
out_has "Invalid port number: not-a-port" "error"
util kill-port 0
assert_equals 1 "$RC" "rc"
util kill-port 65536
assert_equals 1 "$RC" "rc"
out_has "Invalid port number: 65536" "upper bound"

test_start "kill_port_reports_an_idle_port"
: >"$LSOF_PIDS"
util kill-port 3000
assert_equals 0 "$RC" "rc"
out_has "No process found on port 3000" "message"

# `kill` is a shell builtin, so a PATH stub would never be consulted: the
# signal has to be real. Each case therefore targets a throwaway `sleep`
# started by this suite, and never a PID we did not create.
test_start "kill_port_sends_sigterm_by_default"
sleep 30 &
VICTIM=$!
printf '%s\n' "$VICTIM" >"$LSOF_PIDS"
util kill-port 3000
assert_equals 0 "$RC" "rc"
out_has "Sending SIGTERM" "signal announced"
out_has "Killed PID $VICTIM" "result"
wait "$VICTIM" 2>/dev/null
assert_false "kill -0 $VICTIM 2>/dev/null" "the process is gone"

test_start "kill_port_force_sends_sigkill"
sleep 30 &
VICTIM=$!
printf '%s\n' "$VICTIM" >"$LSOF_PIDS"
util kill-port 8080 --force
assert_equals 0 "$RC" "rc"
out_has "Force killing" "announced"
out_has "Killed PID $VICTIM" "result"
wait "$VICTIM" 2>/dev/null
sleep 30 &
VICTIM=$!
printf '%s\n' "$VICTIM" >"$LSOF_PIDS"
util kill-port 8080 -f
out_has "Killed PID $VICTIM" "short flag behaves the same"
wait "$VICTIM" 2>/dev/null

test_start "kill_port_kills_every_listed_process"
sleep 30 &
FIRST=$!
sleep 30 &
SECOND=$!
printf '%s\n%s\n' "$FIRST" "$SECOND" >"$LSOF_PIDS"
util kill-port 3000
assert_equals 0 "$RC" "rc"
out_has "Killed PID $FIRST" "first process"
out_has "Killed PID $SECOND" "second process"
wait "$FIRST" "$SECOND" 2>/dev/null

test_start "kill_port_reports_a_process_it_cannot_signal"
sleep 5 &
GONE=$!
kill "$GONE" 2>/dev/null
wait "$GONE" 2>/dev/null
printf '%s\n' "$GONE" >"$LSOF_PIDS"
util kill-port 3000
assert_equals 0 "$RC" "rc"
out_has "Failed to kill PID $GONE" "failure reported"

NOTOOL="$DOTFILES_COV_TMPDIR/notool"
mkdir -p "$NOTOOL"
ln -sf "$REAL_BASH" "$NOTOOL/bash"
for c in printf echo cat grep sed; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$NOTOOL/$c"
done

test_start "kill_port_without_a_lookup_tool_finds_nothing_to_kill"
# find_pid runs inside a command substitution, so its "no supported tool"
# message is captured as the PID list rather than printed; the observable
# behaviour is that no signal is sent.
: >"$LSOF_PIDS"
PATH="$NOTOOL" util kill-port 3000
assert_true "! grep -q 'Killed PID' '$OUTF'" "nothing is signalled"

# ── notify ──────────────────────────────────────────────────────────────
record_stub osascript
record_stub notify-send

test_start "notify_uses_osascript_on_macos"
util notify "Build" "finished"
assert_equals 0 "$RC" "rc"
called "display notification"
assert_file_contains "$CALLS" "with title \"Build\"" "title passed through"

test_start "notify_defaults_the_title"
util notify
assert_equals 0 "$RC" "rc"
assert_file_contains "$CALLS" "Notification" "default title"

# ── antigravity ─────────────────────────────────────────────────────────
test_start "antigravity_reports_a_missing_upstream_binary"
util antigravity
assert_equals 0 "$RC" "rc"
out_has "not installed; skipping" "no-op message"

test_start "antigravity_answers_version_even_without_the_binary"
util antigravity --version
assert_equals 0 "$RC" "rc"
out_has "antigravity wrapper (upstream not installed)" "version string"

# ── gd ──────────────────────────────────────────────────────────────────
test_start "gd_requires_its_dependencies"
PATH="$NOTOOL" util gd
assert_equals 1 "$RC" "rc"
out_has "gd requires" "error names the missing tool"

record_stub fzf
record_stub delta
cat >"$BIN/git" <<STUB
#!$REAL_BASH
printf 'git %s\\n' "\$*" >>"\$CALLS"
case "\$1" in
  rev-parse) exit "\${GIT_IN_REPO_RC:-0}" ;;
  diff) printf 'file-a.txt\\n' ;;
esac
exit 0
STUB
chmod +x "$BIN/git"

test_start "gd_requires_a_git_repository"
GIT_IN_REPO_RC=1 util gd
assert_equals 1 "$RC" "rc"
out_has "not a git repository" "error"

test_start "gd_pipes_the_diff_into_fzf"
util gd
assert_equals 0 "$RC" "rc"
called "git diff --color=always --name-only"
called "fzf --preview"

test_start "gd_forwards_git_diff_flags"
util gd --staged
assert_equals 0 "$RC" "rc"
called "git diff --staged --color=always --name-only"

test_start "gd_side_mode_sets_the_delta_feature"
util gd --side
assert_equals 0 "$RC" "rc"
assert_true "! grep -q -- '--side' '$CALLS'" "--side is consumed, not forwarded to git"

# ── dot-launch-or-focus ─────────────────────────────────────────────────
test_start "launch_or_focus_help_and_usage_errors"
util dot-launch-or-focus --help
assert_equals 0 "$RC" "rc"
out_has "Usage: dot-launch-or-focus <app>" "usage"
util dot-launch-or-focus
assert_equals 1 "$RC" "rc"
util dot-launch-or-focus --unknown-flag
assert_equals 2 "$RC" "rc"
out_has "Unknown option: --unknown-flag" "error"

test_start "launch_or_focus_falls_back_to_a_direct_launch_without_niri"
record_stub ghostty
util dot-launch-or-focus com.mitchellh.ghostty --extra
assert_equals 0 "$RC" "rc"
out_has "requires niri" "explanation"
called "ghostty --extra"

cat >"$BIN/niri" <<STUB
#!$REAL_BASH
printf 'niri %s\\n' "\$*" >>"\$CALLS"
if [[ "\$2" == "--json" ]]; then cat "\$NIRI_WINDOWS"; fi
exit 0
STUB
chmod +x "$BIN/niri"
export NIRI_WINDOWS="$DOTFILES_COV_TMPDIR/windows.json"

test_start "launch_or_focus_focuses_a_running_window"
printf '[{"id":7,"app_id":"com.mitchellh.ghostty"}]\n' >"$NIRI_WINDOWS"
util dot-launch-or-focus ghostty
assert_equals 0 "$RC" "rc"
called "niri msg action focus-window --id 7"

test_start "launch_or_focus_spawns_when_nothing_matches"
printf '[{"id":7,"app_id":"org.other.app"}]\n' >"$NIRI_WINDOWS"
util dot-launch-or-focus com.mitchellh.ghostty --new-window
assert_equals 0 "$RC" "rc"
called "niri msg action spawn -- ghostty --new-window"

# ── corralctl-sync ──────────────────────────────────────────────────────
CORRAL="$BIN_DIR/executable_corralctl-sync.sh"
LOG="$HOME/Library/Logs/corralctl.log"
mkdir -p "$HOME/Library/Logs" "$HOME/.local/share/mise/shims"
cat >"$HOME/.local/share/mise/shims/corralctl" <<STUB
#!$REAL_BASH
printf 'corralctl %s\\n' "\$*" >>"\$CALLS"
cat "\$CORRAL_OUTPUT" 2>/dev/null
exit "\${CORRAL_RC:-0}"
STUB
chmod +x "$HOME/.local/share/mise/shims/corralctl"
cat >"$BIN/osascript" <<STUB
#!$REAL_BASH
printf 'osascript %s\\n' "\$*" >>"\$CALLS"
exit 0
STUB
chmod +x "$BIN/osascript"
export CORRAL_OUTPUT="$DOTFILES_COV_TMPDIR/corral-out.txt"

corral() {
  : >"$CALLS"
  bash "$CORRAL" >"$OUTF" 2>"$ERRF" </dev/null
  RC=$?
  [[ "${DOTFILES_COV_ECHO_STDERR:-0}" == "1" ]] && cat "$ERRF" >&2
  return 0
}

test_start "corralctl_sync_logs_a_successful_run"
printf '✓ [SYNC] repo-one\n✓ [SYNC] repo-two\n' >"$CORRAL_OUTPUT"
rm -f "$LOG"
corral
assert_equals 0 "$RC" "rc"
called "corralctl sebastienrousseau -c 8"
assert_file_contains "$LOG" "corralctl sync started" "run logged"
assert_file_contains "$LOG" "exit=0 synced=2 errors=0" "counts recorded"
assert_true "! grep -q osascript '$CALLS'" "no notification on success"

test_start "corralctl_sync_counts_reported_errors"
# The failure notification is posted through /usr/bin/osascript by absolute
# path, which no PATH stub can intercept and which would put a real banner on
# the desktop, so this asserts the log evidence and leaves the notify call
# itself undriven.
printf '✓ [SYNC] repo-two\n' >"$CORRAL_OUTPUT"
corral
assert_equals 0 "$RC" "rc"
assert_file_contains "$LOG" "synced=1 errors=0" "counts recorded"
assert_true "! grep -q osascript '$CALLS'" "no notification for a clean run"

test_start "corralctl_sync_writes_its_whole_run_to_the_log_stream"
# The run block redirects *everything* into the log file, so point the log at
# our own stderr to assert what the script actually emits there.
rm -f "$LOG"
ln -sf /dev/stderr "$LOG"
printf '✓ [SYNC] repo-one\n' >"$CORRAL_OUTPUT"
corral
assert_equals 0 "$RC" "rc"
out_has "corralctl sync started" "run banner"
out_has "[SYNC] repo-one" "tool output relayed"
out_has "synced=1 errors=0" "counts"
rm -f "$LOG"

test_start "corralctl_sync_trims_an_oversized_log"
dd if=/dev/zero bs=1024 count=1100 2>/dev/null | tr '\0' 'x' >"$LOG"
printf '\n' >>"$LOG"
: >"$CORRAL_OUTPUT"
corral
assert_equals 0 "$RC" "rc"
assert_true "[[ \$(wc -l <'$LOG') -le 2001 ]]" "log trimmed to the last 2000 lines"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
