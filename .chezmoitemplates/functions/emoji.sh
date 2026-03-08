# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Emoji picker utility

emoji() {
  local src_dir="${DOTFILES_DIR:-$HOME/.dotfiles}"
  if [[ ! -d "$src_dir" ]]; then
    src_dir="$HOME/.local/share/chezmoi"
  fi
  local script="$src_dir/scripts/tools/emoji-picker.sh"
  if [[ -x "$script" ]]; then
    "$script" "$@"
  else
    echo "Emoji picker not found. Expected: $script" >&2
    return 1
  fi
}
