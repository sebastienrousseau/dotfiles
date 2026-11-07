#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# dot cli hook run [--agent <id>] [<payload>] — receive one agent hook event;
# dot cli hook [status] [--json] — each agent session's last state.
#
# An agent's hook (Claude Code, Gemini CLI, Codex) runs this with its JSON
# payload on stdin, or, as Codex's notify does, as the last argument. The
# event becomes the agent's normalised state (agent-event.v1,
# schemas/cli/agent-event.v1.schema.json):
#
#   UserPromptSubmit, BeforeAgent, PreToolUse, PostToolUse   running
#   PermissionRequest, Notification, Elicitation            blocked
#   Stop, AfterAgent, SessionStart, idle_prompt, agent-turn-complete  idle
#   StopFailure                                              error
#   SessionEnd                                               gone
#
# It writes the last state to $XDG_STATE_HOME/dot/cli/agents/<agent>/<session>.json,
# so dot session works with no monitor running, and sends the record as a
# datagram to $XDG_RUNTIME_DIR/dot/agent-events.sock ($TMPDIR on macOS) when
# a socket of this user's listens there (dot top), giving up after 50 ms.
# Metadata only: the prompt, tool input and output in the payload are never
# read into the record.
#
# A hook must not get in the agent's way: this prints nothing (Claude Code
# adds a UserPromptSubmit hook's stdout to the prompt), except {} for Gemini
# CLI, which reads it as JSON, and always exits 0.

set -uo pipefail

# The hook runs on every prompt, tool call and stop of every agent, so the
# event path forks only jq (once), mv, and perl when a listener is there:
# the fields come from one jq call, the time from printf, and the record is
# built in place. tools/ci/hook-bench.sh holds it to its
# p95 budget.

# _hook_field JSON NAME: the string value of top-level key NAME; empty when
# absent. jq when installed; else the first "NAME": "value" pair.
_hook_field() {
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$2" '.[$k] // empty | strings' <<<"$1" 2>/dev/null
  else
    sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" <<<"$1" | head -n 1
  fi
}

# _hook_fields JSON: sets H_EVENT, H_SESSION, H_NTYPE and H_CWD from the
# payload, each empty unless a string, control characters dropped. Event
# and session take the first set of hook_event_name/type and
# session_id/thread-id (Codex names them so). One jq call; without jq, one
# sed per field.
_hook_fields() {
  local out sep=$'\037'
  if command -v jq >/dev/null 2>&1; then
    out="$(jq -r 'def s: if type == "string" then gsub("[[:cntrl:]]"; "") else "" end;
      def pick(a; b): (a | s) as $v | if $v == "" then b | s else $v end;
      [pick(.hook_event_name; .type), pick(.session_id; ."thread-id"), (.notification_type | s), (.cwd | s)]
      | join("\u001f")' <<<"$1" 2>/dev/null)"
    IFS="$sep" read -r H_EVENT H_SESSION H_NTYPE H_CWD <<<"$out"
  else
    H_EVENT="$(_hook_first "$1" hook_event_name type)"
    H_SESSION="$(_hook_first "$1" session_id thread-id)"
    H_NTYPE="$(_hook_field "$1" notification_type)"
    H_CWD="$(_hook_field "$1" cwd)"
    H_EVENT="${H_EVENT//[[:cntrl:]]/}" H_SESSION="${H_SESSION//[[:cntrl:]]/}"
    H_NTYPE="${H_NTYPE//[[:cntrl:]]/}" H_CWD="${H_CWD//[[:cntrl:]]/}"
  fi
}

# _hook_state EVENT NOTIFICATION_TYPE: sets H_STATE, the normalised state;
# empty for an event that says nothing about it.
_hook_state() {
  case "$1" in
    UserPromptSubmit | BeforeAgent | PreToolUse | PostToolUse) H_STATE=running ;;
    Notification) if [[ "$2" == idle_prompt ]]; then H_STATE=idle; else H_STATE=blocked; fi ;;
    PermissionRequest | Elicitation) H_STATE=blocked ;;
    Stop | AfterAgent | SessionStart | agent-turn-complete) H_STATE=idle ;;
    StopFailure) H_STATE=error ;;
    SessionEnd) H_STATE=gone ;;
    *) H_STATE="" ;;
  esac
}

# _hook_json_str VAR TEXT: sets VAR to TEXT as a JSON string (quotes and
# backslashes escaped; the caller has dropped control characters).
_hook_json_str() {
  local s="${2//\\/\\\\}"
  printf -v "$1" '"%s"' "${s//\"/\\\"}"
}

# _hook_now: sets H_NOW to the UTC time, from printf where bash has %()T
# (4.2+), else date (macOS /bin/bash 3.2).
_hook_now() {
  if ((BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 2))); then
    TZ=UTC0 printf -v H_NOW '%(%Y-%m-%dT%H:%M:%SZ)T' -1
  else
    H_NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  fi
}

