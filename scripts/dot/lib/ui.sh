#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
## Dotfiles CLI UI Component Library — Single Source of Truth.
##
## All CLI output MUST go through these primitives.  No raw printf with
## hardcoded ANSI is allowed in scripts; source this file and call the
## functions below instead.
##
## # Primitives
##  Status:   ui_ok, ui_err, ui_warn, ui_info, ui_meta
##  Layout:   ui_header, ui_section, ui_cmd, ui_kv, ui_bullet, ui_logo_dot
##  Animated: ui_spinner_start, ui_spinner_stop, ui_progress, ui_run_cmd
##  Interact: ui_confirm, ui_toast
##  Cursor:   ui_clear_line, ui_hide_cursor, ui_show_cursor
##
## # Platform Notes
## - macOS:  Full support via Homebrew gum
## - Linux:  Full support (tput, UTF-8)
## - WSL:    Works with Windows Terminal color passthrough
## - CI/TTY: Graceful fallback when stdout is not a terminal
##
## # Standards
## - Respects NO_COLOR (https://no-color.org)
## - Respects DOTFILES_ACCESSIBILITY=1 (ASCII-only, no gum)
## - Guarded against multiple source/init (idempotent)
##
## # Usage
##   source "$SCRIPT_DIR/lib/ui.sh"
##   ui_init
##   ui_header "Section Title"
##   ui_ok "Operation succeeded"

# ═══════════════════════════════════════════════════════════════════════
# State — all zeroed before ui_init
# ═══════════════════════════════════════════════════════════════════════
UI_ENABLED=0 # gum available + interactive
UI_INITED=0  # guard flag
UI_COLOR=0   # tput colors available
UI_UTF8=0    # terminal supports UTF-8

BOLD=""
NORMAL=""
RED=""
GREEN=""
YELLOW=""
BLUE=""
MAGENTA=""
CYAN=""
GRAY=""

# Glyph set — overridden to ASCII by DOTFILES_ACCESSIBILITY
_GL_OK="✓"
_GL_FAIL="✗"
_GL_WARN="⚠"
_GL_INFO="•"
_GL_BULLET="•"
_GL_LOGO="◈"
_GL_SPINNER=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
_GL_BAR_FILL="￭"
_GL_BAR_EMPTY="･"

