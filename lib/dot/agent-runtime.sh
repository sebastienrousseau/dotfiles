#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by plugins/ai/libexec/ai/runtime.sh and plugins/session/dot-session;
# inherits set -euo pipefail.
# The agent runtime (plan P0.4, ADR-024): named terminals that outlive the
# shell that started them, for `dot ai start --bg`, `dot ai send`,
# `dot ai wait` and `dot session`. herdr-core (hc) when it is installed,
# else tmux, one detached session per terminal; the verbs are the same.
#
#   start   hc run --bg --name N [--cwd D] CMD    tmux new-session -d -s N
#   send    hc send N TEXT                        tmux send-keys -l TEXT, Enter
#   wait    hc wait N | --children all            the agent's hook state, by pane
#   open    hc attach N                           tmux attach / switch-client
#   stop    hc kill N                             tmux kill-session
#   list    hc ls                                 tmux list-sessions
#
# herdr-core's installer links hc only when no other hc exists, so this
# runs herdr-core. Without hc, wait follows the state the agent's hook
# writes with its tmux pane (agent-event.v1 "pane"): a session is done
# when every pane's agent has reported something other than running since
# it started, or since the last `dot ai send` to it (kept in
# $XDG_STATE_HOME/dot/ai/runtime/<name>, so a reused pane id's old records
# never count). One that has not reported counts as working.
#
# DOT_RUNTIME (hc|tmux) picks the backend; DOT_HC and DOT_TMUX the binaries;
# DOT_RT_POLL the tmux wait's poll interval in seconds. Bash 3.2 compatible.

[[ -n "${_DOT_RUNTIME_LOADED:-}" ]] && return 0
_DOT_RUNTIME_LOADED=1

_dot_rt_hc() { "${DOT_HC:-herdr-core}" "$@"; }
_dot_rt_tmux() { "${DOT_TMUX:-tmux}" "$@"; }
_dot_rt_state() { printf '%s' "${XDG_STATE_HOME:-$HOME/.local/state}/dot"; }

# _dot_rt_now: UTC to the second, as the hook writes times.
_dot_rt_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

# _dot_rt_mark NAME OP: record that reports about NAME count from now: ge
# at its start (the agent may report in the same second), gt after a send
# (the turn the send started).
_dot_rt_mark() {
  local dir
  dir="$(_dot_rt_state)/ai/runtime"
  mkdir -p "$dir" && printf '%s %s\n' "$2" "$(_dot_rt_now)" >"$dir/$1"
}

# dot_rt_backend: hc or tmux; status 1 with neither.
dot_rt_backend() {
  case "${DOT_RUNTIME:-}" in
    hc | tmux)
      printf '%s' "$DOT_RUNTIME"
      return 0
      ;;
  esac
  if command -v "${DOT_HC:-herdr-core}" >/dev/null 2>&1; then
    printf 'hc'
  elif command -v "${DOT_TMUX:-tmux}" >/dev/null 2>&1; then
    printf 'tmux'
  else
    return 1
  fi
}

# dot_rt_name_ok NAME: hc's rule, 1-32 of a-z 0-9 - _, which tmux takes too.
dot_rt_name_ok() { [[ "$1" =~ ^[a-z0-9_-]{1,32}$ ]]; }

# dot_rt_names BACKEND: the live terminals' names, one per line.
dot_rt_names() {
  if [[ "$1" == hc ]]; then
    { _dot_rt_hc ls --json 2>/dev/null || true; } | jq -r '.terminals[].name // empty' 2>/dev/null || true
  else
    _dot_rt_tmux list-sessions -F '#{session_name}' 2>/dev/null || true
  fi
}

# dot_rt_free_name BACKEND BASE: BASE-1, BASE-2, ... the first not in use.
dot_rt_free_name() {
  local names n=1
  names=$'\n'"$(dot_rt_names "$1")"$'\n'
  while [[ "$names" == *$'\n'"$2-$n"$'\n'* ]]; do
    n=$((n + 1))
  done
  printf '%s-%d' "$2" "$n"
}

