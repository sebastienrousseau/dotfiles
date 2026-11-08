#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# dot cli hook (plugins/cli/libexec/hook.sh): an agent's hook runs
# `dot cli hook run` with its payload; the event becomes the session's state
# (agent-event.v1) in $XDG_STATE_HOME/dot/cli/agents/<agent>/<session>.json and a
# datagram to $XDG_RUNTIME_DIR/dot/agent-events.sock. It prints nothing,
# always exits 0, never records the prompt, and refuses ids that are not
# plain names. Every case goes through bin/dot in a sandboxed home.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-hook.XXXXXX")"
LISTENER=""
# The runtime dir holds a socket, whose path must fit sun_path (104 bytes on
# macOS): a long $TMPDIR (a CI runner's, the mutation pool's) would overflow
# it, so this one lives under /tmp.
R="$(mktemp -d /tmp/dot-hook-run.XXXXXX)"
trap '[[ -z "$LISTENER" ]] || kill "$LISTENER" 2>/dev/null; rm -rf "$WORK" "$R"' EXIT
H="$WORK/home" S="$WORK/state"
mkdir -p "$H" "$R"
# The coverage runner's tracing, when it is on: env -i would drop it, and
# the hook's lines would run unmeasured.
COV_ENV=()
for v in BASH_ENV PS4 COV_TRACE_FILE COV_ROOT; do
  [[ -z "${!v:-}" ]] || COV_ENV+=("$v=${!v}")
done

# hook PAYLOAD [ARGS...]: `dot cli hook run ARGS...` with PAYLOAD on stdin;
# sets RC, OUT (stdout) and ERR (stderr).
hook() {
  local payload="$1"
  shift
  RC=0
  OUT="$(printf '%s' "$payload" | env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$S" \
    XDG_RUNTIME_DIR="$R" XDG_CACHE_HOME="$H/.cache" NO_COLOR=1 TERM=dumb TMUX_PANE="${HOOK_PANE:-}" \
    bash "$REPO_ROOT/bin/dot" cli hook run "$@" 2>"$WORK/err")" || RC=$?
  ERR="$(cat "$WORK/err")"
}

state_of() { sed -n 's/.*"state":"\([a-z]*\)".*/\1/p' "$S/dot/cli/agents/$1/$2.json" 2>/dev/null || true; }

test_start "a_prompt_is_running_and_never_recorded"
hook '{"session_id":"s1","hook_event_name":"UserPromptSubmit","cwd":"/work/proj","prompt":"SECRET-PROMPT"}'
assert_equals "0||" "$RC|$OUT|$ERR" "exit 0, and nothing on stdout or stderr"
assert_equals "running" "$(state_of claude s1)" "UserPromptSubmit is running"
assert_file_contains "$S/dot/cli/agents/claude/s1.json" '"cwd":"/work/proj"' "the working directory is kept"
assert_file_not_contains "$S/dot/cli/agents/claude/s1.json" "SECRET-PROMPT" "the prompt is not"
assert_equals "600" "$(stat -c '%a' "$S/dot/cli/agents/claude/s1.json" 2>/dev/null || stat -f '%Lp' "$S/dot/cli/agents/claude/s1.json")" \
  "the state file is private"

# Inside tmux the record names the agent's pane ($TMUX_PANE), so dot ai wait
# can follow an agent it started in a tmux session; anything that is not a
# pane id is left out.
test_start "the_tmux_pane_is_recorded"
HOOK_PANE=%7 hook '{"session_id":"p1","hook_event_name":"Stop"}'
assert_file_contains "$S/dot/cli/agents/claude/p1.json" '"pane":"%7"}' "the pane closes the record"
HOOK_PANE='%7",' hook '{"session_id":"p2","hook_event_name":"Stop"}'
assert_file_not_contains "$S/dot/cli/agents/claude/p2.json" '"pane"' "a pane that is not %N is left out"
hook '{"session_id":"p3","hook_event_name":"Stop"}'
assert_file_not_contains "$S/dot/cli/agents/claude/p3.json" '"pane"' "outside tmux there is none"
rm -f "$S"/dot/cli/agents/claude/p[123].json

test_start "events_map_to_the_normalised_states"
for pair in "PermissionRequest:blocked" "Elicitation:blocked" "Stop:idle" "StopFailure:error" \
  "SessionStart:idle" "PreToolUse:running" "SessionEnd:gone"; do
  hook "{\"session_id\":\"s2\",\"hook_event_name\":\"${pair%%:*}\"}"
  assert_equals "${pair#*:}" "$(state_of claude s2)" "${pair%%:*} is ${pair#*:}"
