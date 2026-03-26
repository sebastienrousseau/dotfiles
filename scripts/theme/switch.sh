#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
## Theme Switcher — Switch between theme families and light/dark modes.
##
## Supports Tokyo Night, Catppuccin, Rose Pine, Kanagawa, and other
## popular theme families. Updates chezmoi data and applies changes.
##
## # Requirements
## - chezmoi: Dotfiles manager
## - sed: For updating theme configuration
##
## # Usage
## dot theme list              # Show all available themes
## dot theme set NAME          # Set theme to NAME
## dot theme toggle            # Toggle light/dark within family
## dot theme family            # Switch between theme families
## dot theme current           # Show current theme info
##
## # Platform Notes
## - All platforms: Updates chezmoi configuration

set -euo pipefail

# Cleanup function for temp files
cleanup() {
  if [[ -n "${tmp_file:-}" ]] && [[ -f "$tmp_file" ]]; then
    rm -f "$tmp_file"
  fi
}
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init

resolve_source_dir() {
  if [ -n "${CHEZMOI_SOURCE_DIR:-}" ] && [ -d "$CHEZMOI_SOURCE_DIR" ]; then
    echo "$CHEZMOI_SOURCE_DIR"
    return
  fi
  if [ -d "$HOME/.dotfiles" ]; then
    echo "$HOME/.dotfiles"
    return
  fi
  if [ -d "$HOME/.local/share/chezmoi" ]; then
    echo "$HOME/.local/share/chezmoi"
    return
  fi
  echo ""
}

SRC_DIR="$(resolve_source_dir)"
if [ -z "$SRC_DIR" ]; then
  ui_err "Dotfiles source" "not found"
  exit 1
fi

DATA_FILE="$SRC_DIR/.chezmoidata.toml"
if [ ! -f "$DATA_FILE" ]; then
  ui_err "Missing" "$DATA_FILE"
  exit 1
fi

# =============================================================================
# Theme Database
# =============================================================================

# Default preferences
DEFAULT_DARK="catppuccin-mocha"
DEFAULT_LIGHT="catppuccin-latte"
TOKYO_DARK="tokyonight-night"
TOKYO_LIGHT="tokyonight-day"
CATPPUCCIN_DARK="catppuccin-mocha"
CATPPUCCIN_LIGHT="catppuccin-latte"

# =============================================================================
# Theme Functions
# =============================================================================

current_theme() {
  awk -F'"' '/^theme =/ {print $2}' "$DATA_FILE" | head -n 1
}

get_theme_family() {
  theme="$1"
  case "$theme" in
    tokyonight-*) echo "tokyonight" ;;
    catppuccin-*) echo "catppuccin" ;;
    rose-pine*) echo "rose-pine" ;;
    kanagawa-*) echo "kanagawa" ;;
    gruvbox-*) echo "gruvbox" ;;
    solarized-*) echo "solarized" ;;
    everforest-*) echo "everforest" ;;
    abstract-waves-*) echo "abstract-waves" ;;
    adwaita-*) echo "adwaita" ;;
    colourful-*) echo "colourful" ;;
    imac-blue-*) echo "imac-blue" ;;
    macos-big-sur-*) echo "macos-big-sur" ;;
    macos-mojave-*) echo "macos-mojave" ;;
    macos-monterey-*) echo "macos-monterey" ;;
    macos-sequoia-*) echo "macos-sequoia" ;;
    macos-sonoma-*) echo "macos-sonoma" ;;
    macos-tahoe-*) echo "macos-tahoe" ;;
    macos-ventura-*) echo "macos-ventura" ;;
    monterey-sierra-blue-*) echo "monterey-sierra-blue" ;;
    *) echo "other" ;;
  esac
}

is_dark_theme() {
  theme="$1"
  case "$theme" in
    *-night | *-storm | *-moon | *-mocha | *-frappe | *-macchiato | *-dark | *-wave | *-dragon | dracula | nord | onedark)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

set_theme() {
  local new_theme="$1"
  if [ -z "$new_theme" ]; then
    pick_theme
    return
  fi
  dot-theme-sync "$new_theme"
}

