#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016 # the fakes are written with literal $
# dot ai start --bg / send / wait (plugins/ai/libexec/ai/runtime.sh on
# lib/dot/agent-runtime.sh). On herdr-core, a fake herdr-core records the
# calls and answers as hc's API schema says. On tmux, a real tmux server on
# a private socket runs a fake agent that reports through the real hook
# (dot cli hook run), so wait follows real state files by pane. HOME is a
# temp dir; no real terminal or agent is touched.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

# Under /tmp: tmux's socket path must fit sun_path.
WORK="$(mktemp -d /tmp/dot-rt.XXXXXX)"
SOCK="dot-rt-$$"
trap 'tmux -L "$SOCK" kill-server 2>/dev/null; rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home"

# The fake herdr-core: each call is logged; ls and wait answer from files.
cat >"$WORK/bin/herdr-core" <<'EOF'
#!/bin/sh
echo "hc $*" >>"$WORK/calls"
case "$1" in
  ls)
    [ -z "${FAIL_HC_LS:-}" ] || exit 1
    cat "$WORK/hc-ls" 2>/dev/null || echo '{"terminals":[],"hidden_finished":0,"machines":[]}'
    ;;
  wait) cat "$WORK/hc-wait" ;;
  send) [ -z "${FAIL_HC_SEND:-}" ] || exit 1 ;;
esac
exit "${FAIL_HC:-0}"
EOF
# The fake agent: reports SessionStart through the real hook, then for each
# line typed into it, running, then idle a moment later.
cat >"$WORK/bin/claude" <<'EOF'
#!/bin/bash
hook() { printf '{"session_id":"%s","hook_event_name":"%s"}' "fake-$$" "$1" | bash "$REPO_ROOT/bin/dot" cli hook run; }
hook SessionStart
while IFS= read -r line; do
  printf '%s\n' "$line" >>"$WORK/typed"
  hook UserPromptSubmit
  sleep "${AGENT_SECONDS:-2}"
  hook Stop
done
EOF
printf '#!/bin/sh\nexec tmux -L "%s" "$@"\n' "$SOCK" >"$WORK/tmux"
chmod +x "$WORK/bin/herdr-core" "$WORK/bin/claude" "$WORK/tmux"

MARKS="$WORK/home/.local/state/dot/ai/runtime"

# ai RUNTIME ARGS...: the real `dot ai` route ($AI_PATH replaces the PATH);
# sets RC and OUT (both streams).
ai() {
  local runtime="$1"
  shift
  RC=0
  OUT="$(env -u TMUX -u TMUX_PANE -u XDG_STATE_HOME HOME="$WORK/home" XDG_CONFIG_HOME="$WORK/home/.config" \
    PATH="${AI_PATH:-$WORK/bin:$PATH}" WORK="$WORK" \
    REPO_ROOT="$REPO_ROOT" DOT_RUNTIME="$runtime" DOT_TMUX="$WORK/tmux" DOT_RT_POLL=0.2 DOT_RT_READY=10 \
    NO_COLOR=1 bash "$REPO_ROOT/bin/dot" ai "$@" 2>&1)" || RC=$?
}
calls() { paste -sd '|' "$WORK/calls" 2>/dev/null; }

test_start "hc_start_names_and_starts_the_agent"
: >"$WORK/calls"
ai hc start --bg claude
assert_equals "0" "$RC" "starts"
assert_equals "hc ls --json|hc run --bg --name claude-1 --label dot=agent -- $WORK/bin/claude" "$(calls)" \
  "the first free name, labelled, the roster's binary"
assert_contains "Started claude-1 (claude, on hc)" "$OUT" "says what it started"
echo '{"terminals":[{"address":"t1","name":"claude-1"},{"address":"t2","name":"claude-2"}],"hidden_finished":0,"machines":[]}' >"$WORK/hc-ls"
: >"$WORK/calls"
ai hc start --bg --cwd /src claude
assert_contains "hc run --bg --name claude-3 --cwd /src" "$(calls)" "the next free name, in --cwd"
rm -f "$WORK/hc-ls"
: >"$WORK/calls"
FAIL_HC_LS=1 ai hc start --bg claude
assert_equals "0" "$RC" "an hc ls that fails leaves every name free"
assert_contains "--name claude-1" "$(calls)" "and the first is taken"

test_start "hc_start_with_a_task_waits_for_the_agent_then_sends_it"
echo '{"terminal":"t1","ended":true,"reason":"status","status":"idle","turn":0,"children":[]}' >"$WORK/hc-wait"
: >"$WORK/calls"
ai hc start --bg --name rev claude review src/x.rs
assert_equals "hc run --bg --name rev --label dot=agent -- $WORK/bin/claude|hc wait rev --timeout 10 --json|hc send rev review src/x.rs" \
  "$(calls)" "starts, waits for its first report, sends the task as one line"
