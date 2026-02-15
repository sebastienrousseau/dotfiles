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
  UI_UTF8=true
  SYMBOL_SUCCESS="✓"
  SYMBOL_ERROR="✗"
  SYMBOL_WARN="⚠"
  SYMBOL_INFO="›"
  SYMBOL_ARROW="→"
  SYMBOL_BULLET="•"
  SYMBOL_ELLIPSIS="…"
  BAR_FULL="█"
  BAR_EMPTY="░"
  SPINNER_FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
else
  UI_UTF8=false
  SYMBOL_SUCCESS="OK"
  SYMBOL_ERROR="ERR"
  SYMBOL_WARN="WARN"
  SYMBOL_INFO=">"
  SYMBOL_ARROW="->"
  SYMBOL_BULLET="*"
  SYMBOL_ELLIPSIS="..."
  BAR_FULL="#"
  BAR_EMPTY="-"
  SPINNER_FRAMES=("-" "\\" "|" "/")
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

# --- Progress UI ---

UI_PROGRESS_ACTIVE=false
UI_PROGRESS_TOTAL=0
UI_PROGRESS_CURRENT=0
UI_PROGRESS_TITLE=""
UI_PROGRESS_SPINNER_INDEX=0
UI_PROGRESS_QUIET=false

ui_term_width() {
  if command -v tput >/dev/null 2>&1; then
    tput cols 2>/dev/null || echo 80
  else
    echo 80
  fi
}

ui_strip_ansi() {
  sed -E 's/\x1B\[[0-9;]*[mK]//g'
}

ui_fit_text() {
  local text="$1"
  local max="$2"
  if (( max <= 0 )); then
    echo ""
    return
  fi
  if (( ${#text} <= max )); then
    echo "$text"
    return
  fi
  local ellipsis="$SYMBOL_ELLIPSIS"
  local keep=$((max - ${#ellipsis}))
  if (( keep <= 0 )); then
    echo "${ellipsis:0:max}"
    return
  fi
  echo "${text:0:keep}${ellipsis}"
}

ui_progress_bar() {
  local percent="$1"
  local width="$2"
  local filled=$((percent * width / 100))
  local bar=""
  local i
  for ((i = 0; i < width; i++)); do
    if ((i < filled)); then
      bar+="$BAR_FULL"
    else
      bar+="$BAR_EMPTY"
    fi
  done
  echo "$bar"
}

ui_progress_render() {
  local message="$1"
  if [[ ! -t 1 ]] || ! $UI_PROGRESS_ACTIVE; then
    return
  fi

  local width
  width=$(ui_term_width)

  local spinner="${SPINNER_FRAMES[$UI_PROGRESS_SPINNER_INDEX]}"
  local count=" ${UI_PROGRESS_CURRENT}/${UI_PROGRESS_TOTAL}"
  local percent=0
  if ((UI_PROGRESS_TOTAL > 0)); then
    percent=$((UI_PROGRESS_CURRENT * 100 / UI_PROGRESS_TOTAL))
  fi

  local bar_width=24
  local bar=""
  if (( width < 60 )); then
    bar_width=0
  elif (( width < 80 )); then
    bar_width=14
  else
    bar_width=24
  fi
  if (( bar_width > 0 )); then
    bar=$(ui_progress_bar "$percent" "$bar_width")
  fi

  local base="${spinner}"
  if [[ -n "$bar" ]]; then
    base+=" ${bar}"
  fi
  base+="${count}"
  local base_len
  base_len=$(printf "%s" "$base" | ui_strip_ansi | wc -c | awk '{print $1}')
  local msg_width=$((width - base_len - 2))
  local msg
  msg=$(ui_fit_text "$message" "$msg_width")

  local line
  line="${BLUE}${spinner}${NORMAL} ${GRAY}${msg}${NORMAL}"
  local gap_len=$((width - (base_len + ${#msg}) - 1))
  if ((gap_len < 1)); then
    gap_len=1
  fi
  local gap
  gap=$(printf "%${gap_len}s" "")

  if [[ -n "$bar" ]]; then
    printf "\r\033[K%s%s${GREEN}%s${NORMAL}%s" "$line" "$gap" "$bar" "$count"
  else
    printf "\r\033[K%s%s%s" "$line" "$gap" "$count"
  fi
}

ui_progress_start() {
  local total="$1"
  local title="$2"
  local quiet="${3:-false}"
  UI_PROGRESS_TOTAL="$total"
  UI_PROGRESS_CURRENT=0
  UI_PROGRESS_TITLE="$title"
  UI_PROGRESS_SPINNER_INDEX=0
  UI_PROGRESS_ACTIVE=true
  UI_PROGRESS_QUIET="$quiet"
  if [[ -t 1 ]]; then
    tput civis >/dev/null 2>&1 || true
  fi
  ui_progress_render "$title"
}

ui_progress_set() {
  local current="$1"
  local message="$2"
  UI_PROGRESS_CURRENT="$current"
  UI_PROGRESS_SPINNER_INDEX=$((UI_PROGRESS_SPINNER_INDEX + 1))
  if ((UI_PROGRESS_SPINNER_INDEX >= ${#SPINNER_FRAMES[@]})); then
    UI_PROGRESS_SPINNER_INDEX=0
  fi
  ui_progress_render "$message"
}

ui_progress_advance() {
  local message="$1"
  UI_PROGRESS_CURRENT=$((UI_PROGRESS_CURRENT + 1))
  ui_progress_set "$UI_PROGRESS_CURRENT" "$message"
}

ui_progress_line() {
  local status="$1"
  local text="$2"
  local detail="${3:-}"
  if $UI_PROGRESS_QUIET; then
    return
  fi
  if ! $UI_PROGRESS_ACTIVE || [[ ! -t 1 ]]; then
    case "$status" in
      pass) ui_success "$text" "$detail" ;;
      warn) ui_warn "$text" "$detail" ;;
      fail) ui_error "$text" "$detail" ;;
      info) ui_info "$text" "$detail" ;;
    esac
    return
  fi

  printf "\r\033[K"
  case "$status" in
    pass) ui_success "$text" "$detail" ;;
    warn) ui_warn "$text" "$detail" ;;
    fail) ui_error "$text" "$detail" ;;
    info) ui_info "$text" "$detail" ;;
  esac
}

ui_progress_end() {
  if $UI_PROGRESS_ACTIVE && [[ -t 1 ]]; then
    printf "\r\033[K\n"
    tput cnorm >/dev/null 2>&1 || true
  fi
  UI_PROGRESS_ACTIVE=false
}

# --- Logo ---

ui_logo_dot() {
  local title="$1"
  printf "\n"
  printf "%s┏━ ┏━┃━┏┛%s\n" "${BOLD}${BLUE}" "${NORMAL}"
  printf "%s┃ ┃┃ ┃ ┃ %s\n" "${BOLD}${CYAN}" "${NORMAL}"
  printf "%s━━ ━━┛ ┛%s\n" "${BOLD}${MAGENTA}" "${NORMAL}"
  if [[ -n "$title" ]]; then
    printf "%s%s%s\n\n" "${GRAY}" "$title" "${NORMAL}"
  else
    printf "\n"
  fi
}
