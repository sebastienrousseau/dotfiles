#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by switch.sh; inherits set -euo pipefail
# Theme history for dot theme: plan, undo, history, diff, export/import
# snapshots and reset. Sourced by scripts/theme/switch.sh.

# dot theme plan
_theme_cmd_plan() {
  shift
  plan_name="${1:-}"
  if [[ -z "$plan_name" ]]; then
    ui_err "Usage" "dot theme plan <family|variant> [--mode auto|dark|light] [--json]"
    exit 1
  fi
  shift
  plan_mode=""
  plan_json=false
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

  plan_family="${plan_name%-dark}"
  [[ "$plan_family" != "$plan_name" ]] || plan_family="${plan_name%-light}"
  plan_args=(--plan)
  [[ "$plan_json" == true ]] && plan_args+=(--json)

  if [[ -z "$plan_mode" && "$plan_family" != "$plan_name" ]]; then
    plan_target="$plan_name"
  else
    [[ -n "$plan_mode" ]] || plan_mode="auto"
    if [[ "$plan_mode" == "auto" ]]; then
      plan_target="${plan_family}-$(system_appearance_mode)"
      plan_args+=(--auto)
    else
      plan_target="${plan_family}-${plan_mode}"
    fi
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
_theme_cmd_diff() {
  shift
  if [[ $# -lt 2 ]]; then
    ui_err "Usage" "dot theme diff <theme-a> <theme-b>"
    exit 1
  fi
  a="$1"
  b="$2"
  if ! grep -q "^\[themes\.${a}\]$" "$THEMES_FILE"; then
    ui_err "Unknown" "theme '$a'"
    exit 1
  fi
  if ! grep -q "^\[themes\.${b}\]$" "$THEMES_FILE"; then
    ui_err "Unknown" "theme '$b'"
    exit 1
  fi
  ui_header "Theme diff: $a  vs  $b"
  awk -v A="$a" -v B="$b" '
      BEGIN {
        esc = sprintf("%c[", 27)
        for (side in slot) delete slot[side]
      }
      function set_slot(name, section, key, value) {
        # `section` is "" for root, "app" or "ui" or "term"
        slot[name "." section "." key] = value
      }
      function get(name, section, key) {
        return slot[name "." section "." key]
      }
      function hex2int(h,   n,i,c,d) {
        d="0123456789abcdef"; n=0; h=tolower(h)
        for(i=1;i<=length(h);i++){c=index(d,substr(h,i,1)); if(c==0)return 0; n=n*16+(c-1)}
        return n
      }
      function swatch(hex,  s,r,g,b) {
        if (hex == "" || hex !~ /^#/) return "    "
        s = substr(hex, 2)
        r = hex2int(substr(s,1,2)); g = hex2int(substr(s,3,2)); b = hex2int(substr(s,5,2))
        return esc "48;2;" r ";" g ";" b "m    " esc "0m"
      }
      function val(line,   v) { v=line; sub(/^[^=]*= *"?/,"",v); sub(/"?[[:space:]]*$/,"",v); return v }
      {
        if ($0 == "[themes." A "]")      { name=A; section=""; next }
        else if ($0 == "[themes." A ".ui]")   { name=A; section="ui"; next }
        else if ($0 == "[themes." A ".term]") { name=A; section="term"; next }
        else if ($0 == "[themes." B "]")      { name=B; section=""; next }
        else if ($0 == "[themes." B ".ui]")   { name=B; section="ui"; next }
        else if ($0 == "[themes." B ".term]") { name=B; section="term"; next }
        else if (/^\[/) { name=""; section=""; next }
      }
      name != "" && /=/ {
        key = $0; sub(/ *=.*/, "", key)
        set_slot(name, section, key, val($0))
      }
      function row(label, left, right) {
        mark = (left == right ? " " : "≠")
        printf "  %s  %-14s  %-24s  %-24s\n", mark, label, left, right
      }
      function row_sw(label, left, right) {
        mark = (left == right ? " " : "≠")
        printf "  %s  %-14s  %s %-18s  %s %-18s\n", mark, label, swatch(left), left, swatch(right), right
      }
      END {
        row("family",       get(A,"","family"),        get(B,"","family"))
        row("mode",         get(A,"","mode"),          get(B,"","mode"))
        row("macos_accent", get(A,"","macos_accent"),  get(B,"","macos_accent"))
        row("wallpaper",    get(A,"","wallpaper"),     get(B,"","wallpaper"))
        row_sw("ui.accent", get(A,"ui","accent"),      get(B,"ui","accent"))
        row_sw("term.bg",   get(A,"term","bg"),        get(B,"term","bg"))
        row_sw("term.fg",   get(A,"term","fg"),        get(B,"term","fg"))
      }
    ' "$THEMES_FILE"
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
