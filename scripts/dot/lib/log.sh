#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Structured JSON logging and metrics library.
# Source this file to emit machine-readable logs and performance metrics.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/log.sh"
#   dot_log info "apply_start" "source=chezmoi"
#   dot_metric "shell_startup" 142 ms

# Structured log entry (JSON when DOTFILES_JSON_LOG=1, silent otherwise)
dot_log() {
  local level="$1" event="$2"
  shift 2
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  if [[ "${DOTFILES_JSON_LOG:-0}" = "1" ]]; then
    printf '{"time":"%s","level":"%s","event":"%s","command":"%s"' \
      "$ts" "$level" "$event" "${DOT_COMMAND:-unknown}"
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
  local metrics_file="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/metrics.jsonl"
  mkdir -p "$(dirname "$metrics_file")"
  printf '{"time":"%s","metric":"%s","value":%s,"unit":"%s"}\n' \
    "$ts" "$name" "$value" "$unit" >>"$metrics_file"
}