FAIL_HC_SEND=1 ai hc start --bg --name rev2 claude review
assert_equals "1" "$RC" "a task that cannot be sent fails the start"
assert_false "[[ '$OUT' == *Started* ]]" "and claims nothing"

test_start "hc_send_and_wait"
: >"$WORK/calls"
ai hc send rev "and the error path"
assert_equals "0|hc send rev and the error path" "$RC|$(calls)" "send"
: >"$WORK/calls"
ai hc wait rev --timeout 5
assert_equals "0|hc wait rev --timeout 5 --json" "$RC|$(calls)" "wait on one"
assert_equals "rev: idle" "$OUT" "by its name, with the state it reported"
echo '{"terminal":"t9","ended":true,"reason":"children","turn":0,"children":[
  {"terminal":"t1","ended":true,"reason":"status","status":"blocked","turn":1,"children":[]},
  {"terminal":"t2","ended":true,"reason":"exit","status":null,"turn":1,"children":[]}]}' >"$WORK/hc-wait"
: >"$WORK/calls"
ai hc wait
assert_equals "hc wait --children all --timeout 180 --json" "$(calls)" "no name: this terminal's children, 180 s"
assert_equals $'t1: blocked\nt2: exit' "$OUT" "one line per child"
echo '{"terminal":"t1","ended":false,"reason":"timeout","status":"working","turn":1,"children":[]}' >"$WORK/hc-wait"
ai hc wait rev --timeout 1
assert_equals "124" "$RC" "still working after the timeout: 124"
assert_contains "rev: working" "$OUT" "and its state"

test_start "usage_and_refusals"
ai hc start --bg
assert_equals "1" "$RC" "no agent"
ai hc start --bg no-such-agent
assert_equals "1" "$RC" "an agent outside the roster fails"
assert_contains "not an agent dot ai knows" "$OUT" "and says so"
: >"$WORK/calls"
AI_PATH="$WORK/bin:/usr/bin:/bin" ai hc start --bg codex
assert_equals "1" "$RC" "an agent that is not installed fails"
assert_contains "not installed: dot ai install codex" "$OUT" "and says how to install it"
assert_equals "" "$(calls)" "and starts nothing"
FAIL_HC=1 ai hc start --bg --name busy claude
assert_equals "1" "$RC" "a start hc refuses fails"
assert_contains "could not start" "$OUT" "and says so"
ai hc start --bg --name 'Bad Name' claude
assert_contains "1-32 of a-z 0-9 - _" "$OUT" "a name hc would refuse"
ai hc send rev
assert_equals "1" "$RC" "send needs text"
ai hc wait --timeout soon
assert_equals "1" "$RC" "a timeout is seconds"
ai hc wait --timeout soon5
assert_equals "1" "$RC" "all of it"
ai hc wait a b
assert_equals "1" "$RC" "one name at most"
ai hc start --bg --name
assert_equals "1" "$RC" "--name needs a value"
assert_contains "Usage" "$OUT" "and gets the usage"
ai hc start --bg --frob claude
assert_equals "1" "$RC" "an unknown option"
assert_contains "Usage" "$OUT" "and gets the usage, not taken for an agent"
FAIL_HC=1 ai hc wait rev
assert_equals "1" "$RC" "an hc wait that fails is an error"
OUT="$(env -u DOT_RUNTIME HOME="$WORK/home" PATH="/usr/bin:/bin" DOT_HC=/nonexistent DOT_TMUX=/nonexistent \
  NO_COLOR=1 /bin/bash "$REPO_ROOT/bin/dot" ai send rev hi 2>&1)" && RC=0 || RC=$?
assert_equals "1" "$RC" "neither herdr-core nor tmux"
assert_contains "dot ai install hc" "$OUT" "says how to get one"
OUT="$(env -u DOT_RUNTIME HOME="$WORK/home" PATH="/usr/bin:/bin" DOT_HC=/nonexistent DOT_TMUX=/nonexistent \
  NO_COLOR=1 /bin/bash "$REPO_ROOT/bin/dot" ai wait rev 2>&1)" && RC=0 || RC=$?
assert_equals "1" "$RC" "wait too"
assert_false "[[ '$OUT' == *'no session'* ]]" "and stops there, never asking a runtime it lacks"
OUT="$(env -u DOT_RUNTIME HOME="$WORK/home" PATH="$WORK/bin:/usr/bin:/bin" DOT_HC=/nonexistent DOT_TMUX=/nonexistent \
  NO_COLOR=1 /bin/bash "$REPO_ROOT/bin/dot" ai start --bg claude 2>&1)" && RC=0 || RC=$?
assert_equals "1" "$RC" "start --bg too"

test_start "delegate_is_retired_onto_start_and_wait"
echo '{"terminal":"t1","ended":true,"reason":"status","status":"idle","turn":1,"children":[]}' >"$WORK/hc-wait"
: >"$WORK/calls"
ai hc delegate "add a CHANGELOG entry" 10 claude 60
assert_equals "0" "$RC" "still works"
assert_contains "retired: dot ai start --bg" "$OUT" "and says what replaces it"
assert_contains "hc send claude-1 add a CHANGELOG entry|hc wait claude-1 --timeout 60 --json" "$(calls)" \
  "the task goes to a background claude, then it waits with the timeout given"
