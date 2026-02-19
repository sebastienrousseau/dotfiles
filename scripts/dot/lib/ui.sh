#!/usr/bin/env bash
# Dotfiles CLI UI Helpers

UI_ENABLED=0
UI_INITED=0

ui_init() {
  if [[ "$UI_INITED" = "1" ]]; then
    return
  fi
  if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
    UI_ENABLED=1
  else
    UI_ENABLED=0
  fi
  UI_INITED=1
}

ui_header() {
  local text="$1"
  ui_init
  if [[ "$UI_ENABLED" = "1" ]]; then
    gum style --foreground 212 --bold "$text"
  else
    echo "$text"
  fi
}

ui_section() {
  local text="$1"
  ui_init
  if [[ "$UI_ENABLED" = "1" ]]; then
    gum style --foreground 212 --bold "$text"
  else
    echo "$text"
  fi
}

ui_status() {
  local symbol="$1"
  local label="$2"
  local detail="${3:-}"
  local width=35
  if [[ -n "$detail" ]]; then
    printf "  %-2s %-*s %s\n" "$symbol" "$width" "$label" "$detail"
  else
    printf "  %-2s %s\n" "$symbol" "$label"
  fi
}

ui_ok() { ui_status "✓" "$1" "${2:-}"; }
ui_warn() { ui_status "⚠" "$1" "${2:-}"; }
ui_err() { ui_status "✗" "$1" "${2:-}"; }
ui_info() { ui_status "•" "$1" "${2:-}"; }

ui_kv() {
  local key="$1"
  local val="$2"
  local width=14
  printf "  %-*s %s\n" "$width" "$key" "$val"
}
