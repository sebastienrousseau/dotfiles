#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by system.sh; inherits set -euo pipefail.
# `dot system clean [--caches] [--yes]` (P9): prune the private build caches
# below DOT_BUILD_ROOT (lib/dot/sdk.sh dot_build_root), which mise points
# Go, pip and uv at and nothing pruned: 23 GB on one machine. Each tool
# prunes its own cache, scoped to its directory there by its environment
# variable, so a cache elsewhere is never touched:
#   uv cache prune            UV_CACHE_DIR=<root>/uv-cache
#   pip cache purge           PIP_CACHE_DIR=<root>/pip-cache
#   go clean -cache           GOCACHE=<root>/go-cache
# It shows the sizes first and asks; with no terminal to ask it only reports,
# unless --yes.

# _clean_tool NAME: the command line that prunes NAME's cache, or false when
# the tool is not installed.
_clean_tool() {
  case "$1" in
    uv) has_command uv && echo "uv cache prune" ;;
    pip)
      if has_command pip3; then
        echo "pip3 cache purge"
      elif has_command python3; then echo "python3 -m pip cache purge"; else return 1; fi
      ;;
    go) has_command go && echo "go clean -cache" ;;
    *) return 1 ;;
  esac
}

# _clean_env NAME DIR: the environment assignment that scopes NAME to DIR.
_clean_env() {
  case "$1" in
    uv) echo "UV_CACHE_DIR=$2" ;;
    pip) echo "PIP_CACHE_DIR=$2" ;;
    go) echo "GOCACHE=$2" ;;
  esac
}

# _clean_report ROOT [quiet]: each cache's size (unless quiet); sets
# _CLEAN_KB to their total in KiB.
_clean_report() {
  local name kb
  _CLEAN_KB=0
  for name in uv pip go; do
    kb="$(dot_build_cache_kb "$1/$name-cache")"
    _CLEAN_KB=$((_CLEAN_KB + kb))
    [[ -n "${2:-}" ]] || ui_info "$name-cache" "$((kb / 1024)) MiB"
  done
}

# _clean_one NAME DIR: prune one cache with its own tool; false on failure.
_clean_one() {
  local cmd env
  [[ -d "$2" ]] || return 0
  if ! cmd="$(_clean_tool "$1")"; then
    ui_info "$1-cache" "skipped: $1 is not installed"
    return 0
  fi
  env="$(_clean_env "$1" "$2")"
  # shellcheck disable=SC2086 # the command is words
  if env "$env" $cmd >/dev/null 2>&1; then
    ui_ok "$1-cache" "pruned"
  else
    ui_err "$1-cache" "'$cmd' failed"
    return 1
  fi
}

# _clean_approved YES: true when the caller may prune (--yes, or a yes at
# the prompt); with no terminal and no --yes, only the report.
_clean_approved() {
  [[ "$1" != 1 ]] || return 0
  if [[ ! -t 0 || "${DOTFILES_NONINTERACTIVE:-0}" == 1 ]]; then
    ui_info "Report only" "no terminal to ask; run 'dot system clean --caches --yes' to prune"
    return 1
  fi
  ui_confirm "Prune these caches?" "n"
}

# dot_system_clean_caches [--caches] [--yes|-y]: report, ask, prune.
dot_system_clean_caches() {
  local root yes=0 arg before rc=0 name
  for arg in "$@"; do
    case "$arg" in
      --caches) ;;
      --yes | -y) yes=1 ;;
      *) dot_usage_error "unknown flag '$arg' for 'dot system clean'" "dot system clean [--caches] [--logs] [--yes]" ;;
    esac
  done
  root="$(dot_build_root)"
  ui_header "Build caches ($root)"
  _clean_report "$root"
  before="$_CLEAN_KB"
  _clean_approved "$yes" || return 0
  for name in uv pip go; do
    _clean_one "$name" "$root/$name-cache" || rc=1
  done
  _clean_report "$root" quiet
  ui_ok "Reclaimed" "$(((before - _CLEAN_KB) / 1024)) MiB"
  return "$rc"
}