# ═══════════════════════════════════════════════════════════════════════
# Initialisation (called once, guard-protected)
# ═══════════════════════════════════════════════════════════════════════
ui_init() {
  [[ "$UI_INITED" = "1" ]] && return

  # --- Accessibility: disable gum + UTF-8 glyphs ---
  if [[ "${DOTFILES_ACCESSIBILITY:-0}" == "1" ]]; then
    UI_ENABLED=0
    UI_UTF8=0
    _GL_OK="[OK]"
    _GL_FAIL="[FAIL]"
    _GL_WARN="[WARN]"
    _GL_INFO="[INFO]"
    _GL_BULLET="*"
    _GL_LOGO="@"
    _GL_SPINNER=('-' '\\' '|' '/')
    _GL_BAR_FILL="#"
    _GL_BAR_EMPTY="-"
  else
    # gum detection (interactive TTY only)
    if command -v gum >/dev/null 2>&1 && [[ -t 1 ]]; then
      UI_ENABLED=1
    fi
    # UTF-8 detection
    if [[ "$(locale charmap 2>/dev/null || true)" = "UTF-8" ]]; then
      UI_UTF8=1
    fi
  fi

  # --- Color palette (tput) ---
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

# ═══════════════════════════════════════════════════════════════════════
# Layout primitives
# ═══════════════════════════════════════════════════════════════════════

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

# ═══════════════════════════════════════════════════════════════════════
# Status primitives (✓ ✗ ⚠ •)
# ═══════════════════════════════════════════════════════════════════════

ui_status() {
  local symbol="$1"
  local alt_symbol="$2"
  local label="$3"
  local detail="${4:-}"
  local color="${5:-}"
  local width="${6:-35}"
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

ui_ok() { ui_status "$_GL_OK" "[OK]" "$1" "${2:-}" "$GREEN"; }
ui_warn() { ui_status "$_GL_WARN" "[WARN]" "$1" "${2:-}" "$YELLOW"; }
ui_err() { ui_status "$_GL_FAIL" "[FAIL]" "$1" "${2:-}" "$RED"; }
ui_info() { ui_status "$_GL_INFO" "[INFO]" "$1" "${2:-}" "$GRAY"; }
ui_meta() { ui_status "$_GL_INFO" "[INFO]" "$1" "${2:-}" "$GRAY" 14; }

# ═══════════════════════════════════════════════════════════════════════
# Help / key-value primitives
# ═══════════════════════════════════════════════════════════════════════

ui_cmd() {
  local cmd="$1"
  local desc="$2"
  local width="${3:-16}"
  ui_init

  local glyph="$_GL_INFO"
  if [[ "${DOTFILES_ACCESSIBILITY:-0}" == "1" ]]; then
    glyph="-"
  elif [[ "$UI_COLOR" = "1" ]]; then
    glyph="${GREEN}${_GL_INFO}${NORMAL}"
  fi

  if [[ "$UI_COLOR" = "1" ]]; then
    printf "  %-4b %s%-*s%s %s\n" "$glyph" "$GREEN" "$width" "$cmd" "$NORMAL" "$desc"
  else
    printf "  %-4b %-*s %s\n" "$glyph" "$width" "$cmd" "$desc"
  fi
}

ui_bullet() {
  local text="$1"
  ui_init
  if [[ "$UI_COLOR" = "1" ]]; then
    printf "  %s%s%s %s\n" "$GRAY" "$_GL_BULLET" "$NORMAL" "$text"
  else
    printf "  %s %s\n" "$_GL_BULLET" "$text"
  fi
}

ui_kv() {
  local key="$1"
  local val="$2"
  local width="${3:-14}"
  ui_init
  if [[ "$UI_COLOR" = "1" ]]; then
    printf "  %s%-*s%s %s\n" "$BOLD" "$width" "$key" "$NORMAL" "$val"
  else
    printf "  %-*s %s\n" "$width" "$key" "$val"
  fi
}

ui_key_value() { ui_kv "$@"; }

# ═══════════════════════════════════════════════════════════════════════
# Cursor control
# ═══════════════════════════════════════════════════════════════════════

ui_clear_line() { printf '\r\033[K'; }
ui_hide_cursor() { [[ -t 1 ]] && printf '\033[?25l'; }
ui_show_cursor() { [[ -t 1 ]] && printf '\033[?25h'; }

# ═══════════════════════════════════════════════════════════════════════
# Spinner — non-blocking, runs in background
#
#   ui_spinner_start "Loading"
#   some_work ...
#   ui_spinner_stop
# ═══════════════════════════════════════════════════════════════════════
_UI_SPINNER_PID=""

ui_spinner_start() {
  local label="${1:-Working}"
  ui_init
  # No animation when non-interactive
  [[ ! -t 1 ]] && {
    printf "  %s %s..." "$_GL_INFO" "$label"
    return
  }

  ui_hide_cursor
  (
    local i=0
    while true; do
      if [[ "$UI_COLOR" = "1" ]]; then
        printf '\r  %s%s%s %s ' "$BLUE" "${_GL_SPINNER[$i]}" "$NORMAL" "$label"
      else
        printf '\r  %s %s ' "${_GL_SPINNER[$i]}" "$label"
      fi
      i=$(((i + 1) % ${#_GL_SPINNER[@]}))
      sleep 0.08
    done
  ) &
  _UI_SPINNER_PID=$!
}

ui_spinner_stop() {
  if [[ -n "$_UI_SPINNER_PID" ]]; then
    kill "$_UI_SPINNER_PID" 2>/dev/null
    wait "$_UI_SPINNER_PID" 2>/dev/null || true
    _UI_SPINNER_PID=""
  fi
  ui_clear_line
  ui_show_cursor
  [[ ! -t 1 ]] && printf "\n"
}

# ═══════════════════════════════════════════════════════════════════════
# Progress bar
#
#   ui_progress 3 10          # 3/10 complete
#   ui_progress 10 10         # done
# ═══════════════════════════════════════════════════════════════════════

ui_progress() {
  local current="${1:?}" total="${2:?}" width="${3:-20}"
  [[ "$total" -eq 0 ]] && return
  ui_init

  local filled=$((current * width / total))
  local empty=$((width - filled))

  local bar=""
  local i
  for ((i = 0; i < filled; i++)); do bar+="$_GL_BAR_FILL"; done
  for ((i = 0; i < empty; i++)); do bar+="$_GL_BAR_EMPTY"; done

  if [[ "$UI_COLOR" = "1" ]]; then
    printf '%s%s%s' "$BLUE" "${bar:0:$filled}" "$NORMAL"
    printf '%s%s%s' "$GRAY" "${bar:$filled}" "$NORMAL"
  else
    printf '%s' "$bar"
  fi
}

# ═══════════════════════════════════════════════════════════════════════
# Run a command with spinner + progress + result line
#
#   ui_run_cmd "Installing rg" 3 10 mise install ripgrep
#   # Shows:  ⠙ Installing rg  ██████░░░░ 4/10
#   # Then:   ✓ Installing rg          (or ✗ on failure)
# ═══════════════════════════════════════════════════════════════════════

ui_run_cmd() {
  local label="$1" completed="$2" total="$3"
  shift 3
  ui_init

  # Non-interactive: simple pass/fail line
  if [[ ! -t 1 ]]; then
    if "$@" >/dev/null 2>&1; then
      ui_ok "$label"
    else
      ui_err "$label"
      return 1
    fi
    return 0
  fi

  local rc_file
  rc_file=$(mktemp)
  trap 'rm -f "$rc_file"' RETURN
  # Run command in background
  (
    "$@" >/dev/null 2>&1
    echo $? >"$rc_file"
  ) &
  local pid=$!

  # Animate spinner while waiting
  ui_hide_cursor
  local fi=0 w=${#total}
  while kill -0 "$pid" 2>/dev/null; do
    if [[ "$UI_COLOR" = "1" ]]; then
      printf '\r  %s%s%s Installing %s%s%s  ' \
        "$BLUE" "${_GL_SPINNER[$fi]}" "$NORMAL" \
        "$MAGENTA" "$label" "$NORMAL"
    else
      printf '\r  %s Installing %s  ' "${_GL_SPINNER[$fi]}" "$label"
    fi
    ui_progress "$completed" "$total"
    printf ' %*d/%d ' "$w" "$((completed + 1))" "$total"
    fi=$(((fi + 1) % ${#_GL_SPINNER[@]}))
    sleep 0.08
  done
  wait "$pid" 2>/dev/null

  local rc
  rc=$(cat "$rc_file" 2>/dev/null || echo 1)
  rm -f "$rc_file"

  ui_clear_line
  ui_show_cursor
  if [[ "$rc" == "0" ]]; then
    ui_ok "$label"
  else
    ui_err "$label"
  fi
  return "$rc"
}

# ═══════════════════════════════════════════════════════════════════════
# Interactive confirm prompt
#
#   if ui_confirm "Apply changes?"; then ... fi
#   ui_confirm "Destroy?" "n"          # default No
# ═══════════════════════════════════════════════════════════════════════

ui_confirm() {
  local prompt="${1:?}" default="${2:-y}"
  ui_init

  # Non-interactive: use default
  if [[ ! -t 0 ]] || [[ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]]; then
    [[ "$default" =~ ^[Yy] ]]
    return $?
  fi

  # gum confirm if available
  if [[ "$UI_ENABLED" = "1" ]]; then
    gum confirm "$prompt"
    return $?
  fi

  local hint="Y/n"
  [[ "$default" =~ ^[Nn] ]] && hint="y/N"

  local answer
  printf "  %s [%s] " "$prompt" "$hint"
  read -r answer </dev/tty
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[Yy] ]]
}

# ═══════════════════════════════════════════════════════════════════════
# Toast — ephemeral status message (error / success / info)
#
#   ui_toast "success" "Config applied"
#   ui_toast "error"   "chezmoi drift detected"
#   ui_toast "warn"    "3 optional tools missing"
# ═══════════════════════════════════════════════════════════════════════

ui_toast() {
  local level="${1:?}" msg="${2:?}"
  ui_init
  case "$level" in
    success | ok) ui_ok "$msg" ;;
    error | err) ui_err "$msg" ;;
    warn) ui_warn "$msg" ;;
    *) ui_info "$msg" ;;
  esac
}

# ═══════════════════════════════════════════════════════════════════════
# Table — fixed-width columnar output
#
#   ui_table_header "Name" "Status" "Path"
#   ui_table_row    "rg"   "✓"      "~/.local/bin/rg"
#   ui_table_sep
# ═══════════════════════════════════════════════════════════════════════
_UI_TABLE_WIDTHS=()

ui_table_header() {
  ui_init
  _UI_TABLE_WIDTHS=()
  local out="  "
  for col in "$@"; do
    local w=$((${#col} + 4))
    ((w < 12)) && w=12
    _UI_TABLE_WIDTHS+=("$w")
    if [[ "$UI_COLOR" = "1" ]]; then
      out+="$(printf '%s%-*s%s' "$BOLD" "$w" "$col" "$NORMAL")"
    else
      out+="$(printf '%-*s' "$w" "$col")"
    fi
  done
  printf '%s\n' "$out"
}

ui_table_row() {
  local out="  " i=0
  for col in "$@"; do
    local w="${_UI_TABLE_WIDTHS[$i]:-16}"
    out+="$(printf '%-*s' "$w" "$col")"
    ((i++)) || true
  done
  printf '%s\n' "$out"
}

ui_table_sep() {
  local total=2
  for w in "${_UI_TABLE_WIDTHS[@]}"; do
    ((total += w)) || true
  done
  printf '  '
  local i
  for ((i = 0; i < total - 2; i++)); do printf '─'; done
  printf '\n'
}

# ═══════════════════════════════════════════════════════════════════════
# Logo
# ═══════════════════════════════════════════════════════════════════════

ui_logo_dot() {
  local title="${1:-}"
  ui_init
  printf "\n"
  if [[ "${DOTFILES_ACCESSIBILITY:-0}" == "1" ]]; then
    printf "DOTFILES\n"
  elif [[ "$UI_UTF8" = "1" ]]; then
    printf "%s%s DOTFILES %s\n" "${BOLD}${BLUE}" "$_GL_LOGO" "${NORMAL}"
  else
    printf "%sDOTFILES%s\n" "${BOLD}${BLUE}" "${NORMAL}"
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

ui_product_banner() {
  local title="${1:-Dot}"
  ui_init
  if [[ "${DOTFILES_SHOW_LOGO:-1}" != "1" ]]; then
    return 0
  fi
  if [[ "${DOTFILES_LOGO_PRINTED:-0}" = "1" ]]; then
    return 0
  fi
  ui_logo_dot "$title"
  DOTFILES_LOGO_PRINTED=1
  export DOTFILES_LOGO_PRINTED
}

ui_dot_banner() {
  local section="${1:-Dot}"
  ui_product_banner "Dot • $section"
}
