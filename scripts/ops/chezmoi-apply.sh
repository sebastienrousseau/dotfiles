#!/usr/bin/env bash
set -euo pipefail

args=()
if [[ -n "${DOTFILES_CHEZMOI_APPLY_FLAGS:-}" ]]; then
  # shellcheck disable=SC2206
  args+=( ${DOTFILES_CHEZMOI_APPLY_FLAGS} )
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
