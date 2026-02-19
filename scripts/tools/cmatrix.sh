#!/usr/bin/env bash
set -euo pipefail

if ! command -v cmatrix >/dev/null; then
  echo "cmatrix not installed. Install it via brew/apt." >&2
  exit 1
fi

color="${DOTFILES_CMATRIX_COLOR:-green}"
opts=("-b" "-C" "$color")

if [[ "${DOTFILES_CMATRIX_RAINBOW:-0}" = "1" ]]; then
  opts+=("-r")
fi

if [[ "${DOTFILES_CMATRIX_ASYNC:-0}" = "1" ]]; then
  opts+=("-a")
fi

exec cmatrix "${opts[@]}" "$@"