# dot_rt_start BACKEND KIND NAME CWD [CMD...]: start CMD (the shell when
# none) in a new terminal NAME and return at once; CWD may be empty. KIND
# agent marks it for a wait with no name (hc label dot=agent, tmux option
# @dot_agent); session does not.
dot_rt_start() {
  local backend="$1" kind="$2" name="$3" cwd="$4"
  shift 4
  if [[ "$backend" == hc ]]; then
    _dot_rt_hc run --bg --name "$name" ${cwd:+--cwd "$cwd"} --label "dot=$kind" -- "$@" >/dev/null
  else
    _dot_rt_mark "$name" ge
    _dot_rt_tmux new-session -d -s "$name" ${cwd:+-c "$cwd"} "$@" || return
    [[ "$kind" != agent ]] || _dot_rt_tmux set-option -q -t "=$name:" @dot_agent 1
  fi
}

# dot_rt_send BACKEND NAME TEXT: paste TEXT and press Enter; the time is
# kept, so a tmux wait after it waits for the turn it started.
dot_rt_send() {
  local pane
  if [[ "$1" == hc ]]; then
    _dot_rt_hc send "$2" "$3" >/dev/null
  else
    # The active pane, by id, out of any mode first: tmux shows a config's
    # errors in view mode, where typed keys never reach the program.
    # Not one pipeline: the caller's pipefail must not decide a gone session.
    pane="$(_dot_rt_tmux list-panes -t "=$2:" -F '#{pane_active} #{pane_id}' 2>/dev/null)" || return 1
    pane="$(awk '$1 == 1 { print $2; exit }' <<<"$pane")"
    _dot_rt_tmux copy-mode -q -t "$pane" 2>/dev/null || true
    _dot_rt_mark "$2" gt
    _dot_rt_tmux send-keys -t "$pane" -l -- "$3" && _dot_rt_tmux send-keys -t "$pane" Enter
  fi
}

# dot_rt_open BACKEND NAME: put this terminal on NAME.
dot_rt_open() {
  if [[ "$1" == hc ]]; then
    _dot_rt_hc attach "$2"
  elif [[ -n "${TMUX:-}" ]]; then
    _dot_rt_tmux switch-client -t "=$2:"
  else
    _dot_rt_tmux attach-session -t "=$2:"
  fi
}

# dot_rt_stop BACKEND NAME: end NAME's program.
dot_rt_stop() {
  rm -f "$(_dot_rt_state)/ai/runtime/$2"
  if [[ "$1" == hc ]]; then
    _dot_rt_hc kill "$2" >/dev/null
  else
    _dot_rt_tmux kill-session -t "=$2:"
  fi
}

# dot_rt_list BACKEND: the live terminals, as the backend lists them.
dot_rt_list() {
  if [[ "$1" == hc ]]; then
    _dot_rt_hc ls
  else
    _dot_rt_tmux list-sessions -F '#{session_name}	#{session_windows} windows	#{?session_attached,attached,detached}' 2>/dev/null ||
      echo "No sessions."
  fi
}

# _dot_rt_counts OP SINCE TIME: whether a report at TIME counts: OP ge
# (at or after SINCE) or gt (after it); any with no SINCE.
_dot_rt_counts() {
  [[ -n "$2" ]] || return 0
  [[ "$3" > "$2" || ("$1" == ge && "$3" == "$2") ]]
}

