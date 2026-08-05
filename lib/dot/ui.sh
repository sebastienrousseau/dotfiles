#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by scripts/dot/commands/*.sh, scripts/diagnostics/*, scripts/ops/*; inherits set -euo pipefail.
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

# Re-source guard: re-sourcing would zero out the BOLD/RED/etc colour
# variables that ui_init() populated, breaking already-rendered output.
[[ "${_DOT_LIB_UI_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_UI_LOADED=1

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

  # --- Color palette (hardcoded ANSI; no tput forks) ---
  # This previously forked ~10 `tput` processes on every ui_init, and because
  # the dispatched command module re-sources ui.sh and re-inits, that doubled
  # to ~20 forks per invocation on a TTY. The escapes below are exactly what
  # `tput bold/sgr0/setaf` emit on a standard terminal (the bin/dot fallback
  # already hardcodes the same idea), so appearance is unchanged with zero forks.
  if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
    UI_COLOR=1
    BOLD=$'\033[1m'
    NORMAL=$'\033[0m'
    RED=$'\033[31m'
    GREEN=$'\033[32m'
    YELLOW=$'\033[33m'
    BLUE=$'\033[34m'
    MAGENTA=$'\033[35m'
    CYAN=$'\033[36m'
    GRAY=$'\033[90m'
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
  # The newline is only needed when stdout is NOT a TTY. We must return
  # 0 either way — without the explicit `return 0`, the function's exit
  # status comes from the trailing `[[ ! -t 1 ]] && printf` chain, which
  # is rc=1 on a TTY and breaks every caller running under `set -e`.
  [[ ! -t 1 ]] && printf "\n"
  return 0
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

  # Guard against the rc_file being empty (race between subshell exit
  # and parent read): an unset rc would default to non-numeric "" and
  # fail the `[[ == "0" ]]` check confusingly. Treat empty as failure.
  local rc=""
  [[ -s "$rc_file" ]] && rc="$(<"$rc_file")"
  rm -f "$rc_file"
  rc="${rc:-1}"

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
# Theme colour export — dogfood the active wallpaper theme in dot-ui
#
# Exports DOT_UI_* from the active [themes.NAME.ui]/.term colours so the
# renderer matches the current wallpaper. Missing values are fine — dot-ui
# falls back per-field to its fixed palette.
# ═══════════════════════════════════════════════════════════════════════

# Resolve + cache the chezmoi source paths for the theme data.
_ui_theme_files() {
  [[ -n "${_UI_THEMES_FILE:-}" ]] && return 0
  local src=""
  if command -v chezmoi >/dev/null 2>&1; then
    src="$(chezmoi source-path 2>/dev/null || true)"
  fi
  [[ -z "$src" && -d "$HOME/.local/share/chezmoi" ]] && src="$HOME/.local/share/chezmoi"
  [[ -z "$src" && -d "$HOME/.dotfiles" ]] && src="$HOME/.dotfiles"
  [[ -n "$src" ]] || return 1
  if [[ -f "$src/.chezmoiroot" ]]; then
    local sub
    sub="$(head -1 "$src/.chezmoiroot" | tr -d '[:space:]')"
    [[ -n "$sub" && -d "$src/$sub" ]] && src="$src/$sub"
  fi
  _UI_DATA_FILE="$src/.chezmoidata.toml"
  _UI_THEMES_FILE="$src/.chezmoidata/themes.toml"
  [[ -f "$_UI_THEMES_FILE" ]] || return 1
  return 0
}

_ui_active_mode() {
  case "$(uname -s)" in
    Darwin)
      [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null || true)" == "Dark" ]] &&
        echo dark || echo light
      ;;
    *)
      if command -v gsettings >/dev/null 2>&1 &&
        [[ "$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || true)" == *dark* ]]; then
        echo dark
      else
        echo light
      fi
      ;;
  esac
}

