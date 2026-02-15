#!/usr/bin/env bash
# UI Library for Dotfiles CLI
# Provides functions for consistent, visually appealing output.

# --- Colors and Styles ---
# Use tput for wider compatibility and to respect terminal capabilities.
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
# Uses Unicode symbols with ASCII fallbacks for wider compatibility.
if [[ "$(locale charmap)" == "UTF-8" ]]; then
  SYMBOL_SUCCESS="✓"
  SYMBOL_ERROR="✗"
  SYMBOL_WARN="⚠"
  SYMBOL_INFO="›"
  SYMBOL_ARROW="→"
  SYMBOL_BULLET="•"
else
  SYMBOL_SUCCESS="OK"
  SYMBOL_ERROR="ERR"
  SYMBOL_WARN="WARN"
  SYMBOL_INFO=">"
  SYMBOL_ARROW="->"
  SYMBOL_BULLET="*"
fi

# --- UI Functions ---

# ui_header <text>
# Prints a main header with a border.
ui_header() {
  local text=" $1 "
  local width=${#text}
  local border
  border=$(printf "%${width}s" | tr ' ' '─')
  printf "
%s┌%s┐%s
" "${BOLD}${BLUE}" "$border" "${NORMAL}"
  printf "%s│%s│%s
" "${BOLD}${BLUE}" "$text" "${NORMAL}"
  printf "%s└%s┘%s
" "${BOLD}${BLUE}" "$border" "${NORMAL}"
}

# ui_section <text>
# Prints a section header.
ui_section() {
  printf "
%s%s%s
" "${BOLD}${CYAN}" "$1" "${NORMAL}"
}

# ui_key_value <key> <value>
# Prints a key-value pair with aligned formatting.
ui_key_value() {
  printf "  %-20s: %s
" "$1" "$2"
}

# ui_success <text>
# Prints a success message.
ui_success() {
  printf "%s %s %s
" "${GREEN}${SYMBOL_SUCCESS}${NORMAL}" "$@"
}

# ui_error <text>
# Prints an error message.
ui_error() {
  printf "%s %s %s
" "${RED}${SYMBOL_ERROR}${NORMAL}" "$@" >&2
}

# ui_warn <text>
# Prints a warning message.
ui_warn() {
  printf "%s %s %s
" "${YELLOW}${SYMBOL_WARN}${NORMAL}" "$@"
}

# ui_info <text>
# Prints an informational message.
ui_info() {
  printf "%s %s %s
" "${GRAY}${SYMBOL_INFO}${NORMAL}" "$@"
}

# ui_bullet <text>
# Prints a bullet point.
ui_bullet() {
  printf "  %s %s
" "${GRAY}${SYMBOL_BULLET}${NORMAL}" "$@"
}

# ui_ask <prompt>
# Prompts the user for confirmation. Returns 0 for yes, 1 for no.
ui_ask() {
  local prompt="$1"
  while true; do
    read -p "$prompt [y/N] " -r reply
    case "$reply" in
      [Yy]*) return 0 ;;
      [Nn]*|"") return 1 ;;
      *) printf "Please answer yes or no.
" ;;
    esac
  done
}

# ui_spinner_start <text>
# Starts a spinner for a long-running command.
ui_spinner_start() {
  local text="$1"
  (
    while true; do
      for char in "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏"; do
        printf "%s %s %s" "${BLUE}${char}${NORMAL}" "$text"
        sleep 0.1
      done
    done
  ) &
  SPINNER_PID=$!
  # Hide cursor
  tput civis
}

# ui_spinner_stop
# Stops the spinner.
ui_spinner_stop() {
  if [[ -n "$SPINNER_PID" ]]; then
    kill "$SPINNER_PID"
    # Clear the line
    printf "\033[K"
    # Show cursor
    tput cnorm
    SPINNER_PID=""
  fi
}
