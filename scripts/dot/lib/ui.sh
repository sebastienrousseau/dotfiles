#!/usr/bin/env bash
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

  if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
    UI_ENABLED=1
  else
    UI_ENABLED=0
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

  if [[ "$(locale charmap 2>/dev/null || true)" = "UTF-8" ]]; then
    UI_UTF8=1
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
    echo "$text"
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
    echo "$text"
  fi
}

ui_status() {
  local symbol="$1"
  local label="$2"
  local detail="${3:-}"
  local color="${4:-}"
  local width=35
  ui_init

  if [[ "$UI_COLOR" = "1" ]] && [[ -n "$color" ]]; then
    symbol="${color}${symbol}${NORMAL}"
  fi

  if [[ -n "$detail" ]]; then
    printf "  %-2b %-*s %s\n" "$symbol" "$width" "$label" "$detail"
  else
    printf "  %-2b %s\n" "$symbol" "$label"
  fi
}

ui_ok() { ui_status "✓" "$1" "${2:-}" "$GREEN"; }
ui_warn() { ui_status "⚠" "$1" "${2:-}" "$YELLOW"; }
ui_err() { ui_status "✗" "$1" "${2:-}" "$RED"; }
ui_info() { ui_status "•" "$1" "${2:-}" "$GRAY"; }

ui_bullet() {
  local text="$1"
  ui_init
  if [[ "$UI_COLOR" = "1" ]]; then
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
  if [[ "$UI_UTF8" = "1" ]]; then
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