# The active theme section, e.g. "pulse-dark" (family from .chezmoidata.toml +
# current mode, tolerant of unpaired themes).
_ui_active_theme_section() {
  _ui_theme_files || return 1
  local family mode cand
  family="$(awk -F'"' '/^theme *=/{print $2; exit}' "$_UI_DATA_FILE" 2>/dev/null || true)"
  [[ -n "$family" ]] || return 1
  mode="$(_ui_active_mode)"
  for cand in "${family}-${mode}" "${family}-dark" "${family}-light" "$family"; do
    if grep -q "^\[themes\.${cand}\]" "$_UI_THEMES_FILE" 2>/dev/null; then
      echo "$cand"
      return 0
    fi
  done
  return 1
}

# theme_ui_value <section> <subsection> <key>  → hex colour (or empty).
theme_ui_value() {
  local section="$1" sub="$2" key="$3"
  _ui_theme_files || return 0
  awk -v sec="[themes.${section}.${sub}]" -v key="$key" '
    $0 == sec { inss = 1; next }
    /^\[/ { inss = 0 }
    inss && $1 == key {
      v = $3
      gsub(/[",]/, "", v)
      print v
      exit
    }
  ' "$_UI_THEMES_FILE" 2>/dev/null || true
}

_ui_export_theme_colors() {
  [[ "${_UI_COLORS_EXPORTED:-0}" == "1" ]] && return 0
  _UI_COLORS_EXPORTED=1
  local sec
  sec="$(_ui_active_theme_section 2>/dev/null || true)"
  [[ -n "$sec" ]] || return 0
  export DOT_UI_ACCENT DOT_UI_ERROR DOT_UI_WARNING DOT_UI_SUCCESS DOT_UI_INFO
  export DOT_UI_PANEL DOT_UI_BORDER DOT_UI_FG DOT_UI_BG
  DOT_UI_ACCENT="$(theme_ui_value "$sec" ui accent)"
  DOT_UI_ERROR="$(theme_ui_value "$sec" ui error)"
  DOT_UI_WARNING="$(theme_ui_value "$sec" ui warning)"
  DOT_UI_SUCCESS="$(theme_ui_value "$sec" ui success)"
  DOT_UI_INFO="$(theme_ui_value "$sec" ui info)"
  DOT_UI_PANEL="$(theme_ui_value "$sec" ui panel)"
  DOT_UI_BORDER="$(theme_ui_value "$sec" ui border)"
  DOT_UI_FG="$(theme_ui_value "$sec" term fg)"
  DOT_UI_BG="$(theme_ui_value "$sec" term bg)"
}

# ═══════════════════════════════════════════════════════════════════════
# Step-runner API (delegates to the `dot-ui` renderer)
#
# Sequential multi-step operations (theme sync, heal, upgrade, …). In a rich
# TTY with dot-ui present it streams NDJSON to an animated Bubble Tea view;
# otherwise it prints today's plain ui_ok/ui_info/ui_err lines. Every
# step-runner using this one API is what makes the output consistent.
#
#   ui_steps_begin "dot theme" "pulse"
#   ui_step ghostty "Ghostty" run
#   ...work...
#   ui_step ghostty "Ghostty" ok "reloaded"
#   ui_step dms "DMS" na                  # dropped — not applicable here
#   ui_steps_end "reloaded ghostty, desktop"
# ═══════════════════════════════════════════════════════════════════════
_UI_STEPS_ACTIVE=0
_UI_STEPS_RICH=0
_UI_STEPS_FD=""
_UI_STEPS_PID=""
_UI_STEPS_START=""
# Step id → label store.
#
# This was `declare -gA _UI_STEP_LABELS`. Associative arrays are bash 4
# only, and macOS still ships 3.2 as /bin/bash. The `2>/dev/null ||
# true` made the declaration look harmless, but the *use* was not: on
# 3.2, `arr[some-id]=x` evaluates the subscript as arithmetic, so a
# non-numeric id like "install-deps" became `install - deps` and, under
# `set -u`, aborted with "install: unbound variable". Any `dot` command
# using the steps API died on stock macOS in plain (non-dot-ui) mode.
#
# Parallel indexed arrays work identically on 3.2 and 4+. Step counts
# are small (tens at most), so the linear lookup costs nothing.
_UI_STEP_IDS=()
_UI_STEP_LABEL_VALUES=()

_ui_step_label_set() {
  local id="$1" label="$2" i=0
  while ((i < ${#_UI_STEP_IDS[@]})); do
    if [[ "${_UI_STEP_IDS[$i]}" == "$id" ]]; then
      _UI_STEP_LABEL_VALUES[$i]="$label"
      return 0
    fi
    ((i++)) || true
  done
  _UI_STEP_IDS+=("$id")
  _UI_STEP_LABEL_VALUES+=("$label")
}

# Echoes the stored label, or the id itself when none was recorded.
_ui_step_label_get() {
  local id="$1" i=0
  while ((i < ${#_UI_STEP_IDS[@]})); do
    if [[ "${_UI_STEP_IDS[$i]}" == "$id" ]]; then
      printf '%s' "${_UI_STEP_LABEL_VALUES[$i]}"
      return 0
    fi
    ((i++)) || true
  done
  printf '%s' "$id"
}

# Milliseconds since epoch (macOS `date` lacks %N → fall back to seconds).
_ui_now_ms() {
  local ns
  ns="$(date +%s%N 2>/dev/null || true)"
  if [[ -z "$ns" || "$ns" == *N ]]; then
    echo $(($(date +%s) * 1000))
  else
    echo $((ns / 1000000))
  fi
}

# Minimal JSON string escaper (backslash + quote; flatten newlines/tabs).
_ui_json_esc() {
  local s="${1//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/ }"
  s="${s//$'\t'/ }"
  printf '%s' "$s"
}

# Write one event to the renderer, never failing the caller.
_ui_steps_emit() {
  [[ -n "$_UI_STEPS_FD" ]] || return 0
  { printf '%s\n' "$1" >&"$_UI_STEPS_FD"; } 2>/dev/null || true
}

# Rich-mode gate: interactive TTY + dot-ui, honouring every opt-out.
_ui_steps_rich_ok() {
  [[ -t 1 ]] || return 1
  [[ "${DOTFILES_ACCESSIBILITY:-0}" != "1" ]] || return 1
  [[ -z "${NO_COLOR:-}" ]] || return 1
  [[ "${DOTFILES_NO_TUI:-0}" != "1" ]] || return 1
  command -v dot-ui >/dev/null 2>&1 || return 1
  return 0
}

ui_steps_begin() {
  local title="${1:-}" subtitle="${2:-}"
  ui_init
  _UI_STEPS_ACTIVE=1
  _UI_STEPS_START="$(_ui_now_ms)"
  _UI_STEP_IDS=()
  _UI_STEP_LABEL_VALUES=()

  if _ui_steps_rich_ok; then
    _ui_export_theme_colors
    # FIFO: dot-ui reads events on stdin while its stdout stays the terminal,
    # and we keep a real PID to wait on when finalising.
    local fifo
    fifo="$(mktemp -u 2>/dev/null || echo "/tmp/dot-ui.$$.$RANDOM")"
    if mkfifo "$fifo" 2>/dev/null; then
      dot-ui run <"$fifo" &
      _UI_STEPS_PID=$!
      if exec {_UI_STEPS_FD}>"$fifo" 2>/dev/null; then
        rm -f "$fifo"
        _UI_STEPS_RICH=1
        _ui_steps_emit "{\"t\":\"header\",\"title\":\"$(_ui_json_esc "$title")\",\"subtitle\":\"$(_ui_json_esc "$subtitle")\"}"
        return 0
      fi
      # exec failed — reap the blocked reader and fall back.
      kill "$_UI_STEPS_PID" 2>/dev/null || true
      _UI_STEPS_PID=""
      rm -f "$fifo"
    fi
  fi

  _UI_STEPS_RICH=0
  if [[ -n "$title" ]]; then
    [[ -n "$subtitle" ]] && ui_section "$title · $subtitle" || ui_section "$title"
  fi
  return 0
}

# ui_step <id> <label> <state> [detail]   state: run|ok|skip|fail|warn|na
ui_step() {
  local id="$1" label="${2:-}" state="${3:-run}" detail="${4:-}"
  [[ "$_UI_STEPS_ACTIVE" == "1" ]] || return 0

  if [[ "$_UI_STEPS_RICH" == "1" ]]; then
    _ui_steps_emit "{\"t\":\"step\",\"id\":\"$(_ui_json_esc "$id")\",\"label\":\"$(_ui_json_esc "$label")\",\"state\":\"$(_ui_json_esc "$state")\",\"detail\":\"$(_ui_json_esc "$detail")\"}"
    return 0
  fi

  # Plain mode: remember the label (set on the `run` event), print only on a
  # terminal state so each step is exactly one line.
  [[ -n "$label" ]] && _ui_step_label_set "$id" "$label"
  local lbl
  lbl="$(_ui_step_label_get "$id")"
  case "$state" in
    ok) ui_ok "$lbl" "$detail" ;;
    skip) ui_info "$lbl" "$detail" ;;
    fail) ui_err "$lbl" "$detail" ;;
    warn) ui_warn "$lbl" "$detail" ;;
    na | run) : ;;
  esac
  return 0
}

ui_step_progress() {
  [[ "$_UI_STEPS_ACTIVE" == "1" && "$_UI_STEPS_RICH" == "1" ]] || return 0
  _ui_steps_emit "{\"t\":\"progress\",\"cur\":${1:-0},\"total\":${2:-0}}"
}

# Indeterminate wait line (spinner + label) — rich mode only.
ui_step_wait() {
  [[ "$_UI_STEPS_ACTIVE" == "1" && "$_UI_STEPS_RICH" == "1" ]] || return 0
  _ui_steps_emit "{\"t\":\"wait\",\"label\":\"$(_ui_json_esc "${1:-}")\"}"
}

ui_steps_end() {
  local summary="${1:-}"
  [[ "$_UI_STEPS_ACTIVE" == "1" ]] || return 0

  if [[ "$_UI_STEPS_RICH" == "1" ]]; then
    local elapsed=0
    [[ -n "$_UI_STEPS_START" ]] && elapsed=$(($(_ui_now_ms) - _UI_STEPS_START))
    _ui_steps_emit "{\"t\":\"done\",\"elapsed_ms\":${elapsed},\"summary\":\"$(_ui_json_esc "$summary")\"}"
    [[ -n "$_UI_STEPS_FD" ]] && exec {_UI_STEPS_FD}>&-
    [[ -n "$_UI_STEPS_PID" ]] && wait "$_UI_STEPS_PID" 2>/dev/null || true
  elif [[ -n "$summary" ]]; then
    ui_ok "Done" "$summary"
  fi

  _UI_STEPS_ACTIVE=0
  _UI_STEPS_RICH=0
  _UI_STEPS_FD=""
  _UI_STEPS_PID=""
  return 0
}

# ═══════════════════════════════════════════════════════════════════════
# Interactive picker — themed dot-ui list with fzf/gum/plain fallback
#
#   sel="$(printf '%s\n' "$rows" | ui_pick --header "…" --prompt "…")"
#
# Prints the chosen line (empty on cancel / no selector). Prefers dot-ui pick
# (rendered on /dev/tty, themed to the wallpaper); falls back to fzf, then gum
# choose. dot-ui pick's exit code distinguishes an intentional cancel (1, stop)
# from an inability to run (2, fall back).
# ═══════════════════════════════════════════════════════════════════════
ui_pick() {
  local header="" prompt=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --header)
        header="${2:-}"
        shift 2
        ;;
      --prompt)
        prompt="${2:-}"
        shift 2
        ;;
      *) shift ;;
    esac
  done
  ui_init
  local input
  input="$(cat)"

  if command -v dot-ui >/dev/null 2>&1 &&
    [[ "${DOTFILES_NO_TUI:-0}" != "1" ]] &&
    [[ "${DOTFILES_ACCESSIBILITY:-0}" != "1" ]] &&
    [[ -z "${NO_COLOR:-}" ]]; then
    _ui_export_theme_colors
    local sel rc
    sel="$(printf '%s\n' "$input" | dot-ui pick --header "$header" --prompt "$prompt")"
    rc=$?
    case "$rc" in
      0)
        printf '%s\n' "$sel"
        return 0
        ;;
      1) return 0 ;; # cancelled — no selection
      *) : ;;        # 2 = could not run → fall through
    esac
  fi

  if command -v fzf >/dev/null 2>&1 && [[ -t 2 ]]; then
    local -a fzf_args=(--height 30 --reverse --no-sort --no-preview --ansi)
    [[ -n "$header" ]] && fzf_args+=(--header "$header")
    [[ -n "$prompt" ]] && fzf_args+=(--prompt "$prompt ")
    printf '%s\n' "$input" | fzf "${fzf_args[@]}" || true
    return 0
  fi

  if command -v gum >/dev/null 2>&1 && [[ -t 2 ]]; then
    printf '%s\n' "$input" | gum choose || true
    return 0
  fi

  return 0 # no interactive selector available
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
  # Same bash 3.2 empty-array hazard as ui_table_end: _UI_TABLE_WIDTHS
  # is empty until ui_table_header populates it, so a separator drawn
  # before any header would abort under `set -u`.
  for w in ${_UI_TABLE_WIDTHS[@]+"${_UI_TABLE_WIDTHS[@]}"}; do
    ((total += w)) || true
  done
  printf '  '
  local i
  for ((i = 0; i < total - 2; i++)); do printf '─'; done
  printf '\n'
}

