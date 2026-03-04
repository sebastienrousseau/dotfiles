#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
## Dotfiles CLI UI Helpers.
##
## Provides terminal UI primitives for consistent output formatting across
## all dot CLI commands. Detects gum availability, color support, and UTF-8
## capability to render appropriate output.
##
## # Dependencies
## - gum (optional): Enhanced TUI rendering
## - tput (coreutils): Color detection
##
## # Platform Notes
## - macOS: Full support via Homebrew gum
## - Linux: Full support via snap/go installed gum
## - WSL: Works with Windows Terminal color passthrough
##
## # Usage
## source "$SCRIPT_DIR/lib/ui.sh"
## ui_init
## ui_header "Section Title"
## ui_ok "Operation succeeded"
##
## # Idempotency
## Safe to source multiple times. ui_init() is guarded.

UI_ENABLED=0
UI_INITED=0
UI_COLOR=0
UI_UTF8=0

BOLD=""
NORMAL=""
RED=""
GREEN=""
YELLOW=""
BLUE=""
MAGENTA=""
CYAN=""
GRAY=""

ui_init() {
  if [[ "$UI_INITED" = "1" ]]; then
    return
  fi

  if [[ "${DOTFILES_ACCESSIBILITY:-0}" == "1" ]]; then
    UI_ENABLED=0
    UI_UTF8=0
  else
    if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
      UI_ENABLED=1
    else
      UI_ENABLED=0
    fi

    if [[ "$(locale charmap 2>/dev/null || true)" = "UTF-8" ]]; then
      UI_UTF8=1
    fi
  fi

  if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && command -v tput >/dev/null 2>&1 && tput setaf 1 >/dev/null 2>&1; then
    UI_COLOR=1
    BOLD="$(tput bold)"
    NORMAL="$(tput sgr0)"
    RED="$(tput setaf 1)"
    GREEN="$(tput setaf 2)"
    YELLOW="$(tput setaf 3)"
    BLUE="$(tput setaf 4)"
    MAGENTA="$(tput setaf 5)"
    CYAN="$(tput setaf 6)"
    GRAY="$(tput setaf 8)"
  fi

  UI_INITED=1
}

ui_header() {
  local text="$1"
  ui_init
  if [[ "$UI_ENABLED" = "1" ]]; then
    gum style --foreground 212 --bold "$text"
  elif [[ "$UI_COLOR" = "1" ]]; then
    printf "%s%s%s\n" "${BOLD}${BLUE}" "$text" "$NORMAL"
  else
    echo "--- $text ---"
  fi
}

ui_section() {
  local text="$1"
  ui_init
  if [[ "$UI_ENABLED" = "1" ]]; then
    gum style --foreground 212 --bold "$text"
  elif [[ "$UI_COLOR" = "1" ]]; then
    printf "%s%s%s\n" "${BOLD}${CYAN}" "$text" "$NORMAL"
  else
    echo "== $text =="
  fi
}

ui_status() {
  local symbol="$1"
  local alt_symbol="$2"
  local label="$3"
  local detail="${4:-}"
  local color="${5:-}"
  local width=35
  ui_init

  local disp_symbol="$symbol"
  if [[ "${DOTFILES_ACCESSIBILITY:-0}" == "1" ]]; then
    disp_symbol="$alt_symbol"
  elif [[ "$UI_COLOR" = "1" ]] && [[ -n "$color" ]]; then
    disp_symbol="${color}${symbol}${NORMAL}"
  fi

  if [[ -n "$detail" ]]; then
    printf "  %-6b %-*s %s\n" "$disp_symbol" "$width" "$label" "$detail"
  else
    printf "  %-6b %s\n" "$disp_symbol" "$label"
  fi
}

ui_ok() { ui_status "✓" "[OK]" "$1" "${2:-}" "$GREEN"; }
ui_warn() { ui_status "⚠" "[WARN]" "$1" "${2:-}" "$YELLOW"; }
ui_err() { ui_status "✗" "[FAIL]" "$1" "${2:-}" "$RED"; }
ui_info() { ui_status "•" "[INFO]" "$1" "${2:-}" "$GRAY"; }

ui_bullet() {
  local text="$1"
  ui_init
  if [[ "${DOTFILES_ACCESSIBILITY:-0}" == "1" ]]; then
    printf "  * %s\n" "$text"
  elif [[ "$UI_COLOR" = "1" ]]; then
    printf "  %b %s\n" "${GRAY}•${NORMAL}" "$text"
  else
    printf "  - %s\n" "$text"
  fi
}

ui_kv() {
  local key="$1"
  local val="$2"
  local width=14
  if [[ "$UI_COLOR" = "1" ]]; then
    printf "  %b%-*s%b %s\n" "${BOLD}" "$width" "$key" "$NORMAL" "$val"
  else
    printf "  %-*s %s\n" "$width" "$key" "$val"
  fi
}

ui_key_value() { ui_kv "$@"; }

ui_logo_dot() {
  local title="${1:-}"
  ui_init
  printf "\n"
  if [[ "${DOTFILES_ACCESSIBILITY:-0}" == "1" ]]; then
    printf "DOTFILES\n"
  elif [[ "$UI_UTF8" = "1" ]]; then
    printf "%s┏━ ┏━┃━┏┛%s\n" "${BOLD}${BLUE}" "${NORMAL}"
    printf "%s┃ ┃┃ ┃ ┃ %s\n" "${BOLD}${CYAN}" "${NORMAL}"
    printf "%s━━ ━━┛ ┛%s\n" "${BOLD}${MAGENTA}" "${NORMAL}"
  else
    printf "%sDOT%s\n" "${BOLD}${BLUE}" "${NORMAL}"
  fi
  if [[ -n "$title" ]]; then
    if [[ "$UI_COLOR" = "1" ]]; then
      printf "%s%s%s\n\n" "${GRAY}" "$title" "${NORMAL}"
    else
      printf "%s\n\n" "$title"
    fi
  else
    printf "\n"
  fi
}
