#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Appearance Commands
# tune (theme, wallpaper and fonts are plugins/theme/dot-theme)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"

dot_ui_command_banner "Appearance" "${1:-}"

usage() {
  cat <<'EOF'
Usage: appearance.sh <command> [args...]

Commands:
  tune
EOF
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
  tune)
    shift
    cmd_tune "$@"
    ;;
  *)
    echo "Unknown appearance command: ${1:-}" >&2
    exit 1
    ;;
esac
