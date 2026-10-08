#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# One consented path from "an AI tool is missing" to "it is installed", shared
# by `dot ai install`, the `dot ai` status offer, and `dot ai <tool>`.
# Sourced by utils.sh after ai-install.sh and preflight.sh; inherits
# set -euo pipefail.
#
# A tool installs one of two ways: a native installer (checksum-pinned, needs
# curl) or mise. mise is itself offered, with consent, when a tool needs it.
# The native installers never fail loudly, so success is judged by the tool's
# command existing afterwards, not by an exit status.
#
# Bash 3.2 compatible (macOS /bin/bash): no associative arrays, no namerefs.

[[ -n "${_DOT_AI_PROVISION_LOADED:-}" ]] && return 0
_DOT_AI_PROVISION_LOADED=1

# ai_install_method <bin>: native:<function> or mise:<package>; 1 (and no
# output) when nothing can install it.
ai_install_method() {
  local pkg
  case "$1" in
    claude | goose | agy | amp | grok | kimi) printf 'native:install_%s_native' "$1" ;;
    cursor-agent) printf 'native:install_cursor_native' ;;
    *)
      pkg="$(_ai_mise_pkg "$1")"
      [[ -n "$pkg" ]] || return 1
      printf 'mise:%s' "$pkg"
      ;;
  esac
}

# _ai_tool_present <bin>: on PATH, or in the directories the native
# installers write to (a fresh install is not on this shell's PATH yet).
_ai_tool_present() {
  local dir
  hash -r 2>/dev/null || true
  command -v "$1" >/dev/null 2>&1 && return 0
  for dir in "$HOME/.local/bin" "$HOME/.kimi-code/bin" "$HOME/.amp/bin" "$HOME/.grok/bin"; do
    [[ -x "$dir/$1" ]] && return 0
  done
  return 1
}

# ai_prepare <bin>...: the prerequisites these tools need, offered with
# consent before anything installs: mise for mise-installed tools, and curl
# for native installers. Returns 1 when no route to install any of them is
# left (the caller then stops instead of reporting each tool as failed).
ai_prepare() {
  local bin need_mise=0 need_curl=0 routes=0
  for bin in "$@"; do
    case "$(ai_install_method "$bin" || true)" in
      mise:*) need_mise=1 ;;
      native:*) need_curl=1 ;;
    esac
  done
  if [[ "$need_curl" == 1 ]]; then
    if command -v curl >/dev/null 2>&1; then
      routes=1
    else
      ui_warn "curl" "not installed — native installers (claude, goose, …) need it"
    fi
  fi
  if [[ "$need_mise" == 1 ]] && dot_ensure_mise "these AI tools install through it"; then
    routes=1
  fi
  [[ "$routes" == 1 || "$need_mise$need_curl" == 00 ]]
}

# ai_install_tool <bin> [label]: install one tool. 0 installed, 1 failed,
# 2 no installer (or its prerequisite is missing).
ai_install_tool() {
  local bin="$1" label="${2:-$1}" method spec
  method="$(ai_install_method "$bin")" || return 2
  case "$method" in
    native:*)
      command -v curl >/dev/null 2>&1 || return 2
      "${method#native:}" "$label"
      # The native installers report failure only as a warning, so judge
      # by the result.
      _ai_tool_present "$bin"
      ;;
    mise:*)
      command -v mise >/dev/null 2>&1 || return 2
      spec="$(ai_pinned_spec "${method#mise:}")" || return 1
      ui_info "Installing" "$label via mise ($spec)"
      # mise's own status is reliable; the new shim may not be on this
      # shell's PATH yet, so a presence check would misreport success.
      _ai_in_scratch_dir mise use -g "$spec" 2>&1
      ;;
    *) return 2 ;;
  esac
}

# ai_install_report <bin> <label> <status>: one line per tool's outcome.
ai_install_report() {
  case "$3" in
    0) ui_ok "$2" "installed" ;;
    2) ui_warn "$2" "skipped — no installer or prerequisite here" ;;
    *) ui_err "$2" "install failed" ;;
  esac
}

# ai_prereq_rows: prerequisite health for `dot ai doctor`.
ai_prereq_rows() {
  _ai_prereq_row mise "installs most AI tools" "dot upgrade --yes (or dot ai install --yes)"
  _ai_prereq_row node "npm-based tools (codex, copilot, qwen, …)" "mise install node"
  _ai_prereq_row uv "Python tools (aider, sgpt)" "mise install uv"
  _ai_prereq_row curl "native installers (claude, goose, …)" "your system package manager"
  _ai_prereq_row go "builds the dot ai cockpit" "mise install go"
}

_ai_prereq_row() {
  if command -v "$1" >/dev/null 2>&1; then
    ui_ok "$1" "$2"
  else
    ui_warn "$1" "missing — $2; install: $3"
  fi
}
