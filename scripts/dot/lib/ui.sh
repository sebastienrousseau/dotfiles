#!/usr/bin/env bash
# UI Library for Dotfiles CLI
# Provides functions for consistent, visually appealing output.

# --- Colors and Styles ---
if command -v tput >/dev/null && tput setaf 1 >/dev/null 2>&1; then
  BOLD=$(tput bold)
  UNDERLINE=$(tput smul)
  NORMAL=$(tput sgr0)
  BLACK=$(tput setaf 0)
  RED=$(tput setaf 1)
  GREEN=$(tput setaf 2)
  YELLOW=$(tput setaf 3)
  BLUE=$(tput setaf 4)
  MAGENTA=$(tput setaf 5)
  CYAN=$(tput setaf 6)
  WHITE=$(tput setaf 7)
  GRAY=$(tput setaf 8)
else
  BOLD=""
  UNDERLINE=""
  NORMAL=""
  BLACK=""
  RED=""
  GREEN=""
  YELLOW=""
  BLUE=""
  MAGENTA=""
  CYAN=""
  WHITE=""
  GRAY=""
fi

# --- Symbols ---
if [[ "$(locale charmap)" == "UTF-8" ]]; then
  SYMBOL_SUCCESS="✓"
  SYMBOL_ERROR="✗"
  SYMBOL_WARN="⚠"
  SYMBOL_INFO="›"
  SYMBOL_ARROW="→"
  SYMBOL_BULLET="•"
  BOX_TOP_LEFT="┌"
  BOX_TOP_RIGHT="┐"
  BOX_BOTTOM_LEFT="└"
  BOX_BOTTOM_RIGHT="┘"
  BOX_HORIZONTAL="─"
  BOX_VERTICAL="│"
else
  SYMBOL_SUCCESS="OK"
  SYMBOL_ERROR="ERR"
  SYMBOL_WARN="WARN"
  SYMBOL_INFO=">"
  SYMBOL_ARROW="->"
  SYMBOL_BULLET="*"
  BOX_TOP_LEFT="+"
  BOX_TOP_RIGHT="+"
  BOX_BOTTOM_LEFT="+"
  BOX_BOTTOM_RIGHT="+"
  BOX_HORIZONTAL="-"
  BOX_VERTICAL="|"
fi

# --- UI Functions ---

ui_header() {
  local text=" $1 "
  printf "\n%s%s%s\n" "${BOLD}${BLUE}" "$text" "${NORMAL}"
}

ui_section() {
  printf "\n%s%s%s\n" "${BOLD}${CYAN}" "$1" "${NORMAL}"
}

ui_key_value() {
  printf "  %-20s: %s\n" "$1" "$2"
}

ui_success() {
  printf "%s %s %s\n" "${GREEN}${SYMBOL_SUCCESS}${NORMAL}" "$@"
}

ui_error() {
  printf "%s %s %s\n" "${RED}${SYMBOL_ERROR}${NORMAL}" "$@" >&2
}

ui_warn() {
  printf "%s %s %s\n" "${YELLOW}${SYMBOL_WARN}${NORMAL}" "$@"
}

ui_info() {
  printf "%s %s %s\n" "${GRAY}${SYMBOL_INFO}${NORMAL}" "$@"
}

ui_bullet() {
  printf "  %s %s\n" "${GRAY}${SYMBOL_BULLET}${NORMAL}" "$@"
}

ui_ask() {
  local prompt="$1"
  while true; do
    read -p "$prompt [y/N] " -r reply
    case "$reply" in
      [Yy]*) return 0 ;;
      [Nn]*|"") return 1 ;;
      *) printf "Please answer yes or no.\n" ;;
    esac
  done
}

ui_spinner_start() {
  local text="$1"
  (
    while true; do
      for char in "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"; do
        printf "\r%s %s %s" "${BLUE}${char}${NORMAL}" "$text"
        sleep 0.1
      done
    done
  ) &
  SPINNER_PID=$!
  tput civis
}

ui_spinner_stop() {
  if [[ -n "$SPINNER_PID" ]]; then
    kill "$SPINNER_PID"
    printf "\r\033[K"
    tput cnorm
    SPINNER_PID=""
  fi
}

# ui_box <color> <title>
# Draws a box with a title
ui_box_start() {
    local color="$1"
    local title="$2"
    local width
    width=$(tput cols)
    local title_len=${#title}
    local padding=$(( (width - title_len - 2) / 2 ))
    printf "%s%s" "$color" "$BOX_TOP_LEFT"
    for ((i=0; i<padding; i++)); do printf "%s" "$BOX_HORIZONTAL"; done
    printf " %s " "$title"
    for ((i=0; i<padding; i++)); do printf "%s" "$BOX_HORIZONTAL"; done
    printf "%s%s\n" "$BOX_TOP_RIGHT" "$NORMAL"
}

ui_box_end() {
    local color="$1"
    local width
    width=$(tput cols)
    printf "%s%s" "$color" "$BOX_BOTTOM_LEFT"
    for ((i=0; i<width-2; i++)); do printf "%s" "$BOX_HORIZONTAL"; done
    printf "%s%s\n" "$BOX_BOTTOM_RIGHT" "$NORMAL"
}
