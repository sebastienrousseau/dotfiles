#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: Theme & wallpaper engine
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- dot theme commands (cross-shell; wallpaper-driven) ---
printf 'List available themes:            dot theme list\n'
printf 'Switch to a named theme:          dot theme tokyonight-night\n'
printf 'Toggle light/dark:                dot theme toggle\n'
printf 'Rebuild generated theme assets:   dot theme rebuild\n'
printf 'Set the desktop wallpaper:        dot wallpaper ~/Pictures/wall.jpg\n'

# --- Underlying theme scripts (repo source of truth) ---
printf 'Theme switch engine:  %s\n' "$repo_root/scripts/theme/switch.sh"
printf 'Rebuild themes:       %s\n' "$repo_root/scripts/theme/rebuild-themes.sh"
printf 'Merge wallpaper:      %s\n' "$repo_root/scripts/theme/merge-wallpaper.sh"
printf 'GNOME theme apply:    %s\n' "$repo_root/scripts/theme/apply-gnome-theme.sh"
printf 'Extract HEIC frames:  %s\n' "$repo_root/scripts/theme/extract-heic-frames.sh"

# The active theme is declared in .chezmoidata.toml:
printf 'Theme source of truth: %s (key: theme = "...")\n' "$repo_root/.chezmoidata.toml"

printf 'Theme example complete.\n'
