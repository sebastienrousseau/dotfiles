#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by the dot CLI's commands and plugins (SDK); inherits set -euo pipefail.
#
# One log, one schema (log.v1, schemas/cli/log.v1.schema.json): every event
# is a JSON line in $XDG_STATE_HOME/dot/<domain>/log.jsonl, the domain being
# the command's (DOT_LOG_DOMAIN, which bin/dot exports, or a plugin's
# DOT_DOMAIN), else cli. Metrics, the agent session log and fleet events are
# log.v1 events too, in their domain's log.
#
#   dot_log info apply_start source=chezmoi    # level, event, data fields
#   dot_metric shell_startup 142 ms            # a "metric" event
#
# Levels are debug, info, warn and error. Events below DOT_LOG_LEVEL (info,
# or debug when -v set DOT_VERBOSE) are not written. Records older than
# DOT_LOG_RETENTION_DAYS (30) are pruned by dot_log_prune, which the
# maintenance job runs. Metadata only: callers log names, counts and ids,
# never prompts or file contents.

# Re-source guard: re-sourcing would mint a new DOT_TRACE_ID and break
# correlation across modules that already captured the original.
[[ "${_DOT_LIB_LOG_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_LOG_LOADED=1

# Correlation ID for tracing across commands in a single invocation
DOT_TRACE_ID="${DOT_TRACE_ID:-$(date +%s%N 2>/dev/null | tail -c 12 || date +%s)}"
export DOT_TRACE_ID

# Saved state that is not a log (agent checkpoints) stays here until the
# state migration moves it.
_DOT_LOG_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"

dot_agent_checkpoint_dir() {
  printf '%s\n' "$_DOT_LOG_STATE_DIR/checkpoints"
}

# dot_jsonl_append FILE PAYLOAD: append PAYLOAD to FILE in the old state
# directory. Deprecated (SDK v1 keeps it for plugins): log with dot_log.
dot_jsonl_append() {
  mkdir -p "$_DOT_LOG_STATE_DIR" 2>/dev/null || return 0
  { printf '%s\n' "$2"; } 2>/dev/null >>"$_DOT_LOG_STATE_DIR/$1" || true
}

# dot_log_path DOMAIN: where DOMAIN's log.v1 events go; 64 for a DOMAIN
# that is not a plain name, which could otherwise climb out with `..`.
dot_log_path() {
  [[ "$1" =~ ^[a-z][a-z0-9-]*$ ]] || return 64
  printf '%s/dot/%s/log.jsonl\n' "${XDG_STATE_HOME:-$HOME/.local/state}" "$1"
}

# _dot_log_domain: the domain this process logs to.
_dot_log_domain() {
  local d="${DOT_LOG_DOMAIN:-${DOT_DOMAIN:-cli}}"
  [[ "$d" =~ ^[a-z][a-z0-9-]*$ ]] || d=cli
  printf '%s' "$d"
}

# _dot_log_rank LEVEL: debug 0, info 1, warn 2, error 3; 1 for anything else.
_dot_log_rank() {
  case "$1" in debug) echo 0 ;; warn) echo 2 ;; error) echo 3 ;; *) echo 1 ;; esac
}

# _dot_log_wanted LEVEL: true when LEVEL is at or above the threshold.
_dot_log_wanted() {
  local min="${DOT_LOG_LEVEL:-info}"
  [[ -n "${DOT_LOG_LEVEL:-}" || "${DOT_VERBOSE:-0}" != 1 ]] || min=debug
  (($(_dot_log_rank "$1") >= $(_dot_log_rank "$min")))
}

# _dot_json_str TEXT: TEXT as a JSON string, quotes included. Control
# characters other than tab, newline and return are dropped.
_dot_json_str() {
  local s="$1"
  s="${s//\\/\\\\}" s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}" s="${s//$'\r'/\\r}" s="${s//$'\t'/\\t}"
  [[ "$s" != *[[:cntrl:]]* ]] || s="$(printf '%s' "$s" | LC_ALL=C tr -d '\000-\037\177')"
  printf '"%s"' "$s"
}

