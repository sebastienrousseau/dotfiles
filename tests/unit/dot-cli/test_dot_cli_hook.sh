#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# dot cli hook (plugins/cli/libexec/hook.sh): an agent's hook runs
# `dot cli hook run` with its payload; the event becomes the session's state
# (agent-event.v1) in $XDG_STATE_HOME/dot/agents/<agent>/<session>.json and a
# datagram to $XDG_RUNTIME_DIR/dot/agent-events.sock. It prints nothing,
# always exits 0, never records the prompt, and refuses ids that are not
# plain names. Every case goes through bin/dot in a sandboxed home.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-hook.XXXXXX")"
LISTENER=""
trap '[[ -z "$LISTENER" ]] || kill "$LISTENER" 2>/dev/null; rm -rf "$WORK"' EXIT
H="$WORK/home" S="$WORK/state" R="$WORK/run"
mkdir -p "$H" "$R"

# hook PAYLOAD [ARGS...]: `dot cli hook run ARGS...` with PAYLOAD on stdin;
# sets RC, OUT (stdout) and ERR (stderr).
hook() {
  local payload="$1"
  shift
  RC=0
  OUT="$(printf '%s' "$payload" | env -i HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$S" \
    XDG_RUNTIME_DIR="$R" XDG_CACHE_HOME="$H/.cache" NO_COLOR=1 TERM=dumb \
    bash "$REPO_ROOT/bin/dot" cli hook run "$@" 2>"$WORK/err")" || RC=$?
  ERR="$(cat "$WORK/err")"
}

state_of() { sed -n 's/.*"state":"\([a-z]*\)".*/\1/p' "$S/dot/agents/$1/$2.json" 2>/dev/null || true; }

test_start "a_prompt_is_running_and_never_recorded"
hook '{"session_id":"s1","hook_event_name":"UserPromptSubmit","cwd":"/work/proj","prompt":"SECRET-PROMPT"}'
assert_equals "0||" "$RC|$OUT|$ERR" "exit 0, and nothing on stdout or stderr"
assert_equals "running" "$(state_of claude s1)" "UserPromptSubmit is running"
assert_file_contains "$S/dot/agents/claude/s1.json" '"cwd":"/work/proj"' "the working directory is kept"
assert_file_not_contains "$S/dot/agents/claude/s1.json" "SECRET-PROMPT" "the prompt is not"
assert_equals "600" "$(stat -c '%a' "$S/dot/agents/claude/s1.json" 2>/dev/null || stat -f '%Lp' "$S/dot/agents/claude/s1.json")" \
  "the state file is private"

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
hook '{"session_id":"ok1","hook_event_name":"Stop"}' --agent '../evil'
hook '{"session_id":"ok2","hook_event_name":"WhoKnows"}'
hook 'not json at all'
assert_equals "0||" "$RC|$OUT|$ERR" "bad input still exits 0 silently"
assert_equals "claude codex" "$(ls "$S/dot/agents" | tr '\n' ' ' | sed 's/ $//')" "no other agent dir is made"
assert_equals "s1.json s2.json" "$(ls "$S/dot/agents/claude" | tr '\n' ' ' | sed 's/ $//')" \
  "nothing is written for a bad id or an event that says nothing about state"
assert_equals "no" "$([[ -e "$WORK/escape.json" || -e "$S/escape.json" ]] && echo yes || echo no)" "nothing outside"

test_start "a_listening_socket_gets_the_record"
mkdir -p "$R/dot"
perl -MIO::Socket::UNIX -MSocket -e '
  my $s = IO::Socket::UNIX->new(Type => SOCK_DGRAM, Local => $ARGV[0]) or die "listen: $!";
  open my $ready, ">", "$ARGV[1].ready"; close $ready;
  $s->recv(my $buf, 65536); open my $out, ">", $ARGV[1]; print $out $buf;' \
  "$R/dot/agent-events.sock" "$WORK/datagram" &
LISTENER=$!
for _ in 1 2 3 4 5 6 7 8 9 10; do [[ -f "$WORK/datagram.ready" ]] && break; sleep 0.1; done
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

test_start "status_lists_the_sessions"
RC=0
OUT="$(env -i HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$S" XDG_CACHE_HOME="$H/.cache" NO_COLOR=1 TERM=dumb \
  bash "$REPO_ROOT/bin/dot" cli hook 2>&1)" || RC=$?
assert_equals "0" "$RC" "bare dot cli hook is status and exits 0"
assert_contains "codex      idle" "$OUT" "one row per session, agent and state"
assert_contains "s3" "$OUT" "naming the session"
OUT="$(env -i HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$S" XDG_CACHE_HOME="$H/.cache" \
  bash "$REPO_ROOT/bin/dot" cli hook status --json 2>&1)"
assert_equals "5" "$(grep -c '"schema":"cli/agent-event.v1"' <<<"$OUT")" "--json prints the records"
OUT="$(env -i HOME="$H" PATH="/usr/bin:/bin" XDG_STATE_HOME="$WORK/empty" XDG_CACHE_HOME="$H/.cache" \
  bash "$REPO_ROOT/bin/dot" cli hook status 2>&1)"
assert_contains "No agent events recorded yet" "$OUT" "with none, it says so"

print_summary
