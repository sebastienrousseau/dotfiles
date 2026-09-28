#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
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
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"

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

# Descend into the chezmoi source subdir when .chezmoiroot is present (post-reorg, chezmoi files under defaults/)
CHEZMOI_SRC="$SRC_DIR"
if [[ -f "$SRC_DIR/.chezmoiroot" ]]; then
  _sub="$(head -1 "$SRC_DIR/.chezmoiroot" | tr -d '[:space:]')"
  [[ -n "$_sub" && -d "$SRC_DIR/$_sub" ]] && CHEZMOI_SRC="$SRC_DIR/$_sub"
fi

DATA_FILE="$CHEZMOI_SRC/.chezmoidata.toml"
THEMES_FILE="$CHEZMOI_SRC/.chezmoidata/themes.toml"
WALLPAPER_DIR="${DOTFILES_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
if [ ! -f "$DATA_FILE" ]; then
  ui_err "Missing" "$DATA_FILE"
  exit 1
fi

# =============================================================================
# Theme Database
# =============================================================================

# Default family (must ship a dark+light pair in themes.toml). Maui uses one
# dynamic HEIC wallpaper while exposing separate palettes to applications.
DEFAULT_DARK="maui-dark"
DEFAULT_LIGHT="maui-light"

# Machine-local chezmoi overrides take precedence over repository defaults.
# Theme switching writes only these overrides so selecting a wallpaper never
# dirties the tracked default configuration.
CHEZMOI_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"
THEME_SYNC_BIN="$(command -v dot-theme-sync 2>/dev/null || true)"
THEME_SYNC_BIN="${THEME_SYNC_BIN:-$HOME/.local/bin/dot-theme-sync}"

# =============================================================================
# Theme Functions
# =============================================================================

theme_setting() {
  local key="${1:-}"
  if [[ -f "$CHEZMOI_CFG" ]]; then
    local override
    override="$(awk -F'"' -v key="$key" '
      /^\[data\]$/ { in_data=1; next }
      /^\[/ { in_data=0 }
      in_data && $0 ~ "^" key "[[:space:]]*=" { print $2; exit }
    ' "$CHEZMOI_CFG")"
    if [[ -n "$override" ]]; then
      echo "$override"
      return 0
    fi
  fi
  awk -F'"' -v key="$key" '$0 ~ "^" key "[[:space:]]*=" {print $2; exit}' "$DATA_FILE"
}

current_theme() { theme_setting theme; }

theme_mode_preference() {
  local mode
  mode="$(theme_setting theme_mode)"
  case "$mode" in
    auto | dark | light) printf '%s\n' "$mode" ;;
    *)
      local current
      current="$(current_theme)"
      is_dark_theme "$current" && printf 'dark\n' || printf 'light\n'
      ;;
  esac
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

run_theme_sync() {
  "$THEME_SYNC_BIN" "$@"
}

all_theme_names() {
  sed -n 's/^\[themes\.\([a-zA-Z0-9-]*\)\]$/\1/p' "$THEMES_FILE" | sort -u
}

# List wallpaper families that have BOTH dark and light variants in themes.toml.
# Only these are presented to users — unpaired wallpapers are hidden.
#
# This was two associative arrays. Those are bash 4 only, and macOS still
# ships 3.2 as /bin/bash, where `local -A` fails outright ("local: -A:
# invalid option"). Both arrays then stayed empty, so this function printed
# nothing and `dot theme list`, `dot theme family` and the interactive picker
# silently offered no themes at all on a stock macOS shell.
#
# Two newline-separated lists plus `comm` behave identically on 3.2 and 4+.
paired_families() {
  local darks="" lights="" name family
  while IFS= read -r name; do
    case "$name" in
      *-dark) darks="${darks}${name%-dark}"$'\n' ;;
      *-light) lights="${lights}${name%-light}"$'\n' ;;
    esac
  done < <(all_theme_names)

  # `fallback` is a synthetic safety theme (see themes.toml) that templates
  # degrade to when .theme is unset/invalid — never a user-selectable one.
  comm -12 \
    <(printf '%s' "$darks" | sort -u) \
    <(printf '%s' "$lights" | sort -u) |
    grep -vxF 'fallback' || true
}

