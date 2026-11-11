#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by plugins/ai/libexec/ai.sh; inherits set -euo pipefail.
# Agents that outlive the shell (plan P0.4, ADR-024), on the runtime in
# lib/dot/agent-runtime.sh (herdr-core, else tmux):
#
#   dot ai start --bg [--name N] [--cwd D] <agent> [task...]
#   dot ai send <name> <text...>
#   dot ai wait [<name>] [--timeout S]
#
# start --bg names the terminal <agent>-<n> unless told; with a task it
# waits up to 30 s for the agent's first state, then sends the task. wait
# exits 0 once the agent stops working (idle, blocked, error, exit), 124
# when it still works after the timeout (180 s), leaving it running.
# dot ai delegate, the /vibe delegator, is retired onto these.

[[ -n "${_DOT_LIB_AI_RUNTIME_LOADED:-}" ]] && return 0
_DOT_LIB_AI_RUNTIME_LOADED=1

_AI_RT_SDK="${BASH_SOURCE[0]%/*}/../../../../lib/dot"
# shellcheck source-path=SCRIPTDIR source=../../../../lib/dot/agent-runtime.sh
source "${DOT_SDK:-$_AI_RT_SDK}/agent-runtime.sh"

# _ai_rt_backend: the runtime, or an error saying how to get one.
_ai_rt_backend() {
  dot_rt_backend && return 0
  ui_err "dot ai" "needs herdr-core (dot ai install hc) or tmux" >&2
  return 1
}

# _ai_rt_usage LINE: the usage error, status 1.
_ai_rt_usage() {
  ui_err "Usage" "$1" >&2
  return 1
}

# _ai_rt_start_opts ARG...: sets AI_RT_OPT_NAME, AI_RT_OPT_CWD and
# AI_RT_SHIFT (how many words were options); 1 on a bad option.
_ai_rt_start_opts() {
  AI_RT_OPT_NAME="" AI_RT_OPT_CWD="" AI_RT_SHIFT=0
  while :; do
    case "${1:-}" in
      --bg) set -- "${@:2}" && AI_RT_SHIFT=$((AI_RT_SHIFT + 1)) ;;
      --name | --cwd)
        [[ $# -ge 2 ]] || return 1
        if [[ "$1" == --name ]]; then AI_RT_OPT_NAME="$2"; else AI_RT_OPT_CWD="$2"; fi
        set -- "${@:3}"
        AI_RT_SHIFT=$((AI_RT_SHIFT + 2))
        ;;
      -*) return 1 ;;
      *) return 0 ;; # the agent, or nothing left
    esac
  done
}

# _ai_rt_agent_path AGENT: the agent's binary as an absolute path (the
# runtime's server may not share this PATH), or why there is none.
_ai_rt_agent_path() {
  local bin
  bin="$(ai_roster_bin "$1")" || {
    ui_err "$1" "not an agent dot ai knows ('dot ai list')" >&2
    return 1
  }
  command -v "$bin" || {
    ui_err "$1" "not installed: dot ai install $1" >&2
    return 1
  }
}

# cmd_ai_start_bg [--bg] [--name N] [--cwd D] AGENT [TASK...]: start AGENT in
# a terminal of its own and return; sets AI_RT_NAME to its name.
cmd_ai_start_bg() {
  local usage="dot ai start --bg [--name N] [--cwd DIR] <agent> [task...]"
  local agent path backend name
  _ai_rt_start_opts "$@" || _ai_rt_usage "$usage" || return
  shift "$AI_RT_SHIFT"
  agent="${1:-}"
  [[ -n "$agent" ]] || _ai_rt_usage "$usage" || return
  shift
  path="$(_ai_rt_agent_path "$agent")" || return 1
  backend="$(_ai_rt_backend)" || return 1
  name="${AI_RT_OPT_NAME:-$(dot_rt_free_name "$backend" "$agent")}"
  dot_rt_name_ok "$name" || _ai_rt_usage "a name is 1-32 of a-z 0-9 - _" || return
  _ai_rt_launch "$backend" "$name" "$agent" "$path" "$@"
}

# _ai_rt_launch BACKEND NAME AGENT PATH [TASK...]: start it, then (once the
# agent has reported, or after DOT_RT_READY seconds) type the task in.
_ai_rt_launch() {
  local backend="$1" name="$2" agent="$3"
  dot_rt_start "$backend" agent "$name" "$AI_RT_OPT_CWD" "$4" || {
    ui_err "$name" "could not start (is the name taken? dot session list)" >&2
    return 1
  }
  AI_RT_NAME="$name"
  shift 4
  if [[ $# -gt 0 ]]; then
    dot_rt_ready "$backend" "$name" "${DOT_RT_READY:-30}" || true
    dot_rt_send "$backend" "$name" "$*" || return 1
  fi
  printf 'Started %s (%s, on %s). Next: dot ai send %s "..." · dot ai wait %s · dot session open %s\n' \
    "$name" "$agent" "$backend" "$name" "$name" "$name"
}

# cmd_ai_send NAME TEXT...: give the agent in NAME the words as one line.
cmd_ai_send() {
  local backend
  [[ $# -ge 2 ]] || _ai_rt_usage "dot ai send <name> <text...>" || return
  backend="$(_ai_rt_backend)" || return 1
  dot_rt_send "$backend" "$1" "${*:2}"
}

# cmd_ai_wait [NAME] [--timeout S]: block until NAME (else every agent
# started with --bg) stops working.
cmd_ai_wait() {
  local usage="dot ai wait [<name>] [--timeout SECONDS]"
  local name="" timeout=180 backend
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --timeout)
        [[ "${2:-}" =~ ^[0-9]+$ ]] || _ai_rt_usage "$usage" || return
        timeout="$2"
        shift 2
        ;;
      -*) _ai_rt_usage "$usage" || return ;;
      *)
        [[ -z "$name" ]] || _ai_rt_usage "$usage" || return
        name="$1"
        shift
        ;;
    esac
  done
  backend="$(_ai_rt_backend)" || return 1
  dot_rt_wait "$backend" "$timeout" "$name"
}

# cmd_ai_delegate "<prompt>" [max-turns] [agent] [timeout] — retired: the
# /vibe delegator's place is taken by start --bg and wait, which this now
# runs (max-turns has no equivalent and is ignored).
cmd_ai_delegate() {
  [[ $# -ge 1 ]] || _ai_rt_usage 'dot ai start --bg <agent> "<task>"; dot ai wait <name>' || return
  ui_warn "dot ai delegate" "retired: dot ai start --bg <agent> \"<task>\", then dot ai wait <name>" >&2
  cmd_ai_start_bg "${3:-claude}" "$1" || return
  cmd_ai_wait "$AI_RT_NAME" --timeout "${4:-180}"
}
