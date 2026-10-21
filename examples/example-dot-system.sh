#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Example: dot system status and scheduled maintenance
#
# Show the host, then set, run and remove the maintenance schedule.
#
# Backing module: scripts/dot/commands/system.sh
# Feature matrix: docs/reference/FEATURE-MATRIX.md
#
# Runnable and side-effect free: HOME is redirected into a throwaway
# directory, and launchctl and systemctl are replaced by `true`, so `set`
# writes its agent or timer into the sandbox and loads nothing.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dot="$repo_root/bin/dot"

sandbox="$(mktemp -d -t dot-example.XXXXXX)"
trap 'rm -rf "$sandbox"' EXIT
mkdir -p "$sandbox/.config" "$sandbox/.local/share" "$sandbox/.local/state" "$sandbox/.cache"

export HOME="$sandbox" \
  XDG_CONFIG_HOME="$sandbox/.config" \
  XDG_DATA_HOME="$sandbox/.local/share" \
  XDG_STATE_HOME="$sandbox/.local/state" \
  XDG_CACHE_HOME="$sandbox/.cache" \
  DOT_LAUNCHCTL=true DOT_SYSTEMCTL=true \
  NO_COLOR=1 DOTFILES_SHOW_LOGO=0 DOTFILES_NO_TUI=1 DOTFILES_NONINTERACTIVE=1

printf '=== dot system ===\n\n'
bash "$dot" system status

printf '\n--- weekly maintenance ---\n\n'
bash "$dot" system schedule set weekly
bash "$dot" system schedule list
bash "$dot" system schedule run
bash "$dot" system status | grep 'Last run'
bash "$dot" system schedule set off

printf '\ndot system example complete.\n'
