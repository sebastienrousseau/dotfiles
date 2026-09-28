#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by ai.sh; inherits set -euo pipefail
# The `dot ai` status screen: rows from the probe cache, the offer to
# install missing CLIs (gum chooser, native installers, mise) and the
# launcher. Sourced by scripts/dot/commands/ai.sh.

# _ai_status_rows <entries...>: one row per CLI from the status cache;
# fills the caller's installed (name|bin|role) and missing (name|bin).
_ai_status_rows() {
  local entry category role name bin desc ver current_category="" st_installed st_ver
  for entry in "$@"; do
    IFS='|' read -r category role name bin desc <<<"$entry"
    if [[ "$category" != "$current_category" ]]; then
      echo ""
      ui_section "$category"
      current_category="$category"
    fi
    # One awk over the cache row; no row (EOF, `|| true`) reads as not installed.
    st_installed="" st_ver=""
    IFS=$'\t' read -r st_installed st_ver < <(
      awk -F'\t' -v b="$bin" '$1==b{print $2"\t"$3;exit}' "$AI_STATUS_CACHE_FILE" 2>/dev/null
    ) || true
    if [[ "$st_installed" == "1" ]]; then
      ver="${st_ver:-installed}"
      [[ "$bin" == "claude" ]] && ver="${ver%% *}"
      ui_ok "$name" "$ver — $desc"
      installed+=("$name|$bin|$role")
    else
      ui_info "$name" "— $desc (not installed)"
      missing+=("$name|$bin")
    fi
  done
}

# _ai_native_installer <bin>: the vendor installer function for tools that
# have no mise package (empty for the rest).
_ai_native_installer() {
  case "$1" in
    claude | goose | agy | amp | grok | kimi) echo "install_${1}_native" ;;
    cursor-agent) echo "install_cursor_native" ;;
  esac
}

# _ai_install_one <name> <bin>: the native installer, else mise (under a
# gum spinner when gum is still there).
_ai_install_one() {
  local name="$1" bin="$2" native pkg
  native="$(_ai_native_installer "$bin")"
  if [[ -n "$native" ]]; then
    "$native" "$name"
    return 0
  fi
  pkg=$(_ai_mise_pkg "$bin")
  [[ -n "$pkg" ]] || return 0
  if ! has_command gum; then
    ui_info "Installing" "$name via mise ($pkg)"
    _ai_in_scratch_dir mise use -g "$pkg@latest" 2>&1 || ui_warn "$name" "install failed (continuing)" # mutation: ignore unreachable: gum answered the prompt above and stays hashed, so has_command gum is still true here
    return 0
  fi
  if _ai_in_scratch_dir gum spin --spinner dot --title "Installing $name ($pkg)" -- \
    mise use -g "$pkg@latest" 2>&1; then
    ui_ok "$name" "installed"
  else
    ui_warn "$name" "install failed (continuing)"
  fi
}

# _ai_pick_missing: append the missing entries the user ticks in gum to the
# caller's _ai_to_install.
_ai_pick_missing() {
  local entry name bin picked selected
  local -a choices=()
  for entry in "${missing[@]}"; do
    IFS='|' read -r name bin <<<"$entry"
    choices+=("$name")
  done
  picked=$(printf '%s\n' "${choices[@]}" |
    gum choose --no-limit --header "Select providers to install (Space to toggle, Enter to confirm)") || picked=""
  [[ -n "$picked" ]] || return 0
  while IFS= read -r selected; do
    [[ -z "$selected" ]] && continue
    for entry in "${missing[@]}"; do
      IFS='|' read -r name bin <<<"$entry"
      if [[ "$name" == "$selected" ]]; then
        _ai_to_install+=("$entry")
      fi
    done
  done <<<"$picked"
}

# _ai_can_offer: missing CLIs, mise to install them, and a person at a
# terminal to ask.
_ai_can_offer() {
  [[ ${#missing[@]} -gt 0 && -t 0 && -t 1 && "${DOTFILES_NONINTERACTIVE:-0}" != "1" ]] && has_command mise
}

# _ai_choose_install: fill the caller's _ai_to_install through gum (all, a
# choice, or none); without gum, print how to install them instead.
_ai_choose_install() {
  local action=""
  if ! has_command gum; then
    ui_info "Tip" "Install missing providers: mise install"
    ui_info "Tip" "Or individually: mise use -g <package>@latest"
    return 0
  fi
  action=$(printf '%s\n' "Install all" "Choose which to install" "Skip" |
    gum choose --header "Missing AI providers — install via mise?") || action=""
  case "$action" in
    "Install all") _ai_to_install=("${missing[@]}") ;;
    "Choose which to install") _ai_pick_missing ;;
  esac
}

# _ai_offer_install: offer to install the missing CLIs via mise.
_ai_offer_install() {
  local entry name bin
  local -a _ai_to_install=()
  _ai_can_offer || return 0
  echo ""
  _ai_choose_install
  [[ ${#_ai_to_install[@]} -gt 0 ]] || return 0
  echo ""
  for entry in "${_ai_to_install[@]}"; do
    IFS='|' read -r name bin <<<"$entry"
    _ai_install_one "$name" "$bin"
  done
  # Invalidate cache after installs
  rm -f "$AI_STATUS_CACHE_FILE"
  echo ""
  ui_ok "Done" "Run 'dot ai' again to see updated status"
}

# _ai_launch_menu: pick an installed CLI with gum and exec it.
_ai_launch_menu() {
  local entry name bin role pick
  local -a choices=()
  ui_info "Launch" "Select an AI CLI to start"
  for entry in "${installed[@]}"; do
    IFS='|' read -r name bin role <<<"$entry"
    choices+=("$(printf '%-16s — %s' "$name" "$role")")
  done
  pick=$(printf '%s\n' "${choices[@]}" | gum choose --header "Select an AI CLI") || true
  [ -n "$pick" ] || return 0
  pick="${pick%% — *}"
  pick="${pick%"${pick##*[![:space:]]}"}"
  for entry in "${installed[@]}"; do
    IFS='|' read -r name bin role <<<"$entry"
    if [ "$name" = "$pick" ]; then
      echo ""
      ui_info "Starting" "$name ($bin)"
      exec "$bin"
    fi
  done
}