# Interactive theme picker
pick_theme() {
  if ! command -v fzf &>/dev/null; then
    ui_err "fzf" "required for interactive picker"
    ui_info "Usage" "dot theme set <name>"
    exit 1
  fi

  local current
  current="$(current_theme)"

  local themes_file="$SRC_DIR/.chezmoidata/themes.toml"
  if [[ ! -f "$themes_file" ]]; then
    ui_err "Missing" "$themes_file"
    exit 1
  fi

  # Build theme list with metadata
  local theme_list=""
  local name mode family
  while IFS= read -r section; do
    name="${section#\[themes.}"
    name="${name%\]}"
    [[ "$name" == *.* ]] && continue

    mode="$(awk -v n="$name" '
      $0 == "[themes." n "]" { found=1; next }
      /^\[/ { found=0 }
      found && /^mode/ { sub(/.*= *"/, ""); sub(/".*/, ""); print; exit }
    ' "$themes_file")"
    mode="${mode:-dark}"

    family="$(get_theme_family "$name")"
    local marker="○"
    [[ "$name" == "$current" ]] && marker="✓"

    theme_list+="$(printf '%s  %-25s  %-10s  %s' "$marker" "$name" "$mode" "$family")"$'\n'
  done < <(grep '^\[themes\.[a-z]' "$themes_file" | grep -v '\.\(term\|ui\|app\|ext\)\]')

  local selected
  selected="$(echo "$theme_list" | fzf \
    --header "Select theme (current: $current)" \
    --prompt "Theme > " \
    --height 30 \
    --reverse \
    --no-sort \
    --no-preview \
    --ansi |
    awk '{print $2}')" || return 0

  if [[ -n "$selected" && "$selected" != "$current" ]]; then
    dot-theme-sync "$selected"
  elif [[ "$selected" == "$current" ]]; then
    ui_info "Theme" "already on $current"
  fi
}

list_themes() {
  ui_header "Catppuccin (Recommended)"
  ui_ok "catppuccin-latte" "(light)"
  ui_ok "catppuccin-frappe" "(dark - muted)"
  ui_ok "catppuccin-macchiato" "(dark - balanced)"
  ui_ok "catppuccin-mocha" "(dark - rich)"
  echo ""
  ui_header "Tokyo Night"
  ui_ok "tokyonight-day" "(light)"
  ui_ok "tokyonight-storm" "(dark - muted)"
  ui_ok "tokyonight-night" "(dark - default)"
  ui_ok "tokyonight-moon" "(dark - softer)"
  echo ""
  ui_header "Rose Pine"
  ui_ok "rose-pine" "(dark)"
  ui_ok "rose-pine-moon" "(dark - softer)"
  ui_ok "rose-pine-dawn" "(light)"
  echo ""
  ui_header "Kanagawa"
  ui_ok "kanagawa-wave" "(dark - default)"
  ui_ok "kanagawa-dragon" "(dark - vibrant)"
  ui_ok "kanagawa-lotus" "(light)"
  echo ""
  ui_header "Other"
  ui_ok "dracula" "(dark)"
  ui_ok "gruvbox-light" "(light)"
  ui_ok "gruvbox-dark" "(dark)"
  ui_ok "nord" "(dark)"
  ui_ok "onelight" "(light)"
  ui_ok "onedark" "(dark)"
  ui_ok "solarized-light" "(light)"
  ui_ok "solarized-dark" "(dark)"
  ui_ok "everforest-light" "(light)"
  ui_ok "everforest-dark" "(dark)"
  echo ""
  ui_info "Current theme" "$(current_theme)"
}

# Toggle between light and dark within the same family, or switch families
toggle_theme() {
  current="$(current_theme)"
  family="$(get_theme_family "$current")"

  if is_dark_theme "$current"; then
    # Currently dark, switch to light variant
    case "$family" in
      tokyonight) set_theme "$TOKYO_LIGHT" ;;
      catppuccin) set_theme "$CATPPUCCIN_LIGHT" ;;
      rose-pine) set_theme "rose-pine-dawn" ;;
      kanagawa) set_theme "kanagawa-lotus" ;;
      gruvbox) set_theme "gruvbox-light" ;;
      solarized) set_theme "solarized-light" ;;
      everforest) set_theme "everforest-light" ;;
      # Wallpaper themes: swap -dark to -light
      abstract-waves | adwaita | colourful | imac-blue | \
        macos-big-sur | macos-mojave | macos-monterey | macos-sequoia | \
        macos-sonoma | macos-tahoe | macos-ventura | monterey-sierra-blue)
        set_theme "${current%-dark}-light"
        ;;
      *) set_theme "$DEFAULT_LIGHT" ;;
    esac
  else
    # Currently light, switch to dark variant
    case "$family" in
      tokyonight) set_theme "$TOKYO_DARK" ;;
      catppuccin) set_theme "$CATPPUCCIN_DARK" ;;
      rose-pine) set_theme "rose-pine" ;;
      kanagawa) set_theme "kanagawa-wave" ;;
      gruvbox) set_theme "gruvbox-dark" ;;
      solarized) set_theme "solarized-dark" ;;
      everforest) set_theme "everforest-dark" ;;
      # Wallpaper themes: swap -light to -dark
      abstract-waves | adwaita | colourful | imac-blue | \
        macos-big-sur | macos-mojave | macos-monterey | macos-sequoia | \
        macos-sonoma | macos-tahoe | macos-ventura | monterey-sierra-blue)
        set_theme "${current%-light}-dark"
        ;;
      *) set_theme "$DEFAULT_DARK" ;;
    esac
  fi
}

