#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Shared logging functions for provision scripts
# Source this file at the top of any install/provision script.

set -euo pipefail

# Guard against double-sourcing
if [[ -n "${_DOTFILES_LOGGING_LOADED:-}" ]]; then
  return 0
fi
_DOTFILES_LOGGING_LOADED=1

log_json() {
  local level="$1"
  local message="$2"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  printf '{"time":"%s", "level":"%s", "message":"%s"}\n' "$timestamp" "$level" "$message"
}

log_info() {
  if [[ "${DOTFILES_JSON_LOG:-0}" == "1" ]]; then
    log_json "INFO" "$*"
  else
    printf '\n[INFO] %s\n' "$*"
  fi
}

log_warn() {
  if [[ "${DOTFILES_JSON_LOG:-0}" == "1" ]]; then
    log_json "WARN" "$*" >&2
  else
    printf '\n[WARN] %s\n' "$*" >&2
  fi
}

log_error() {
  if [[ "${DOTFILES_JSON_LOG:-0}" == "1" ]]; then
    log_json "ERROR" "$*" >&2
  else
    printf '\n[ERROR] %s\n' "$*" >&2
  fi
}

die() {
  log_error "$@"
  exit 1
}
