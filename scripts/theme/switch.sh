#!/usr/bin/env bash
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
  new_theme="$1"
  if [ -z "$new_theme" ]; then
    ui_err "Theme" "name required"
    exit 1
  fi
  # Validate theme name: only allow alphanumeric, hyphens, underscores
  case "$new_theme" in
    *[!a-zA-Z0-9_-]*)
      ui_err "Invalid theme name" "$new_theme" >&2
      ui_info "Allowed" "letters, digits, hyphens, underscores" >&2
      exit 1
      ;;
  esac

  tmp_file="$(mktemp)"
  if grep -q '^theme = ' "$DATA_FILE"; then
    sed "s/^theme = .*/theme = \"$new_theme\"/" "$DATA_FILE" >"$tmp_file"
  else
    cat "$DATA_FILE" >"$tmp_file"
    echo "theme = \"$new_theme\"" >>"$tmp_file"
  fi
  mv "$tmp_file" "$DATA_FILE"
  ui_ok "Theme set" "$new_theme"
  ui_info "Applying" "dotfiles"
  chezmoi apply --force 2>/dev/null || chezmoi apply
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
  if is_dark_theme "$current"; then
    mode="dark"
  else
    mode="light"
  fi
  ui_info "Current" "$current ($family, $mode)"
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
  family)
    switch_family
    ;;
  current)
    show_current
    ;;
  "")
    ui_header "Usage"
    ui_info "dot theme" "[command]"
    echo ""
    ui_header "Commands"
    ui_ok "list" "Show all available themes"
    ui_ok "set NAME" "Set theme to NAME"
    ui_ok "toggle" "Toggle between light/dark within current family"
    ui_ok "family" "Switch between Tokyo Night and Catppuccin families"
    ui_ok "current" "Show current theme info"
    echo ""
    show_current
    ;;
  *)
    ui_err "Unknown theme command" "$1"
    ui_info "Usage" "dot theme [list|set <name>|toggle|family|current]"
    exit 1
    ;;
esac
