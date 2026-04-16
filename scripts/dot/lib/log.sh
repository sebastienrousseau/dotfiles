#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Structured JSON logging and metrics library.
# Source this file to emit machine-readable logs and performance metrics.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/log.sh"
#   dot_log info "apply_start" "source=chezmoi"
#   dot_metric "shell_startup" 142 ms

# Correlation ID for tracing across commands in a single invocation
DOT_TRACE_ID="${DOT_TRACE_ID:-$(date +%s%N 2>/dev/null | tail -c 12 || date +%s)}"
export DOT_TRACE_ID

_DOT_LOG_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"

dot_agent_checkpoint_dir() {
  printf '%s\n' "$_DOT_LOG_STATE_DIR/checkpoints"
}

dot_jsonl_append() {
  local file="$1" payload="$2"
  mkdir -p "$_DOT_LOG_STATE_DIR" 2>/dev/null || return 0
  printf '%s\n' "$payload" >>"$_DOT_LOG_STATE_DIR/$file" 2>/dev/null || true
}

# Always-on file logging (appends to dot.log, rotates at 1MB)
dot_log_file() {
  local level="$1" event="$2"
  shift 2
  local log_file="$_DOT_LOG_STATE_DIR/dot.log"
  mkdir -p "$_DOT_LOG_STATE_DIR" 2>/dev/null || return 0
  # Rotate at 1MB
  if [[ -f "$log_file" ]]; then
    local size
    size=$(stat -c '%s' "$log_file" 2>/dev/null || stat -f '%z' "$log_file" 2>/dev/null || echo 0)
    if [[ "$size" -gt 1048576 ]]; then
      mv "$log_file" "${log_file}.1" 2>/dev/null || true
    fi
  fi
  printf '[%s] [%s] [%s] %s' \
    "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$level" "$DOT_TRACE_ID" "$event" >>"$log_file" 2>/dev/null || return 0
  while [[ $# -gt 0 ]]; do
    printf ' %s' "$1" >>"$log_file" 2>/dev/null || return 0
    shift
  done
  printf '\n' >>"$log_file" 2>/dev/null || true
}

# Structured log entry (JSON when DOTFILES_JSON_LOG=1, silent otherwise)
# Always writes to file log
dot_log() {
  local level="$1" event="$2"
  shift 2
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  # Always-on file logging
  dot_log_file "$level" "$event" "$@"
  # JSON stdout logging when enabled
  if [[ "${DOTFILES_JSON_LOG:-0}" = "1" ]]; then
    printf '{"time":"%s","level":"%s","event":"%s","command":"%s","trace_id":"%s"' \
      "$ts" "$level" "$event" "${DOT_COMMAND:-unknown}" "$DOT_TRACE_ID"
    while [[ $# -gt 0 ]]; do
      printf ',"%s":"%s"' "${1%%=*}" "${1#*=}"
      shift
    done
    printf '}\n'
  fi
}

# Metrics emission (append to JSONL metrics file)
dot_metric() {
  local name="$1" value="$2" unit="${3:-ms}"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local metrics_file="$_DOT_LOG_STATE_DIR/metrics.jsonl"
  mkdir -p "$_DOT_LOG_STATE_DIR" 2>/dev/null || return 0
  printf '{"time":"%s","metric":"%s","value":%s,"unit":"%s","trace_id":"%s"}\n' \
    "$ts" "$name" "$value" "$unit" "$DOT_TRACE_ID" >>"$metrics_file" 2>/dev/null || true
}

# Print recent metrics (for `dot metrics` command)
dot_metrics_summary() {
  local metrics_file="$_DOT_LOG_STATE_DIR/metrics.jsonl"
  local count="${1:-20}"
  if [[ ! -f "$metrics_file" ]]; then
    echo "No metrics collected yet."
    echo "Metrics are recorded at: $metrics_file"
    return 0
  fi
  tail -n "$count" "$metrics_file"
}

dot_agent_session_log() {
  local event="$1" profile="$2" status="${3:-ok}"
  shift 3 || true
  local ts payload
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  payload=$(printf '{"time":"%s","event":"%s","profile":"%s","status":"%s","trace_id":"%s","command":"%s"' \
    "$ts" "$event" "$profile" "$status" "$DOT_TRACE_ID" "${DOT_COMMAND:-unknown}")
  while [[ $# -gt 0 ]]; do
    payload+=$(printf ',"%s":"%s"' "${1%%=*}" "${1#*=}")
    shift
  done
  payload+='}'
  dot_jsonl_append "agent-sessions.jsonl" "$payload"
}

dot_agent_session_tail() {
  local count="${1:-20}"
  local sessions_file="$_DOT_LOG_STATE_DIR/agent-sessions.jsonl"
  if [[ ! -f "$sessions_file" ]]; then
    echo "No agent sessions recorded yet."
    echo "Agent sessions are recorded at: $sessions_file"
    return 0
  fi
  tail -n "$count" "$sessions_file"
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
