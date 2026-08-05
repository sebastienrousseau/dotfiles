#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Appearance Commands
# theme, wallpaper, fonts, tune

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"

dot_ui_command_banner "Appearance" "${1:-}"

usage() {
  cat <<'EOF'
Usage: appearance.sh <command> [args...]

Commands:
  theme, wallpaper, fonts, tune
EOF
}

cmd_theme() {
  run_script "scripts/theme/switch.sh" "Theme switcher" "$@"
}

cmd_wallpaper() {
  case "${1:-sync}" in
    sync)
      shift 2>/dev/null || true
      run_script "scripts/theme/wallpaper-sync.sh" "Wallpaper sync script" "$@"
      ;;
    rotate)
      shift
      run_script "scripts/theme/wallpaper-rotate.sh" "Wallpaper rotate script" "$@"
      ;;
    *)
      run_script "scripts/theme/wallpaper-sync.sh" "Wallpaper sync script" "$@"
      ;;
  esac
}

cmd_fonts() {
  local sub="${1:-install}"
  case "$sub" in
    patch)
      shift
      run_script "scripts/fonts/patch-fonts.sh" "Font patch helper" "$@"
      ;;
    install | "")
      [[ "$sub" == install ]] && shift || true
      run_script "scripts/fonts/install-nerd-fonts.sh" "Font install script" "$@"
      ;;
    *)
      run_script "scripts/fonts/install-nerd-fonts.sh" "Font install script" "$@"
      ;;
  esac
}

cmd_tune() {
  local src_dir
  local platform
  src_dir="$(require_source_dir)"
  platform="$(dot_platform_id)"

  case "$platform" in
    macos)
      exec bash "$src_dir/scripts/tuning/macos.sh" "$@"
      ;;
    linux | wsl)
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
  --help | -h | help)
    usage
    ;;
  "")
    usage
    exit 1
    ;;
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