# ═══════════════════════════════════════════════════════════════════════
# Buffered table — accumulates rows then renders via `gum table -p`
# (rounded borders) when gum is on PATH and stdout is a TTY; falls back
# to the existing printf-based ui_table_header/row otherwise.
#
#   ui_table_begin "Tool" "Version" "Source" "Requested"
#   ui_table_add   "node" "24.14.0" "~/.dotfiles/mise.toml" "24.14.0"
#   ui_table_add   "node" "25.9.0"  ""                       ""
#   ui_table_end
#
# Cells may contain anything except ASCII US (0x1f), the internal row
# separator. Empty cells render as blank in both modes.
#
# Environment overrides:
#   DOTFILES_NO_TUI=1   force the printf fallback even if gum is installed
#   NO_COLOR=…          standard convention; also forces the fallback
# ═══════════════════════════════════════════════════════════════════════
_UI_TABLE_HEADERS=()
_UI_TABLE_ROWS=()

ui_table_begin() {
  _UI_TABLE_HEADERS=("$@")
  _UI_TABLE_ROWS=()
}

ui_table_add() {
  if [[ "${#_UI_TABLE_HEADERS[@]}" -eq 0 ]]; then
    return 1
  fi
  local IFS=$'\x1f'
  _UI_TABLE_ROWS+=("$*")
}

