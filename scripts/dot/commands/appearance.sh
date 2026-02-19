#!/usr/bin/env bash
# Dotfiles CLI - Appearance Commands
# theme, wallpaper, fonts, tune

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

ui_logo_once "Dot • Appearance"

cmd_theme() {
  run_script "scripts/theme/switch.sh" "Theme switcher" "$@"
}

cmd_wallpaper() {
  run_script "scripts/theme/wallpaper-sync.sh" "Wallpaper script" "$@"
}

cmd_fonts() {
  run_script "scripts/fonts/install-nerd-fonts.sh" "Font install script" "$@"
}

cmd_tune() {
  local src_dir
  src_dir="$(require_source_dir)"

  case "$(uname -s)" in
    Darwin)
      exec bash "$src_dir/scripts/tuning/macos.sh" "$@"
      ;;
    Linux)
      exec bash "$src_dir/scripts/tuning/linux.sh" "$@"
      ;;
    *)
      echo "OS tuning not supported on this platform."
      exit 1
      ;;
  esac
}

# Dispatch
case "${1:-}" in
  theme)
    shift
    cmd_theme "$@"
    ;;
  wallpaper)
    shift
    cmd_wallpaper "$@"
    ;;
  fonts)
    shift
    cmd_fonts "$@"
    ;;
  tune)
    shift
    cmd_tune "$@"
    ;;
  *)
    echo "Unknown appearance command: ${1:-}" >&2
    exit 1
    ;;
esac
