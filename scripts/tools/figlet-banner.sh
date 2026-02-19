#!/usr/bin/env bash
set -euo pipefail

text="${*:-${USER:-dotfiles}}"
font="${DOTFILES_FIGLET_FONT:-slant}"

if command -v figlet >/dev/null; then
  figlet -f "$font" "$text"
  exit 0
fi

if command -v toilet >/dev/null; then
  toilet -f "$font" "$text"
  exit 0
fi

echo "$text"
