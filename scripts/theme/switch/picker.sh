#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by switch.sh; inherits set -euo pipefail
# Picking and browsing themes for dot theme: the fzf picker, list, toggle,
# family, current, preview, random and help. Sourced by scripts/theme/switch.sh.

# Interactive theme picker — prefers fzf, falls back to a numbered menu
# when fzf isn't installed (useful in restricted environments / CI).
pick_theme() {
  local current
  current="$(current_theme)"

  if [[ ! -f "$THEMES_FILE" ]]; then
    ui_err "Missing" "$THEMES_FILE"
    exit 1
  fi

  local current_family="${current%-dark}"
  [[ "$current_family" != "$current" ]] || current_family="${current%-light}"
  local current_mode="dark"
  is_dark_theme "$current" 2>/dev/null || current_mode="light"

  # Build theme list: one row per family, shows active mode
  local theme_list=""
  local family source marker active_mode
  while IFS= read -r family; do
    [[ -n "$family" ]] || continue
    source="$(wallpaper_source "$family")"
    marker="○"
    active_mode=""
    if [[ "$family" == "$current_family" ]]; then
      marker="✓"
      active_mode="$current_mode"
    fi
    theme_list+="$(printf '%s  %-35s  %-8s  %s' "$marker" "$family" "$source" "$active_mode")"$'\n'
  done < <(paired_families)

  # Preview helper: awk-extracts the theme's accent + wallpaper + full
  # 16-colour ANSI palette, then renders live swatches using 24-bit
  # terminal escapes. Fast — one awk pass, no forks-per-swatch, no
  # image decoding.
  local preview_cmd
  preview_cmd='family={2}; mode='"$current_mode"'; f="'"$THEMES_FILE"'"; awk -v F="$family" -v M="$mode" '"'"'
BEGIN {
  root = "[themes." F "-" M "]"
  ui   = "[themes." F "-" M ".ui]"
  term = "[themes." F "-" M ".term]"
  esc  = sprintf("%c[", 27)
}
function hex2int(h,   n, i, c, digits) {
  digits = "0123456789abcdef"
  n = 0
  h = tolower(h)
  for (i = 1; i <= length(h); i++) {
    c = index(digits, substr(h, i, 1))
    if (c == 0) return 0
    n = n * 16 + (c - 1)
  }
  return n
}
function swatch(hex,   clean, r, g, b) {
  clean = hex
  sub(/^#/, "", clean)
  r = hex2int(substr(clean, 1, 2))
  g = hex2int(substr(clean, 3, 2))
  b = hex2int(substr(clean, 5, 2))
  return esc "48;2;" r ";" g ";" b "m    " esc "0m"
}
$0 == root { in_root=1; in_ui=0; in_term=0; next }
$0 == ui   { in_ui=1; in_root=0; in_term=0; next }
$0 == term { in_term=1; in_root=0; in_ui=0; next }
/^\[/ { in_root=0; in_ui=0; in_term=0; next }
in_root && /^wallpaper /   { sub(/.*= *"?/,""); sub(/"$/,""); wallpaper=$0 }
in_root && /^macos_accent/ { sub(/.*= */,"");   accent_int=$0 }
in_ui && /^accent /        { sub(/.*= *"?/,""); sub(/"$/,""); accent=$0 }
in_term && /^bg /          { sub(/.*= *"?/,""); sub(/"$/,""); bg=$0 }
in_term && /^fg /          { sub(/.*= *"?/,""); sub(/"$/,""); fg=$0 }
in_term && /^c[0-9]+ *= *"/ {
    # Not match($0, re, m): the three-argument form is a gawk extension,
    # and macOS ships the one-true-awk, which rejects it outright — the
    # whole preview then dies with a syntax error.
    _k = $0; sub(/ *=.*$/, "", _k); sub(/^c/, "", _k)
    _v = $0; sub(/^[^"]*"/, "", _v); sub(/".*$/, "", _v)
    term_c[_k+0] = _v
  }
END {
  print "family:    " F " (" M ")"
  print "wallpaper: " wallpaper
  print "accent:    " swatch(accent) " " accent " (macos=" accent_int ")"
  print "bg:        " swatch(bg) " " bg
  print "fg:        " swatch(fg) " " fg
  print ""
  # 16-colour ANSI palette, laid out 8 wide × 2 rows.
  line1 = ""; line2 = ""
  for (i = 0; i <= 7; i++)  line1 = line1 swatch(term_c[i])
  for (i = 8; i <= 15; i++) line2 = line2 swatch(term_c[i])
  print "palette:"
  print "  " line1
  print "  " line2
}'"'"' "$f"'

  local selected_family
  selected_family="$(printf '%s' "$theme_list" | ui_pick \
    --header "Select wallpaper theme (current: $current_family [$current_mode])" \
    --prompt "Theme >" \
    --preview "$preview_cmd" |
    awk '$1 !~ /^#/ && NF >= 2 {print $2}')" || return 0

  if [[ -n "$selected_family" ]]; then
    # Families selected from the picker follow the system appearance. The
    # concrete variant remains available to templates as a resolved cache.
    local selected_mode
    selected_mode="$(system_appearance_mode)"
    local new_theme="${selected_family}-${selected_mode}"
    if [[ "$new_theme" != "$current" || "$(theme_mode_preference)" != "auto" ]]; then
      run_theme_sync "$new_theme" --auto
    else
      ui_info "Theme" "already on $current (auto)"
    fi
  else
    # Cancelled, or no selector could run. Either way nothing changed, and
    # saying so beats exiting mute on a command the user asked to be
    # interactive.
    ui_info "Theme" "no selection — still on $current"
  fi
}

list_themes() {
  local current
  current="$(current_theme)"
  local current_family="${current%-dark}"
  [[ "$current_family" != "$current" ]] || current_family="${current%-light}"

  local count=0
  local family source

  printf '  %-35s  %s\n' "WALLPAPER" "SOURCE"
  printf '  %-35s  %s\n' "---------" "------"
  while IFS= read -r family; do
    [[ -n "$family" ]] || continue
    source="$(wallpaper_source "$family")"
    if [[ "$family" == "$current_family" ]]; then
      ui_ok "$family" "$source ◀"
    else
      printf '  %-35s  %s\n' "$family" "$source"
    fi
    count=$((count + 1))
  done < <(paired_families)

  echo ""
  ui_info "Current" "$(current_theme) ($count wallpaper themes available)"
}

# Toggle between light and dark within the same family, or switch families
toggle_theme() {
  local current
  current="$(current_theme)"

  if is_dark_theme "$current"; then
    if [[ "$current" == *-dark ]]; then
      set_theme "${current%-dark}-light"
    else
      set_theme "$DEFAULT_LIGHT"
    fi
  else
    if [[ "$current" == *-light ]]; then
      set_theme "${current%-light}-dark"
    else
      set_theme "$DEFAULT_DARK"
    fi
  fi
}

# Switch to the next wallpaper family while preserving mode.
switch_family() {
  local current family
  current="$(current_theme)"
  family="$(get_theme_family "$current")"
  local mode="dark"
  local families=()
  local idx=0
  local next_family=""

  if [[ "$current" == *-light ]]; then
    mode="light"
  fi

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    families+=("$name")
  done < <(paired_families)

  if [[ ${#families[@]} -eq 0 ]]; then
    set_theme "$DEFAULT_DARK"
    return
  fi

  for idx in "${!families[@]}"; do
    if [[ "${families[$idx]}" == "$family" ]]; then
      next_family="${families[$(((idx + 1) % ${#families[@]}))]}"
      break
    fi
  done

  if [[ -z "$next_family" ]]; then
    next_family="${families[0]}"
  fi

  if [[ "$(theme_mode_preference)" == "auto" ]]; then
    set_theme "${next_family}-${mode}" --auto
  else
    set_theme "${next_family}-${mode}"
  fi
}

# Show current theme info
show_current() {
  local current family
  current="$(current_theme)"
  family="$(get_theme_family "$current")"
  local mode="dark"
  if ! is_dark_theme "$current" 2>/dev/null; then
    mode="light"
  fi
  ui_info "Current" "$current ($family, $mode; $(theme_mode_preference))"
}

# dot theme set
_theme_cmd_set() {
  shift
  # `"${1:-}"`, not `"$1"`: with no theme name the bare positional aborts
  # the script under `set -u` before set_theme's own empty-string check can
  # open the picker `dot help theme` promises. Worse, the abort is silent
  # about its status on bash 3.2 (macOS /bin/bash): when a script dies on an
  # unbound variable with an EXIT trap installed — switch.sh installs
  # `trap cleanup EXIT` — 3.2 exits 0, and no handler can recover the status
  # because `$?` is already 0 when the handler runs. So on a stock Mac this
  # one missing default turned every `dot theme set` typo into a reported
  # success. Keep every expansion in this script guarded.
  set_theme "${1:-}"
}

# dot theme preview
_theme_cmd_preview() {
  shift
  preview="${1:-}"
  if [[ -z "$preview" ]]; then
    ui_err "Usage" "dot theme preview <name>"
    exit 1
  fi
  prev="$(current_theme)"
  ui_info "Preview" "$preview (was $prev)"
  # Revert on Ctrl-C. Trap fires before exit so the shell prompt
  # returns with the original theme active.
  trap 'echo; run_theme_sync --force "'"$prev"'" >/dev/null 2>&1; ui_info "Reverted" "'"$prev"'"; exit 130' INT
  if ! run_theme_sync --force "$preview"; then
    ui_err "Preview" "apply failed — reverting"
    run_theme_sync --force "$prev" >/dev/null 2>&1
    exit 1
  fi
  echo ""
  read -r -p "  Press ENTER to keep '$preview' or Ctrl-C to revert to '$prev': " _
  trap - INT
  ui_ok "Kept" "$preview"
}

# dot theme random
# Pick a random paired family and apply it. Default mode = current
# mode; override with `--mode dark|light`.
# _theme_random_args <args...>: parse `random` options into the caller's
# _rand_mode / _rand_explicit.
_theme_random_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode | --mode=*)
        local value="${1#--mode=}"
        if [[ "$1" == --mode ]]; then
          shift
          value="${1:-}"
        fi
        # Both spellings are checked: --mode=purple used to reach
        # dot-theme-sync as the theme "<family>-purple".
        case "$value" in
          dark | light) ;;
          *)
            ui_err "Usage" "--mode dark|light"
            exit 1
            ;;
        esac
        _rand_mode="$value"
        _rand_explicit=true
        shift
        ;;
      *)
        ui_err "Usage" "dot theme random [--mode dark|light]"
        exit 1
        ;;
    esac
  done
}

