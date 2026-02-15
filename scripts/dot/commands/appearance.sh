#!/usr/bin/env bash
# Dotfiles CLI - Appearance Commands
# theme, wallpaper, fonts, tune

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"
# shellcheck source=../lib/ui.sh
source "$SCRIPT_DIR/../lib/ui.sh"

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
      ui_logo_dot "Dot Tune • Appearance"
      exec bash "$src_dir/scripts/tuning/macos.sh" "$@"
      ;;
    Linux)
      ui_logo_dot "Dot Tune • Appearance"
      exec bash "$src_dir/scripts/tuning/linux.sh" "$@"
      ;;
    *)
      ui_logo_dot "Dot Tune • Appearance"
      ui_error "OS tuning not supported on this platform."
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
    ui_error "Unknown appearance command: ${1:-}"
    exit 1
    ;;
esac