# Determine source type (system/custom) for a wallpaper family.
wallpaper_source() {
  local family="${1:-}"
  # Check for custom wallpapers: dynamic (family.heic) or split (family-dark/light.ext)
  for ext in heic jpg png webp; do
    if [[ -f "$WALLPAPER_DIR/${family}.${ext}" || -f "$WALLPAPER_DIR/${family}-dark.${ext}" || -f "$WALLPAPER_DIR/${family}-light.${ext}" || -f "$WALLPAPER_DIR/${family}-0.${ext}" ]]; then
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

# _theme_family_of <theme>: the family, i.e. the name without its
# -dark/-light suffix (unchanged when it has neither).
_theme_family_of() {
  local family="${1%-dark}"
  [[ "$family" != "$1" ]] || family="${1%-light}"
  printf '%s\n' "$family"
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
  local new_theme="${1:-}"
  if [ -z "$new_theme" ]; then
    # A picker needs someone to pick. Under DOTFILES_NONINTERACTIVE the
    # selector cannot run, and ui_pick reports "nothing selected" the same
    # way it reports a cancel — so answering with a silent success would
    # make a forgotten argument indistinguishable from a theme change.
    if [ "${DOTFILES_NONINTERACTIVE:-0}" = "1" ]; then
      ui_err "Missing theme name" "no interactive picker in a non-interactive session"
      ui_info "Usage" "dot theme set <name>  (or 'dot theme list' to see them)"
      return 1
    fi
    pick_theme
    return
  fi

  # A family name means "follow the system"; an explicit suffixed variant
  # remains a manual light/dark selection for scripts and power users.
  if ! theme_exists "$new_theme" && theme_exists "${new_theme}-dark" && theme_exists "${new_theme}-light"; then
    local family="$new_theme"
    new_theme="${family}-$(system_appearance_mode)"
    shift
    run_theme_sync "$new_theme" --auto "$@"
    return
  fi

  # Pass remaining args (e.g. --force, --full) straight through so the
  # sync backend can honour them.
  shift
  run_theme_sync "$new_theme" "$@"
}

# =============================================================================
# Main
# =============================================================================

# Subcommand implementations, by concern.
# shellcheck source-path=SCRIPTDIR source=switch/picker.sh
source "$SCRIPT_DIR/switch/picker.sh"
# shellcheck source-path=SCRIPTDIR source=switch/ambient.sh
source "$SCRIPT_DIR/switch/ambient.sh"
# shellcheck source-path=SCRIPTDIR source=switch/history.sh
source "$SCRIPT_DIR/switch/history.sh"
# shellcheck source-path=SCRIPTDIR source=switch/desktop.sh
source "$SCRIPT_DIR/switch/desktop.sh"

# One-line subcommands; the rest live in the switch/ modules.
_theme_cmd_list() { list_themes; }
_theme_cmd_toggle() { toggle_theme; }
_theme_cmd_sync() { sync_theme "${2:-}"; }
_theme_cmd_family() { switch_family; }
_theme_cmd_current() { show_current; }
_theme_cmd_rebuild() {
  shift
  bash "$SCRIPT_DIR/rebuild-themes.sh" "$@"
}

# _theme_quick_switch <name>: a known variant or a paired family name
# switches directly; anything else is an unknown command.
_theme_quick_switch() {
  if grep -q "^\[themes\.${1}\]" "$THEMES_FILE" 2>/dev/null; then
    run_theme_sync "$1"
  elif theme_exists "${1}-dark" && theme_exists "${1}-light"; then
    set_theme "$1"
  else
    ui_err "Unknown command or theme" "$1"
    ui_info "Usage" "dot theme [list|set <name>|toggle|family|current|help]"
    exit 1
  fi
}

# Every subcommand is _theme_cmd_<name>, called with the full argument list
# (the subcommand is still $1, as each expects).
_THEME_COMMANDS="list set toggle mode rotate sync ambient family current plan undo history reset diff export import fit wallpaper accent status rebuild preview random help"

_theme_main() {
  local cmd="${1:-}"
  case "$cmd" in
    "")
      pick_theme
      return
      ;;
    --help | -h) cmd="help" ;;
  esac
  if [[ "$cmd" =~ ^[a-z]+$ && " $_THEME_COMMANDS " == *" $cmd "* ]]; then
    "_theme_cmd_$cmd" "$@"
  else
    _theme_quick_switch "$@"
  fi
}

_theme_main "$@"