# Switch between Tokyo Night and Catppuccin families
switch_family() {
  current="$(current_theme)"
  family="$(get_theme_family "$current")"

  if is_dark_theme "$current"; then
    # Stay in dark mode, switch family
    case "$family" in
      tokyonight) set_theme "$CATPPUCCIN_DARK" ;;
      catppuccin) set_theme "$TOKYO_DARK" ;;
      *) set_theme "$CATPPUCCIN_DARK" ;;
    esac
  else
    # Stay in light mode, switch family
    case "$family" in
      tokyonight) set_theme "$CATPPUCCIN_LIGHT" ;;
      catppuccin) set_theme "$TOKYO_LIGHT" ;;
      *) set_theme "$CATPPUCCIN_LIGHT" ;;
    esac
  fi
}

# Show current theme info
show_current() {
  current="$(current_theme)"
  family="$(get_theme_family "$current")"
  if is_dark_theme "$current" 2>/dev/null; then
    mode="dark"
  else
    mode="light"
  fi
  ui_info "Current" "$current ($family, $mode)"
}

# Detect system appearance (Dark/Light) and sync dotfiles
sync_theme() {
  local os_mode="dark" # Default fallback
  case "$(uname -s)" in
    Darwin)
      if defaults read -g AppleInterfaceStyle >/dev/null 2>&1; then
        os_mode="dark"
      else
        os_mode="light"
      fi
      ;;
    Linux)
      if command -v gsettings >/dev/null 2>&1; then
        # Check GNOME color scheme
        scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
        if [[ "$scheme" == "prefer-light" ]]; then
          os_mode="light"
        else
          os_mode="dark"
        fi
      fi
      ;;
  esac

  current="$(current_theme)"
  if is_dark_theme "$current" && [[ "$os_mode" == "light" ]]; then
    ui_info "Sync" "System is light, switching dotfiles to light..."
    toggle_theme
  elif ! is_dark_theme "$current" && [[ "$os_mode" == "dark" ]]; then
    ui_info "Sync" "System is dark, switching dotfiles to dark..."
    toggle_theme
  else
    ui_ok "Sync" "Dotfiles already match system ($os_mode mode)"
  fi
}

# =============================================================================
# Main
# =============================================================================

case "${1:-}" in
  list)
    list_themes
    ;;
  set)
    shift
    set_theme "$1"
    ;;
  toggle)
    toggle_theme
    ;;
  sync)
    sync_theme
    ;;
  family)
    switch_family
    ;;
  current)
    show_current
    ;;
  help | --help | -h)
    ui_header "Usage"
    ui_info "dot theme" "[command]"
    echo ""
    ui_header "Commands"
    ui_ok "(no args)" "Interactive theme picker (fzf)"
    ui_ok "list" "Show all available themes"
    ui_ok "set [NAME]" "Set theme (interactive if no name)"
    ui_ok "toggle" "Toggle between light/dark within current family"
    ui_ok "family" "Cycle between theme families"
    ui_ok "current" "Show current theme info"
    ui_ok "sync" "Sync dotfiles with system dark/light mode"
    echo ""
    show_current
    ;;
  "")
    pick_theme
    ;;
  *)
    # Treat unknown args as theme names for quick switching: dot theme dracula
    if grep -q "^\[themes\.${1}\]" "$SRC_DIR/.chezmoidata/themes.toml" 2>/dev/null; then
      dot-theme-sync "$1"
    else
      ui_err "Unknown command or theme" "$1"
      ui_info "Usage" "dot theme [list|set <name>|toggle|family|current|help]"
      exit 1
    fi
    ;;
esac
