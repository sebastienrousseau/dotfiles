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
# adds a UserPromptSubmit hook's stdout to the prompt) and always exits 0.

set -uo pipefail

# _hook_field JSON NAME: the string value of top-level key NAME; empty when
# absent. jq when installed; else the first "NAME": "value" pair.
_hook_field() {
  if command -v jq >/dev/null 2>&1; then
    jq -r --arg k "$2" '.[$k] // empty | strings' <<<"$1" 2>/dev/null
  else
    sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p" <<<"$1" | head -n 1
  fi
}

# _hook_state EVENT NOTIFICATION_TYPE: the normalised state; empty for an
# event that says nothing about it.
_hook_state() {
  case "$1" in
    UserPromptSubmit | BeforeAgent | PreToolUse | PostToolUse) echo running ;;
    Notification) if [[ "$2" == idle_prompt ]]; then echo idle; else echo blocked; fi ;;
    PermissionRequest | Elicitation) echo blocked ;;
    Stop | AfterAgent | SessionStart | agent-turn-complete) echo idle ;;
    StopFailure) echo error ;;
    SessionEnd) echo gone ;;
  esac
}

# _hook_json_str TEXT: TEXT as a JSON string (quotes, backslashes and
# control characters escaped or dropped).
_hook_json_str() {
  local s="${1//\\/\\\\}"
  s="${s//\"/\\\"}"
  printf '"%s"' "$(printf '%s' "$s" | LC_ALL=C tr -d '\000-\037\177')"
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

# _hook_payload ARG...: the payload, the last argument (Codex notify) or
# stdin (Claude Code, Gemini CLI); at most 2 s waiting on stdin.
_hook_payload() {
  local payload=""
  if [[ $# -gt 0 ]]; then
    payload="${!#}"
  elif [[ ! -t 0 ]]; then
    IFS= read -r -d '' -t 2 payload || true
  fi
  printf '%s' "$payload"
}

# _hook_first JSON NAME...: the first of the NAMEd fields that is set.
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

# _hook_write AGENT SESSION RECORD: replace the session's state file.
_hook_write() {
  local dir="${XDG_STATE_HOME:-$HOME/.local/state}/dot/cli/agents/$1"
  (umask 077 && mkdir -p "$dir" && printf '%s\n' "$3" >"$dir/$2.json.$$" &&
    mv -f "$dir/$2.json.$$" "$dir/$2.json") 2>/dev/null || rm -f "$dir/$2.json.$$" 2>/dev/null
}

hook_main() {
  local agent=claude payload event session state record dir
  if [[ "${1:-}" == --agent ]]; then
    agent="${2:-}"
    shift 2 || return 0
  fi
  payload="$(_hook_payload "$@")"
  event="$(_hook_first "$payload" hook_event_name type)"
  session="$(_hook_first "$payload" session_id thread-id)"
  state="$(_hook_state "$event" "$(_hook_field "$payload" notification_type)")"
  [[ -n "$state" ]] && _hook_ids_ok "$agent" "$session" || return 0
  record="$(printf '{"schema":"cli/agent-event.v1","time":"%s","agent":"%s","session":"%s","state":"%s","event":%s,"cwd":%s}' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$agent" "$session" "$state" "$(_hook_json_str "$event")" \
    "$(_hook_json_str "$(_hook_field "$payload" cwd)")")"
  _hook_write "$agent" "$session" "$record"
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
exit 0