done
hook '{"session_id":"s2","hook_event_name":"Notification","notification_type":"permission_prompt"}'
assert_equals "blocked" "$(state_of claude s2)" "a permission notification is blocked"
hook '{"session_id":"s2","hook_event_name":"Notification","notification_type":"idle_prompt"}'
assert_equals "idle" "$(state_of claude s2)" "an idle_prompt notification is idle"

test_start "codex_notify_passes_the_payload_as_an_argument"
hook '' --agent codex '{"type":"agent-turn-complete","thread-id":"t-9","cwd":"/w"}'
assert_equals "0|idle" "$RC|$(state_of codex t-9)" "agent-turn-complete is idle, under the codex agent"

test_start "ids_that_are_not_plain_names_are_refused"
hook '{"session_id":"../../escape","hook_event_name":"Stop"}'
hook '{"session_id":".hidden","hook_event_name":"Stop"}'
# A valid tail after a path does not make a plain id.
hook '{"session_id":"/stray","hook_event_name":"Stop"}'
hook '{"session_id":"ok3","hook_event_name":"Stop"}' --agent 'x/claude'
hook '{"session_id":"ok1","hook_event_name":"Stop"}' --agent '../evil'
hook '{"session_id":"ok2","hook_event_name":"WhoKnows"}'
hook 'not json at all'
assert_equals "0||" "$RC|$OUT|$ERR" "bad input still exits 0 silently"
assert_equals "claude codex" "$(ls "$S/dot/cli/agents" | tr '\n' ' ' | sed 's/ $//')" "no other agent dir is made"
assert_equals "s1.json s2.json" "$(ls "$S/dot/cli/agents/claude" | tr '\n' ' ' | sed 's/ $//')" \
  "nothing is written for a bad id or an event that says nothing about state"
assert_equals "no" "$([[ -e "$WORK/escape.json" || -e "$S/escape.json" ]] && echo yes || echo no)" "nothing outside"

test_start "a_listening_socket_gets_the_record"
mkdir -p "$R/dot"
# At most 10 s: no datagram must fail the test, not hang it.
perl -MIO::Socket::UNIX -MSocket -e '
  $SIG{ALRM} = sub { exit 1 }; alarm 10;
  my $s = IO::Socket::UNIX->new(Type => SOCK_DGRAM, Local => $ARGV[0]) or die "listen: $!";
  open my $ready, ">", "$ARGV[1].ready"; close $ready;
  $s->recv(my $buf, 65536); open my $out, ">", $ARGV[1]; print $out $buf;' \
  "$R/dot/agent-events.sock" "$WORK/datagram" &
LISTENER=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [[ -f "$WORK/datagram.ready" ]] && break
  sleep 0.1
done
hook '{"session_id":"s3","hook_event_name":"Stop","cwd":"/w"}'
wait "$LISTENER" 2>/dev/null
LISTENER=""
assert_contains '"schema":"cli/agent-event.v1"' "$(cat "$WORK/datagram" 2>/dev/null)" "the datagram is the record"
assert_contains '"session":"s3","state":"idle"' "$(cat "$WORK/datagram" 2>/dev/null)" "for that session"

test_start "a_lock_on_cli_does_not_hold_the_hook"
mkdir -p "$S/dot/cli"
sleep 30 &
holder=$!
ln -sfn "$holder" "$S/dot/cli/lock"
hook '{"session_id":"s4","hook_event_name":"Stop"}'
kill "$holder" 2>/dev/null
assert_equals "0|idle" "$RC|$(state_of claude s4)" "dot cli hook run is lock = false"

record_of() { cat "$S/dot/cli/agents/$1/$2.json" 2>/dev/null || true; }

test_start "the_record_escapes_quotes_backslashes_and_drops_control_characters"
hook '{"session_id":"s5","hook_event_name":"Stop","cwd":"/w/a\"b\\c\td\u0001e"}'
assert_contains '"cwd":"/w/a\"b\\cde"}' "$(record_of claude s5)" "quote and backslash escaped, tab and U+0001 dropped"
assert_equals "/w/a\"b\\cde" "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["cwd"])' \
  "$S/dot/cli/agents/claude/s5.json" 2>&1)" "the record parses back to the same directory"

test_start "a_field_that_is_not_a_string_counts_as_unset"
hook '{"session_id":"s6","hook_event_name":7,"type":"agent-turn-complete","cwd":["/x"]}'
assert_equals "idle" "$(state_of claude s6)" "a numeric hook_event_name falls back to type"
assert_contains '"cwd":""}' "$(record_of claude s6)" "an array cwd is empty"

