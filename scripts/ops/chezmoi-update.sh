#!/usr/bin/env bash
set -euo pipefail

args=()
if [[ -n "${DOTFILES_CHEZMOI_UPDATE_FLAGS:-}" ]]; then
  # shellcheck disable=SC2206
  args+=(${DOTFILES_CHEZMOI_UPDATE_FLAGS})
fi

if [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" ]]; then
  args+=("--verbose")
fi

echo "Updating dotfiles..."
chezmoi update "${args[@]}"
