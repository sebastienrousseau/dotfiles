#!/usr/bin/env bash
set -euo pipefail

args=()
if [[ -n "${DOTFILES_CHEZMOI_APPLY_FLAGS:-}" ]]; then
  # Safely parse space-separated flags into array
  read -ra flag_array <<<"$DOTFILES_CHEZMOI_APPLY_FLAGS"
  args+=("${flag_array[@]}")
fi

if [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" ]]; then
  args+=("--verbose")
fi

if [[ "${DOTFILES_CHEZMOI_KEEP_GOING:-0}" = "1" ]]; then
  args+=("--keep-going")
fi

echo "Applying dotfiles..."
chezmoi apply "${args[@]}"

if [[ "${DOTFILES_CHEZMOI_STATUS:-1}" = "1" ]]; then
  printf "\nStatus:\n"
  chezmoi status || true
fi