: >"$WORK/calls"
ai hc delegate "fix the typo"
assert_equals "0" "$RC" "the prompt alone will do"
assert_contains "hc send claude-1 fix the typo|hc wait claude-1 --timeout 180 --json" "$(calls)" \
  "claude, and wait's own timeout"

test_start "a_report_counts_from_the_start_second_or_after_a_send"
counts() { (source "$REPO_ROOT/lib/dot/agent-runtime.sh" && _dot_rt_counts "$@") && echo yes || echo no; }
T=2026-11-08T10:00:00Z
assert_equals "yes" "$(counts "" "" 2020-01-01T00:00:00Z)" "nothing marked: any report"
assert_equals "yes" "$(counts ge "$T" "$T")" "the agent may report in its start second"
assert_equals "no" "$(counts gt "$T" "$T")" "not in a send's second: that is the last turn"
assert_equals "yes" "$(counts gt "$T" 2026-11-08T10:00:01Z)" "after it"
assert_equals "no" "$(counts ge "$T" 2026-11-08T09:59:59Z)" "never before the start"

# ── tmux, for real ───────────────────────────────────────────────────────
if command -v tmux >/dev/null 2>&1; then
  ready() { (
    unset XDG_STATE_HOME
    export HOME="$WORK/home" DOT_TMUX="$WORK/tmux" DOT_RT_POLL=0.2
    source "$REPO_ROOT/lib/dot/agent-runtime.sh" && dot_rt_ready tmux "$@"
  ) && echo ready || echo "not ready"; }
  test_start "tmux_start_send_and_wait_follow_the_agent_by_pane"
  ai tmux wait
  assert_equals "1" "$RC" "no agent started yet: nothing to wait for"
  ai tmux start --bg --name t1 claude "first task"
  assert_equals "0" "$RC" "starts in a detached tmux session"
  assert_equals "t1 1" "$("$WORK/tmux" list-sessions -F '#{session_name} #{@dot_agent}')" "named, marked as an agent"
  ai tmux wait t1 --timeout 20
  assert_equals "0|t1: idle" "$RC|$OUT" "the task's turn ran and ended"
  assert_equals "first task" "$(cat "$WORK/typed" 2>/dev/null)" "the task was typed after the agent reported"
  assert_contains "gt " "$(cat "$MARKS/t1")" "the send is marked, so a wait follows its turn"
  assert_equals "ready" "$(ready t1 5)" "an agent that has reported is ready"
  # A pane in a mode (tmux shows a config's errors in view mode) would
  # swallow the keys: send leaves the mode first.
  "$WORK/tmux" copy-mode -t "$("$WORK/tmux" list-panes -t =t1: -F '#{pane_id}')"
  AGENT_SECONDS=1 ai tmux send t1 "second task"
  ai tmux wait t1 --timeout 20
  assert_equals "0|t1: idle" "$RC|$OUT" "a wait after a send waits for that turn, not the last idle"
  assert_equals $'first task\nsecond task' "$(cat "$WORK/typed")" "both reached it"
  ai tmux wait --timeout 20
  assert_equals "0|t1: idle" "$RC|$OUT" "no name: every agent started with --bg"
  ai tmux wait nope
  assert_equals "1" "$RC" "no such session"

  test_start "tmux_wait_times_out_and_sees_an_exit"
  "$WORK/tmux" new-session -d -s quiet 'sleep 30'
  "$WORK/tmux" set-option -q -t =quiet: @dot_agent 1
  ai tmux wait quiet --timeout 1
  assert_equals "124" "$RC" "an agent that never reports counts as working"
  assert_contains "still working after 1s" "$OUT" "and the wait says so"
  "$WORK/tmux" kill-session -t =quiet:
  ai tmux wait t1 --timeout 1
  assert_equals "0" "$RC" "the others are unaffected"
  "$WORK/tmux" kill-session -t =t1:
  ai tmux start --bg --name t2 claude
  "$WORK/tmux" kill-session -t =t2:
  ai tmux send t2 hi
  assert_equals "1" "$RC" "send to a gone session fails"
  assert_contains "ge " "$(cat "$MARKS/t2")" "and marks nothing: the start's mark stays"
  # Started as dot would: marked, so the records of an earlier server's %0
  # (this server is new: killing its last session ended the old one) do not
  # count. A second passes first: t2's agent reported for its %0 just now.
  sleep 1.1
  printf 'ge %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >"$MARKS/mute"
  "$WORK/tmux" new-session -d -s mute 'sleep 30'
  assert_equals "not ready" "$(ready mute 1)" "an agent that never reports is not ready after the timeout"
  "$WORK/tmux" kill-session -t =mute:
else
  echo "  - tmux not installed: the tmux runtime cases are skipped"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
