#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by switch.sh; inherits set -euo pipefail
# Theme history for dot theme: plan, undo, history, diff, export/import
# snapshots and reset. Sourced by scripts/theme/switch.sh.

# dot theme plan
# _theme_plan_args <args...>: parse `plan` options into the caller's
# plan_mode / plan_json.
_theme_plan_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        shift
        plan_mode="${1:-}"
        [[ -n "$plan_mode" ]] || {
          ui_err "Usage" "--mode requires auto, dark, or light"
          exit 1
        }
        shift
        ;;
      --mode=*)
        plan_mode="${1#--mode=}"
        shift
        ;;
      --json)
        plan_json=true
        shift
        ;;
      *)
        ui_err "Unknown option" "$1"
        exit 1
        ;;
    esac
  done
  case "$plan_mode" in
    "" | auto | dark | light) ;;
    *)
      ui_err "Usage" "--mode requires auto, dark, or light"
      exit 1
      ;;
  esac
}

_theme_cmd_plan() {
  shift
  local plan_name="${1:-}" plan_mode="" plan_json=false plan_family plan_target
  local -a plan_args=(--plan)
  if [[ -z "$plan_name" ]]; then
    ui_err "Usage" "dot theme plan <family|variant> [--mode auto|dark|light] [--json]"
    exit 1
  fi
  shift
  _theme_plan_args "$@"
  plan_family="$(_theme_family_of "$plan_name")"
  [[ "$plan_json" == true ]] && plan_args+=(--json)

  if [[ -z "$plan_mode" && "$plan_family" != "$plan_name" ]]; then
    # An explicit variant with no --mode is planned as named.
    plan_target="$plan_name"
  elif [[ "${plan_mode:-auto}" == "auto" ]]; then
    plan_target="${plan_family}-$(system_appearance_mode)"
    plan_args+=(--auto)
  else
    plan_target="${plan_family}-${plan_mode}"
  fi
  run_theme_sync "$plan_target" "${plan_args[@]}"
}

# dot theme undo
# Step back one entry in the theme-history stack. Applied theme goes
# to the top so a second `undo` returns to it (toggle behaviour).
_theme_cmd_undo() {
  hist="${XDG_STATE_HOME:-$HOME/.local/state}/dot/theme-history"
  if [[ ! -s "$hist" ]]; then
    ui_err "History" "empty — no previous theme recorded"
    exit 1
  fi
  prev="$(head -1 "$hist")"
  current="$(current_theme)"
  rest="$(tail -n +2 "$hist" 2>/dev/null | grep -Fxv -- "$current" || true)"
  tmp="$(mktemp)"
  {
    printf '%s\n' "$current"
    [[ -n "$rest" ]] && printf '%s\n' "$rest"
  } >"$tmp"
  mv "$tmp" "$hist"
  set_theme "$prev"
}

# dot theme history
_theme_cmd_history() {
  hist="${XDG_STATE_HOME:-$HOME/.local/state}/dot/theme-history"
  if [[ ! -s "$hist" ]]; then
    ui_info "History" "empty — apply a theme to start tracking"
    exit 0
  fi
  ui_header "Recent themes (newest first)"
  n=1
  while IFS= read -r line; do
    printf '  %2d  %s\n' "$n" "$line"
    n=$((n + 1))
  done <"$hist"
  ui_info "Current" "$(current_theme)"
}

# dot theme reset
# Restore sane defaults: Adwaita GTK, default cursor/font, remove
# accent + shell theme. Wallpaper stays — we don't clobber user
# media choices. Use --force so DE handlers actually re-apply.
_theme_cmd_reset() {
  if command -v gsettings >/dev/null 2>&1; then
    gsettings reset org.gnome.desktop.interface accent-color 2>/dev/null || true
    gsettings reset org.gnome.desktop.interface cursor-theme 2>/dev/null || true
    gsettings reset org.gnome.desktop.interface monospace-font-name 2>/dev/null || true
    gsettings reset org.gnome.desktop.interface font-name 2>/dev/null || true
    gsettings reset org.gnome.desktop.interface document-font-name 2>/dev/null || true
    gsettings set org.gnome.shell.extensions.user-theme name "" 2>/dev/null || true
  fi
  ui_ok "Reset" "GNOME accent / cursor / fonts / shell-theme restored to defaults"
  ui_info "Note" "wallpaper untouched — re-run 'dot theme set <name>' to apply a theme"
}

# dot theme diff
# _theme_require <theme>: exit 1 unless themes.toml has [themes.<theme>].
_theme_require() {
  if ! grep -q "^\[themes\.${1}\]$" "$THEMES_FILE"; then
    ui_err "Unknown" "theme '$1'"
    exit 1
  fi
}

_theme_cmd_diff() {
  shift
  if [[ $# -lt 2 ]]; then
    ui_err "Usage" "dot theme diff <theme-a> <theme-b>"
    exit 1
  fi
  local a="$1" b="$2"
  _theme_require "$a"
  _theme_require "$b"
  ui_header "Theme diff: $a  vs  $b"
  awk -v A="$a" -v B="$b" -f "$SCRIPT_DIR/switch/diff.awk" "$THEMES_FILE"
}

# dot theme export
# Snapshot the current theme + DE state to a portable JSON file.
# `dot theme import` on any machine restores the same theme name
# (wallpaper/accent/cursor are derived from the theme + machine
# env, so we only ship what makes the snapshot reproducible).
_theme_cmd_export() {
  shift
  out="${1:-}"
  payload_theme="$(current_theme)"
  payload_hostname="$(hostname 2>/dev/null || echo unknown)"
  payload_date="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  payload_fit=""
  if command -v gsettings >/dev/null 2>&1; then
    payload_fit="$(gsettings get org.gnome.desktop.background picture-options 2>/dev/null | tr -d "'")"
  fi
  payload="$(printf '{
  "version": 1,
  "theme": "%s",
  "fit": "%s",
  "exported_from": "%s",
  "exported_at": "%s"
}\n' "$payload_theme" "$payload_fit" "$payload_hostname" "$payload_date")"
  if [[ -z "$out" || "$out" == "-" ]]; then
    printf '%s\n' "$payload"
  else
    printf '%s\n' "$payload" >"$out"
    ui_ok "Export" "$out"
  fi
}

# dot theme import
_theme_cmd_import() {
  shift
  in_file="${1:-}"
  if [[ -z "$in_file" || ! -f "$in_file" ]]; then
    ui_err "Usage" "dot theme import <file.json>"
    exit 1
  fi
  # Minimal JSON reader — extract "theme" and "fit" via awk. Avoids a
  # hard jq dependency; JSON emitted by `dot theme export` is fixed
  # shape, so brittle parsing is fine.
  imp_theme="$(awk -F'"' '/"theme"/ {print $4; exit}' "$in_file")"
  imp_fit="$(awk -F'"' '/"fit"/ {print $4; exit}' "$in_file")"
  if [[ -z "$imp_theme" ]]; then
    ui_err "Import" "no theme field in $in_file"
    exit 1
  fi
  if ! grep -q "^\[themes\.${imp_theme}\]$" "$THEMES_FILE"; then
    ui_err "Import" "theme '$imp_theme' not in themes.toml — run 'dot theme rebuild' first"
    exit 1
  fi
  ui_info "Import" "$in_file"
  set_theme "$imp_theme"
  if [[ -n "$imp_fit" && "$imp_fit" != "" ]] && command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.background picture-options "$imp_fit" 2>/dev/null &&
      ui_ok "Fit" "$imp_fit"
  fi
}