ui_table_end() {
  if [[ "${#_UI_TABLE_HEADERS[@]}" -eq 0 ]]; then
    return 0
  fi

  # Preferred: a themed dot-ui table (matches the active wallpaper). Buffered
  # data, static render — safe, no terminal takeover. Falls through to gum /
  # printf when dot-ui is absent or any opt-out is set.
  if command -v dot-ui >/dev/null 2>&1 &&
    [[ -t 1 ]] &&
    [[ "${DOTFILES_NO_TUI:-0}" != "1" ]] &&
    [[ "${DOTFILES_ACCESSIBILITY:-0}" != "1" ]] &&
    [[ -z "${NO_COLOR:-}" ]]; then
    _ui_export_theme_colors
    local _hdr IFS=$'\x1f'
    _hdr="${_UI_TABLE_HEADERS[*]}"
    if {
      printf '%s\n' "$_hdr"
      # A zero-row table is legitimate (a search that matched nothing).
      # bash 3.2 — still /bin/bash on macOS — treats "${arr[@]}" on an
      # empty array as an unbound variable under `set -u`, which is
      # fatal regardless of errexit. Guard on the count.
      ((${#_UI_TABLE_ROWS[@]} > 0)) && printf '%s\n' "${_UI_TABLE_ROWS[@]}"
    } | dot-ui table 2>/dev/null; then
      _UI_TABLE_HEADERS=()
      _UI_TABLE_ROWS=()
      return 0
    fi
  fi

  local use_gum=0
  if command -v gum >/dev/null 2>&1 &&
    [[ -t 1 ]] &&
    [[ "${DOTFILES_NO_TUI:-0}" != "1" ]] &&
    [[ -z "${NO_COLOR:-}" ]]; then
    use_gum=1
  fi

  if ((use_gum)); then
    local header_row
    local IFS=$'\x1f'
    header_row="${_UI_TABLE_HEADERS[*]}"
    # Charm palette: 212 = hot pink (matches ui_header), 240 = muted grey.
    # Cell colour intentionally left at terminal default so the table
    # reads on both light and dark backgrounds.
    # Override via DOTFILES_TABLE_{BORDER,HEADER}_FG env vars.
    local border_fg="${DOTFILES_TABLE_BORDER_FG:-240}"
    local header_fg="${DOTFILES_TABLE_HEADER_FG:-212}"
    {
      printf '%s\n' "$header_row"
      # See the bash 3.2 empty-array note in ui_table_end above.
      ((${#_UI_TABLE_ROWS[@]} > 0)) && printf '%s\n' "${_UI_TABLE_ROWS[@]}"
    } | gum table --print \
      --separator=$'\x1f' \
      --border=rounded \
      --border.foreground="$border_fg" \
      --header.foreground="$header_fg" \
      --padding="0 1" 2>/dev/null ||
      _ui_table_printf_fallback
  else
    _ui_table_printf_fallback
  fi

  _UI_TABLE_HEADERS=()
  _UI_TABLE_ROWS=()
}

_ui_table_printf_fallback() {
  ui_init
  # Pre-scan all buffered rows + headers to compute per-column width so
  # values aren't truncated or collide. Min width 8, +2 padding.
  local ncols="${#_UI_TABLE_HEADERS[@]}"
  local -a widths=()
  local i
  for ((i = 0; i < ncols; i++)); do
    widths[i]="${#_UI_TABLE_HEADERS[i]}"
  done
  local row
  for row in ${_UI_TABLE_ROWS[@]+"${_UI_TABLE_ROWS[@]}"}; do
    local -a _fields=()
    local IFS=$'\x1f'
    read -ra _fields <<<"$row"
    for ((i = 0; i < ncols; i++)); do
      local len="${#_fields[i]}"
      ((len > widths[i])) && widths[i]=$len
    done
  done
  for ((i = 0; i < ncols; i++)); do
    ((widths[i] += 2))
    ((widths[i] < 8)) && widths[i]=8
  done

  # Emit header (bold when color available), separator, then rows.
  local out="  "
  for ((i = 0; i < ncols; i++)); do
    if [[ "$UI_COLOR" = "1" ]]; then
      out+="$(printf '%s%-*s%s' "$BOLD" "${widths[i]}" "${_UI_TABLE_HEADERS[i]}" "$NORMAL")"
    else
      out+="$(printf '%-*s' "${widths[i]}" "${_UI_TABLE_HEADERS[i]}")"
    fi
  done
  printf '%s\n' "$out"

  local total=2
  for ((i = 0; i < ncols; i++)); do ((total += widths[i])); done
  printf '  '
  for ((i = 0; i < total - 2; i++)); do printf '─'; done
  printf '\n'

  for row in ${_UI_TABLE_ROWS[@]+"${_UI_TABLE_ROWS[@]}"}; do
    local -a _fields=()
    local IFS=$'\x1f'
    read -ra _fields <<<"$row"
    out="  "
    for ((i = 0; i < ncols; i++)); do
      out+="$(printf '%-*s' "${widths[i]}" "${_fields[i]:-}")"
    done
    printf '%s\n' "$out"
  done
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