# dot_log_record LEVEL EVENT [KEY=VALUE...]: one log.v1 line on stdout.
dot_log_record() {
  local level="$1" event="$2" data="" kv
  shift 2
  for kv in "$@"; do
    [[ "$kv" == *=* ]] || kv="$kv="
    data+="${data:+,}$(_dot_json_str "${kv%%=*}"):$(_dot_json_str "${kv#*=}")"
  done
  printf '{"schema":"cli/log.v1","time":"%s","level":%s,"domain":%s,"event":%s,"command":%s,"trace_id":%s,"pid":%d,"data":{%s}}\n' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(_dot_json_str "$level")" "$(_dot_json_str "$(_dot_log_domain)")" \
    "$(_dot_json_str "$event")" "$(_dot_json_str "${DOT_COMMAND:-unknown}")" "$(_dot_json_str "$DOT_TRACE_ID")" \
    "$$" "$data"
}

# dot_log LEVEL EVENT [KEY=VALUE...]: append a log.v1 event to the domain's
# log; with DOTFILES_JSON_LOG=1, print it on stdout too. Never fails the
# caller: a log that cannot be written is skipped.
dot_log() {
  _dot_log_wanted "$1" || return 0
  local record file
  record="$(dot_log_record "$@")"
  file="$(dot_log_path "$(_dot_log_domain)")"
  if mkdir -p "${file%/*}" 2>/dev/null; then
    { printf '%s\n' "$record"; } 2>/dev/null >>"$file" || true
  fi
  [[ "${DOTFILES_JSON_LOG:-0}" != 1 ]] || printf '%s\n' "$record"
}

# dot_log_tail DOMAIN [COUNT] [EVENT_PREFIX]: the last COUNT (20) events of
# DOMAIN's log, those whose event starts with EVENT_PREFIX when given.
dot_log_tail() {
  local file
  file="$(dot_log_path "$1")" || return 64
  [[ -f "$file" ]] || return 0
  grep -F "\"event\":\"${3:-}" "$file" 2>/dev/null | tail -n "${2:-20}" || true
}

# dot_log_prune [DAYS]: drop records older than DAYS (DOT_LOG_RETENTION_DAYS,
# else 30) from every domain's log. ISO timestamps sort as text.
dot_log_prune() {
  local days="${1:-${DOT_LOG_RETENTION_DAYS:-30}}" cutoff file
  [[ "$days" =~ ^[0-9]+$ ]] || return 64
  if ! cutoff="$(date -u -d "-$days days" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null ||
    date -u -v"-${days}d" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"; then
    echo "dot_log_prune: this date understands neither -d nor -v; the logs were not pruned" >&2
    return 1
  fi
  for file in "${XDG_STATE_HOME:-$HOME/.local/state}"/dot/*/log.jsonl; do
    [[ -f "$file" ]] || continue
    if awk -v c="\"time\":\"$cutoff\"" '{ i = index($0, "\"time\":\""); if (!i || substr($0, i, length(c)) >= c) print }' \
      "$file" >"$file.$$"; then
      mv -f "$file.$$" "$file"
    else
      rm -f "$file.$$"
    fi
  done
}

# dot_metric NAME VALUE [UNIT]: a "metric" event (unit ms by default).
dot_metric() {
  dot_log info metric "name=$1" "value=$2" "unit=${3:-ms}"
}

# dot_metrics_summary [COUNT]: the last COUNT (20) metric events of every
# domain, oldest first (`dot doctor metric list`).
dot_metrics_summary() {
  local count="${1:-20}" files=() f
  for f in "${XDG_STATE_HOME:-$HOME/.local/state}"/dot/*/log.jsonl; do
    [[ -f "$f" ]] && files+=("$f")
  done
  if ((${#files[@]} == 0)) || ! grep -qF '"event":"metric"' "${files[@]}"; then
    echo "No metrics collected yet."
    echo "Metrics are logged to: ${XDG_STATE_HOME:-$HOME/.local/state}/dot/<domain>/log.jsonl"
    return 0
  fi
  # Stable sort on the time field (the 8th "-separated one), so records of
  # the same second keep the order they were written in.
  grep -hF '"event":"metric"' "${files[@]}" | sort -s -t'"' -k8,8 | tail -n "$count"
}

# dot_agent_session_log EVENT PROFILE [STATUS] [KEY=VALUE...]: an agent
# session event in the agent domain's log.
dot_agent_session_log() {
  local event="$1" profile="$2" status="${3:-ok}"
  shift 3 || shift $#
  DOT_LOG_DOMAIN=agent dot_log info "session_$event" "profile=$profile" "status=$status" "$@"
}

# dot_agent_session_tail [COUNT]: the last COUNT (20) agent session events.
dot_agent_session_tail() {
  local out
  out="$(dot_log_tail agent "${1:-20}" session_)"
  if [[ -z "$out" ]]; then
    echo "No agent sessions recorded yet."
    echo "Agent sessions are logged to: $(dot_log_path agent)"
    return 0
  fi
  printf '%s\n' "$out"
}

dot_agent_checkpoint_create() {
  local profile="$1" status="${2:-ready}"
  shift 2 || true

  local checkpoint_dir checkpoint_id checkpoint_file created_at
  local argv_json='[]'
  checkpoint_dir="$(dot_agent_checkpoint_dir)"
  checkpoint_id="${DOT_AGENT_CHECKPOINT_ID:-$(date -u +%Y%m%dT%H%M%SZ)-${DOT_TRACE_ID}}"
  checkpoint_file="$checkpoint_dir/${checkpoint_id}.json"
  created_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  mkdir -p "$checkpoint_dir" 2>/dev/null || return 0

  if [[ "$#" -gt 0 ]] && command -v jq >/dev/null 2>&1; then
    argv_json="$(printf '%s\n' "$@" | jq -R . | jq -s .)"
  fi

  if command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg id "$checkpoint_id" \
      --arg time "$created_at" \
      --arg profile "$profile" \
      --arg status "$status" \
      --arg trace_id "$DOT_TRACE_ID" \
      --arg command "${DOT_COMMAND:-unknown}" \
      --arg cwd "$(pwd)" \
      --arg approval "${DOT_AGENT_APPROVAL:-}" \
      --arg filesystem "${DOT_AGENT_FILESYSTEM:-}" \
      --arg network "${DOT_AGENT_NETWORK:-}" \
      --arg mcp_profile "${DOT_AGENT_MCP_PROFILE:-}" \
      --arg max_steps "${DOT_AGENT_MAX_STEPS:-}" \
      --argjson argv "$argv_json" \
      '{
        id: $id,
        created_at: $time,
        profile: $profile,
        status: $status,
        trace_id: $trace_id,
        command: $command,
        cwd: $cwd,
        argv: $argv,
        env: {
          approval: $approval,
          filesystem: $filesystem,
          network: $network,
          mcp_profile: $mcp_profile,
          max_steps: $max_steps
        }
      }' >"$checkpoint_file"
  else
    printf '{"id":"%s","created_at":"%s","profile":"%s","status":"%s","trace_id":"%s","command":"%s"}\n' \
      "$checkpoint_id" "$created_at" "$profile" "$status" "$DOT_TRACE_ID" "${DOT_COMMAND:-unknown}" >"$checkpoint_file"
  fi

  printf '%s\n' "$checkpoint_file"
}

# Convenience wrappers for human-readable log output.
# Source this file and call log_info/log_warn/log_error/log_success instead of
# ui_info/ui_warn/ui_err/ui_ok when the caller prefers semantic log names.
log_info() { ui_info "$*"; }
log_warn() { ui_warn "$*"; }
log_error() { ui_err "$*"; }
log_success() { ui_ok "$*"; }

dot_agent_checkpoint_tail() {
  local count="${1:-20}"
  local checkpoint_dir file
  checkpoint_dir="$(dot_agent_checkpoint_dir)"
  [[ -d "$checkpoint_dir" ]] || return 0
  find "$checkpoint_dir" -maxdepth 1 -type f -name '*.json' | sort | tail -n "$count" | while IFS= read -r file; do
    [[ -n "$file" ]] || continue
    cat "$file"
  done
}
