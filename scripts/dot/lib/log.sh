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