test_start "the_time_is_utc_on_this_bash_too"
# bin/dot runs under whichever bash is first on PATH: /bin/bash 3.2 on
# macOS (the cases above), a bash with printf %()T elsewhere.
printf '%s' '{"session_id":"s7","hook_event_name":"Stop"}' | env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="/usr/bin:/bin" \
  XDG_STATE_HOME="$S" XDG_RUNTIME_DIR="$R" TZ=Asia/Tokyo "$BASH" "$REPO_ROOT/bin/dot" cli hook run >/dev/null 2>&1
want="$(date -u +%Y-%m-%dT%H:%M)"
assert_contains "\"time\":\"$want" "$(record_of claude s7)" "bash $BASH_VERSION writes UTC with TZ set elsewhere"

test_start "without_jq_the_fields_are_still_read"
NOJQ="$WORK/nojq"
mkdir -p "$NOJQ"
for t in bash sed head mv mkdir rm date perl cat; do
  p="$(PATH=/usr/bin:/bin command -v "$t")" && ln -s "$p" "$NOJQ/$t"
done
printf '%s' '{"session_id":"s8","hook_event_name":"PermissionRequest","cwd":"/nojq"}' | env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" \
  PATH="$NOJQ" XDG_STATE_HOME="$S" XDG_RUNTIME_DIR="$R" bash "$REPO_ROOT/bin/dot" cli hook run >/dev/null 2>&1
assert_equals "blocked" "$(state_of claude s8)" "the state comes from sed"
assert_contains '"cwd":"/nojq"}' "$(record_of claude s8)" "and the directory"

test_start "help_still_reaches_the_help_page"
OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$S" XDG_CACHE_HOME="$H/.cache" NO_COLOR=1 TERM=dumb \
  bash "$REPO_ROOT/bin/dot" cli hook run --help 2>&1)"
assert_contains "cli" "$OUT" "dot cli hook run --help shows help"
assert_equals "no" "$([[ -e "$S/dot/cli/agents/claude/--help.json" ]] && echo yes || echo no)" "and records nothing"

test_start "status_lists_the_sessions"
RC=0
OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$S" XDG_CACHE_HOME="$H/.cache" NO_COLOR=1 TERM=dumb \
  bash "$REPO_ROOT/bin/dot" cli hook 2>&1)" || RC=$?
assert_equals "0" "$RC" "bare dot cli hook is status and exits 0"
assert_contains "codex      idle" "$OUT" "one row per session, agent and state"
assert_contains "s3" "$OUT" "naming the session"
OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$S" XDG_CACHE_HOME="$H/.cache" \
  bash "$REPO_ROOT/bin/dot" cli hook status --json 2>&1)"
assert_equals "9" "$(grep -c '"schema":"cli/agent-event.v1"' <<<"$OUT")" "--json prints the records"
OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$WORK/empty" XDG_CACHE_HOME="$H/.cache" \
  bash "$REPO_ROOT/bin/dot" cli hook status 2>&1)"
assert_contains "No agent events recorded yet" "$OUT" "with none, it says so"

test_start "live_status_leaves_out_gone_and_old_sessions"
L="$WORK/live/dot/cli/agents"
mkdir -p "$L/codex" "$L/claude"
now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
live_rec() { printf '{"schema":"cli/agent-event.v1","time":"%s","agent":"%s","session":"%s","state":"%s","event":"E","cwd":"/p"}\n' "$1" "$2" "$3" "$4"; }
live_rec "$now_iso" codex now running >"$L/codex/now.json"
live_rec "$now_iso" claude ended gone >"$L/claude/ended.json"
live_rec "2020-01-01T00:00:00Z" codex stale idle >"$L/codex/stale.json"
live() {
  env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$WORK/live" XDG_CACHE_HOME="$H/.cache" \
    NO_COLOR=1 TERM=dumb bash "$REPO_ROOT/plugins/cli/libexec/hook.sh" --status --live "$@" 2>&1
}
OUT="$(live)"
assert_contains "codex      running" "$OUT" "a session active in the last 24 h is listed"
assert_equals "no|no" "$([[ "$OUT" == *ended* ]] && echo yes || echo no)|$([[ "$OUT" == *stale* ]] && echo yes || echo no)" \
  "a gone session and one silent for a day are not"
OUT="$(live --json)"
assert_equals "1" "$(grep -c '"schema"' <<<"$OUT")" "--json prints only the live record"
OUT="$(BASH_ENV= env -i HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$WORK/live" /bin/bash "$REPO_ROOT/plugins/cli/libexec/hook.sh" --status --live --json 2>&1)"
assert_contains '"session":"now"' "$OUT" "macOS /bin/bash 3.2 finds the cutoff with date"
assert_equals "1" "$(grep -c '"schema"' <<<"$OUT")" "and filters the same way"
rm -f "$L/codex/now.json"
OUT="$(live)"
assert_contains "No agent sessions in the last 24 hours" "$OUT" "with none live, it says so"

print_summary
