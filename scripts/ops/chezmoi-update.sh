#!/usr/bin/env bash
set -euo pipefail

args=()
if [[ -n "${DOTFILES_CHEZMOI_UPDATE_FLAGS:-}" ]]; then
  # Safely parse space-separated flags into array
  read -ra flag_array <<<"$DOTFILES_CHEZMOI_UPDATE_FLAGS"
  args+=("${flag_array[@]}")
fi

if [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" ]]; then
  args+=("--verbose")
fi

echo "Updating dotfiles..."
chezmoi update "${args[@]}"