# _dot_rt_pane_state PANE OP SINCE: sets RT_STATE to the newest state
# recorded for PANE that counts (_dot_rt_counts), "" when none.
_dot_rt_pane_state() {
  local f rec time best=""
  RT_STATE=""
  for f in "$(_dot_rt_state)"/cli/agents/*/*.json; do
    [[ -f "$f" ]] || continue
    rec="$(<"$f")"
    [[ "$rec" == *"\"pane\":\"$1\""* && "$rec" =~ \"time\":\"([^\"]+)\" ]] || continue
    time="${BASH_REMATCH[1]}"
    _dot_rt_counts "$2" "$3" "$time" && [[ ! "$time" < "$best" ]] || continue
    [[ "$rec" =~ \"state\":\"([a-z]+)\" ]] || continue
    best="$time" RT_STATE="${BASH_REMATCH[1]}"
  done
}

# _dot_rt_session_state NAME: sets RT_STATE to NAME's state for a wait:
# running while any pane's agent works or has not reported since its start
# or the last send, exit when the session is gone, else the last pane's.
_dot_rt_session_state() {
  local pane op="" since="" mark state=""
  if ! _dot_rt_tmux has-session -t "=$1:" 2>/dev/null; then
    RT_STATE="exit"
    return
  fi
  mark="$(_dot_rt_state)/ai/runtime/$1"
  [[ ! -s "$mark" ]] || read -r op since <"$mark"
  for pane in $(_dot_rt_tmux list-panes -s -t "=$1:" -F '#{pane_id}' 2>/dev/null); do
    _dot_rt_pane_state "$pane" "$op" "$since"
    [[ -n "$RT_STATE" && "$RT_STATE" != running ]] || {
      RT_STATE=running
      return
    }
    state="$RT_STATE"
  done
  RT_STATE="${state:-running}"
}

# _dot_rt_tmux_wait TIMEOUT NAME...: poll until no session is running;
# prints "NAME: STATE" for each, 124 when one still is after TIMEOUT.
_dot_rt_tmux_wait() {
  local timeout="$1" name busy out
  local deadline=$((SECONDS + timeout))
  shift
  while :; do
    busy=0 out=""
    for name in "$@"; do
      _dot_rt_session_state "$name"
      [[ "$RT_STATE" != running ]] || busy=1
      out+="$name: $RT_STATE"$'\n'
    done
    if ((busy == 0)); then
      printf '%s' "$out"
      return 0
    fi
    if ((SECONDS >= deadline)); then
      printf '%s' "$out"
      printf 'still working after %ss; it keeps running\n' "$timeout" >&2
      return 124
    fi
    sleep "${DOT_RT_POLL:-1}"
  done
}

# dot_rt_ready BACKEND NAME TIMEOUT: wait up to TIMEOUT seconds for the
# agent in NAME to report its first state, so text sent next is not typed
# into a program still starting; 1 when it never did (send anyway: an
# agent without hooks never reports).
dot_rt_ready() {
  local deadline=$((SECONDS + $3))
  if [[ "$1" == hc ]]; then
    _dot_rt_hc wait "$2" --timeout "$3" --json 2>/dev/null | jq -e '.ended' >/dev/null 2>&1
    return
  fi
  while :; do
    _dot_rt_session_state "$2"
    [[ "$RT_STATE" == running ]] || return 0
    ((SECONDS < deadline)) || return 1
    sleep "${DOT_RT_POLL:-1}"
  done
}

# _dot_rt_tmux_agents: the sessions dot started an agent in.
_dot_rt_tmux_agents() {
  { _dot_rt_tmux list-sessions -F '#{session_name} #{@dot_agent}' 2>/dev/null || true; } |
    awk '$2 == 1 { print $1 }'
}

# dot_rt_wait BACKEND TIMEOUT [NAME]: block until NAME (else every agent dot
# started: hc's children of this terminal) stops working, at most TIMEOUT
# seconds; prints "NAME: STATE". 124 when still working, 1 on an error.
dot_rt_wait() {
  local backend="$1" timeout="$2" name="${3:-}" json
  local -a names who=(--children all)
  if [[ "$backend" == hc ]]; then
    [[ -z "$name" ]] || who=("$name")
    json="$(_dot_rt_hc wait "${who[@]}" --timeout "$timeout" --json)" || return 1
    # One line per child, or for the one terminal waited on, by its name.
    jq -r --arg n "$name" 'if (.children | length) > 0 then .children[] | "\(.terminal): \(.status // .reason)"
      else "\(if $n == "" then .terminal else $n end): \(.status // .reason)" end' <<<"$json"
    [[ "$(jq -r '.ended' <<<"$json")" == true ]] || {
      printf 'still working after %ss; it keeps running\n' "$timeout" >&2
      return 124
    }
    return 0
  fi
  if [[ -n "$name" ]]; then
    _dot_rt_tmux has-session -t "=$name:" 2>/dev/null || {
      printf "dot: no session '%s'\n" "$name" >&2
      return 1
    }
    names=("$name")
  else
    # shellcheck disable=SC2207 # session names have no spaces (dot_rt_name_ok)
    names=($(_dot_rt_tmux_agents))
    ((${#names[@]} > 0)) || {
      echo "No agents started with 'dot ai start --bg'." >&2
      return 1
    }
  fi
  _dot_rt_tmux_wait "$timeout" "${names[@]}"
}
