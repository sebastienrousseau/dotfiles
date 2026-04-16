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
THEMES_FILE="$SRC_DIR/.chezmoidata/themes.toml"
WALLPAPER_DIR="${DOTFILES_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
if [ ! -f "$DATA_FILE" ]; then
  ui_err "Missing" "$DATA_FILE"
  exit 1
fi

# =============================================================================
# Theme Database
# =============================================================================

# Default preferences
DEFAULT_DARK="macos-monterey-dark"
DEFAULT_LIGHT="macos-monterey-light"

# =============================================================================
# Theme Functions
# =============================================================================

current_theme() {
  awk -F'"' '/^theme =/ {print $2}' "$DATA_FILE" | head -n 1
}

theme_mode() {
  local name="${1:-}"
  awk -v n="$name" '
    $0 == "[themes." n "]" { found=1; next }
    /^\[/ { found=0 }
    found && /^mode/ { sub(/.*= *"/, ""); sub(/".*/, ""); print; exit }
  ' "$THEMES_FILE"
}

theme_exists() {
  local name="${1:-}"
  grep -q "^\[themes\.${name}\]$" "$THEMES_FILE" 2>/dev/null
}

all_theme_names() {
  sed -n 's/^\[themes\.\([a-z0-9-]*\)\]$/\1/p' "$THEMES_FILE" | sort -u
}

# List wallpaper families that have BOTH dark and light variants in themes.toml.
# Only these are presented to users — unpaired wallpapers are hidden.
paired_families() {
  local -A has_dark has_light
  local name family
  while IFS= read -r name; do
    if [[ "$name" == *-dark ]]; then
      family="${name%-dark}"
      has_dark["$family"]=1
    elif [[ "$name" == *-light ]]; then
      family="${name%-light}"
      has_light["$family"]=1
    fi
  done < <(all_theme_names)

  for family in $(printf '%s\n' "${!has_dark[@]}" | sort); do
    [[ -n "${has_light[$family]+x}" ]] && echo "$family"
  done
}

# Determine source type (system/custom) for a wallpaper family.
wallpaper_source() {
  local family="${1:-}"
  # Check for custom wallpapers: dynamic (family.heic) or split (family-dark/light.ext)
  for ext in heic jpg png; do
    if [[ -f "$WALLPAPER_DIR/${family}.${ext}" || -f "$WALLPAPER_DIR/${family}-dark.${ext}" || -f "$WALLPAPER_DIR/${family}-light.${ext}" ]]; then
      echo "Custom"
      return
    fi
  done
  echo "System"
}

get_theme_family() {
  local theme="${1:-}"
  # Read family from themes.toml if available
  if [[ -f "$THEMES_FILE" ]]; then
    local family
    family="$(awk -v n="$theme" '
      $0 == "[themes." n "]" { found=1; next }
      /^\[/ { found=0 }
      found && /^family/ { sub(/.*= *"/, ""); sub(/".*/, ""); print; exit }
    ' "$THEMES_FILE")"
    if [[ -n "$family" ]]; then
      echo "$family"
      return
    fi
  fi
  # Fallback: strip -dark/-light suffix
  local family="${theme%-dark}"
  [[ "$family" != "$theme" ]] || family="${theme%-light}"
  echo "$family"
}

is_dark_theme() {
  local theme="${1:-}"
  case "$theme" in
    *-dark)
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
  local current="$(current_theme)"

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

  local selected_family
  selected_family="$(echo "$theme_list" | fzf \
    --header "Select wallpaper theme (current: $current_family [$current_mode])" \
    --prompt "Theme > " \
    --height 30 \
    --reverse \
    --no-sort \
    --no-preview \
    --ansi |
    awk '$1 !~ /^#/ && NF >= 2 {print $2}')" || return 0

  if [[ -n "$selected_family" ]]; then
    # Apply with current appearance mode (dark/light)
    local new_theme="${selected_family}-${current_mode}"
    if [[ "$new_theme" != "$current" ]]; then
      dot-theme-sync "$new_theme"
    else
      ui_info "Theme" "already on $current"
    fi
  fi
}

list_themes() {
  local current="$(current_theme)"
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
  local current="$(current_theme)"

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
  local current="$(current_theme)"
  local family="$(get_theme_family "$current")"
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

  set_theme "${next_family}-${mode}"
}

# Show current theme info
show_current() {
  local current="$(current_theme)"
  local family="$(get_theme_family "$current")"
  local mode="dark"
  if ! is_dark_theme "$current" 2>/dev/null; then
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
        local scheme=scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
        if [[ "$scheme" == "prefer-light" ]]; then
          os_mode="light"
        else
          os_mode="dark"
        fi
      fi
      ;;
  esac

  local current="$(current_theme)"
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
  rebuild)
    shift
    bash "$SCRIPT_DIR/rebuild-themes.sh" "$@"
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
    ui_ok "rebuild" "Regenerate themes from system + custom wallpapers"
    echo ""
    show_current
    ;;
  "")
    pick_theme
    ;;
  *)
    # Treat unknown args as theme names for quick switching: dot theme macos-sequoia-dark
    if grep -q "^\[themes\.${1}\]" "$THEMES_FILE" 2>/dev/null; then
      dot-theme-sync "$1"
    else
      ui_err "Unknown command or theme" "$1"
      ui_info "Usage" "dot theme [list|set <name>|toggle|family|current|help]"
      exit 1
    fi
    ;;
esac
