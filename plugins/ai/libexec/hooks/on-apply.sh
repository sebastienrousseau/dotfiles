#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# The ai plugin's on-apply hook (P2.2): after `dot apply`, list the roster's
# tools and, on an interactive run, offer to install the missing ones. The
# host runs it from scripts/ops/chezmoi-apply.sh through lib/dot/hooks.sh,
# with DOT_HOOK_INTERACTIVE=1 when it may prompt. The tools, their installers
# and their pins all come from the roster (plugins/ai/roster.toml).
#
# Bash 3.2 compatible (macOS /bin/bash): no associative arrays, no namerefs.

set -euo pipefail

_HOOK_LIB="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../lib/dot" && pwd)"
# shellcheck source=../../../../lib/dot/sdk.sh
source "${DOT_SDK:-$_HOOK_LIB}/sdk.sh"
# shellcheck source=../../../../lib/dot/ai-provision.sh
source "$_HOOK_LIB/ai-provision.sh"

# _on_apply_label <bin>: the roster's display name for a binary (every
# binary has one: both lists are generated from the same roster).
_on_apply_label() {
  local row label bin
  for row in "${AI_ROSTER_STATUS[@]}"; do
    IFS='|' read -r _ _ label bin _ <<<"$row"
    [[ "$bin" != "$1" ]] || printf '%s\n' "$label"
  done
}

# _on_apply_scan: one row per roster tool; the missing ones that something
# here can install go to _missing.
_on_apply_scan() {
  local bin label
  _missing=()
  for bin in "${AI_ROSTER_BINS[@]}"; do
    label="$(_on_apply_label "$bin")"
    if _ai_tool_present "$bin"; then
      ui_ok "$label"
    elif ai_install_method "$bin" >/dev/null; then
      ui_info "$label" "not installed"
      _missing+=("$bin")
    else
      ui_info "$label" "not installed (no installer for this platform)"
    fi
  done
}

# _on_apply_pick: the missing tools whose labels the user ticked.
_on_apply_pick() {
  local bin picked selected
  local -a labels=()
  for bin in "${_missing[@]}"; do labels+=("$(_on_apply_label "$bin")"); done
  picked=$(printf '%s\n' "${labels[@]}" |
    gum choose --no-limit --header "Select providers to install (Space to toggle, Enter to confirm)") || picked=""
  while IFS= read -r selected; do
    [[ -n "$selected" ]] || continue
    for bin in "${_missing[@]}"; do
      [[ "$(_on_apply_label "$bin")" != "$selected" ]] || _to_install+=("$bin")
    done
  done <<<"$picked"
}

# _on_apply_choose: fill _to_install through gum (all, a choice, or none);
# without gum, print how to install them instead.
_on_apply_choose() {
  local action=""
  _to_install=()
  if ! command -v gum >/dev/null 2>&1; then
    ui_info "Tip" "Install every missing AI provider with: dot ai install"
    ui_info "Tip" "Or one: dot ai install <tool> (pinned versions)"
    return 0
  fi
  action=$(printf '%s\n' "Install all" "Choose which to install" "Skip" |
    gum choose --header "Missing AI providers: install them?") || action=""
  case "$action" in
    "Install all") _to_install=("${_missing[@]}") ;;
    "Choose which to install") _on_apply_pick ;;
  esac
}

# _on_apply_offer: offer to install the missing tools (interactive runs only).
_on_apply_offer() {
  local bin label rc
  [[ ${#_missing[@]} -gt 0 && "${DOT_HOOK_INTERACTIVE:-0}" == "1" ]] || return 0
  if ! command -v mise >/dev/null 2>&1; then
    ui_warn "mise" "not found: install mise first to manage AI providers"
    return 0
  fi
  echo ""
  _on_apply_choose
  [[ ${#_to_install[@]} -gt 0 ]] || return 0
  echo ""
  for bin in "${_to_install[@]}"; do
    label="$(_on_apply_label "$bin")"
    rc=0
    ai_install_tool "$bin" "$label" || rc=$?
    ai_install_report "$bin" "$label" "$rc"
  done
}

_on_apply_scan
_on_apply_offer