# _hook_send SOCKET RECORD: one datagram, best effort, 50 ms at most, and
# only to a socket this user owns.
_hook_send() {
  [[ -S "$1" && -O "$1" ]] || return 0
  command -v perl >/dev/null 2>&1 || return 0
  perl -MIO::Socket::UNIX -MSocket -MTime::HiRes=alarm -e '
    $SIG{ALRM} = sub { exit 0 }; alarm(0.05);
    my $s = IO::Socket::UNIX->new(Type => SOCK_DGRAM, Peer => $ARGV[0]) or exit 0;
    $s->send($ARGV[1]);' "$1" "$2" 2>/dev/null || true
}

# _hook_payload ARG...: sets H_PAYLOAD, the last argument (Codex notify) or
# stdin (Claude Code, Gemini CLI); at most 2 s waiting on stdin.
_hook_payload() {
  H_PAYLOAD=""
  if [[ $# -gt 0 ]]; then
    H_PAYLOAD="${!#}"
  elif [[ ! -t 0 ]]; then
    IFS= read -r -d '' -t 2 H_PAYLOAD || true
  fi
}

# _hook_first JSON NAME...: the first of those fields that is set.
_hook_first() {
  local json="$1" name value
  shift
  for name in "$@"; do
    value="$(_hook_field "$json" "$name")"
    [[ -z "$value" ]] || break
  done
  printf '%s' "$value"
}

# _hook_ids_ok AGENT SESSION: both become a path, so a plain id only.
_hook_ids_ok() {
  [[ "$1" =~ ^[a-z][a-z0-9-]{0,31}$ ]] || return 1
  [[ "$2" =~ ^[A-Za-z0-9._-]{1,128}$ && "$2" != .* ]]
}

# _hook_write AGENT SESSION RECORD: replace the session's state file
# (private: hook_main sets umask 077), making its directory only when it is
# missing.
_hook_write() {
  local dir="${XDG_STATE_HOME:-$HOME/.local/state}/dot/cli/agents/$1"
  [[ -d "$dir" ]] || mkdir -p "$dir" 2>/dev/null || return 0
  { printf '%s\n' "$3" >"$dir/$2.json.$$" && mv -f "$dir/$2.json.$$" "$dir/$2.json"; } 2>/dev/null ||
    rm -f "$dir/$2.json.$$" 2>/dev/null
}

hook_main() {
  local agent=claude record event cwd dir
  if [[ "${1:-}" == --agent ]]; then
    agent="${2:-}"
    shift 2 || return 0
  fi
  umask 077
  _hook_payload "$@"
  _hook_fields "$H_PAYLOAD"
  _hook_state "$H_EVENT" "$H_NTYPE"
  [[ -n "$H_STATE" ]] && _hook_ids_ok "$agent" "$H_SESSION" || return 0
  _hook_now
  _hook_json_str event "$H_EVENT"
  _hook_json_str cwd "$H_CWD"
  record="{\"schema\":\"cli/agent-event.v1\",\"time\":\"$H_NOW\",\"agent\":\"$agent\",\"session\":\"$H_SESSION\",\"state\":\"$H_STATE\",\"event\":$event,\"cwd\":$cwd}"
  _hook_write "$agent" "$H_SESSION" "$record"
  # A per-user runtime dir only: a shared /tmp would let another user listen.
  dir="${XDG_RUNTIME_DIR:-${TMPDIR:-}}"
  [[ -z "$dir" ]] || _hook_send "${dir%/}/dot/agent-events.sock" "$record"
}

# hook_status [--json]: each agent session's last state (dot cli hook
# status), newest first; --json prints the records, one per line.
hook_status() {
  local dir="${XDG_STATE_HOME:-$HOME/.local/state}/dot/cli/agents" f rec
  local -a files=()
  for f in "$dir"/*/*.json; do [[ -f "$f" ]] && files+=("$f"); done
  if ((${#files[@]} == 0)); then
    echo "No agent events recorded yet: an agent's hooks report them with 'dot cli hook run'."
    return 0
  fi
  [[ "${1:-}" != --json ]] || {
    cat "${files[@]}"
    return 0
  }
  printf '%-10s %-8s %-20s %s\n' AGENT STATE TIME SESSION
  for f in "${files[@]}"; do
    rec="$(cat "$f")"
    printf '%s\t%-10s %-8s %-20s %s\n' "$(_hook_field "$rec" time)" "$(_hook_field "$rec" agent)" \
      "$(_hook_field "$rec" state)" "$(_hook_field "$rec" time)" "$(_hook_field "$rec" session)"
  done | sort -r | cut -f2-
}

if [[ "${1:-}" == --status ]]; then
  hook_status "${@:2}"
  exit 0
fi
hook_main "$@" >/dev/null 2>&1
# Gemini CLI reads a hook's stdout as JSON: {} says "nothing to change".
[[ "${1:-} ${2:-}" != "--agent gemini" ]] || printf '{}\n'
exit 0
