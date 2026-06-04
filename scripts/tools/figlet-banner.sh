#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
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