# _theme_random_family <current family>: a random paired family other than
# the current one (the current one only when it is the sole family).
_theme_random_family() {
  local fam
  local -a families=() picks=()
  # Not `mapfile -t`: that is bash 4 only, and macOS ships bash 3.2 as
  # /bin/bash. tests/unit/shell/test_bash32_portability.sh gates on it.
  while IFS= read -r fam; do
    [[ -n "$fam" ]] && families+=("$fam")
  done < <(paired_families)
  [[ ${#families[@]} -gt 0 ]] || return 1
  for fam in "${families[@]}"; do
    [[ "$fam" != "$1" ]] && picks+=("$fam")
  done
  [[ ${#picks[@]} -gt 0 ]] || picks=("${families[@]}")
  printf '%s\n' "${picks[RANDOM % ${#picks[@]}]}"
}

_theme_cmd_random() {
  shift
  local current pick _rand_mode="" _rand_explicit=false
  _theme_random_args "$@"
  current="$(current_theme)"
  if [[ -z "$_rand_mode" ]]; then
    _rand_mode="dark"
    is_dark_theme "$current" 2>/dev/null || _rand_mode="light"
  fi
  if ! pick="$(_theme_random_family "$(_theme_family_of "$current")")"; then
    ui_err "No themes" "run 'dot theme rebuild' first"
    exit 1
  fi
  if [[ "$(theme_mode_preference)" == "auto" && "$_rand_explicit" == false ]]; then
    set_theme "${pick}-${_rand_mode}" --auto
  else
    set_theme "${pick}-${_rand_mode}"
  fi
}

# dot theme help | --help | -h
_theme_cmd_help() {
  ui_header "Usage"
  ui_info "dot theme" "[command]"
  echo ""
  ui_header "Commands"
  ui_ok "(no args)" "Interactive theme picker (fzf)"
  ui_ok "list" "Show all available themes"
  ui_ok "set [NAME]" "Set a family to auto, or an explicit light/dark variant"
  ui_ok "toggle" "Toggle between light/dark within current family"
  ui_ok "mode <dark|light|auto>" "Choose manual mode or follow the system"
  ui_ok "rotate [enable [N]|disable|status]" "Wallpaper rotation timer"
  ui_ok "family" "Cycle to the next family"
  ui_ok "random" "Pick a random family, keep current mode"
  ui_ok "preview [NAME]" "Try a theme, ENTER to keep or Ctrl-C to revert"
  ui_ok "plan <NAME> [--mode M] [--json]" "Pure, versioned operation plan"
  ui_ok "undo" "Step back to the previous theme (re-run to toggle)"
  ui_ok "history" "Show recently-applied themes"
  ui_ok "reset" "Restore GNOME defaults (accent/cursor/fonts/shell theme)"
  ui_ok "current" "Show current theme info"
  ui_ok "status" "Dashboard: recorded vs applied theme state"
  ui_ok "diff <a> <b>" "Side-by-side comparison of two themes"
  ui_ok "accent [color]" "Tweak accent live (no wallpaper/theme change)"
  ui_ok "wallpaper [path]" "Set an arbitrary wallpaper without theme swap"
  ui_ok "fit <mode>" "Wallpaper fit: zoom|spanned|centered|scaled|stretched"
  ui_ok "export [file]" "Snapshot current theme+fit to JSON"
  ui_ok "import <file>" "Restore theme+fit from a snapshot"
  ui_ok "sync" "Enable auto mode and sync with system appearance"
  ui_ok "ambient" "Time-based mode switch (run|enable|disable|status)"
  ui_ok "rebuild" "Regenerate themes from system + custom wallpapers"
  echo ""
  show_current
}
