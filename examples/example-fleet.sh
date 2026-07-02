#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: Fleet management (multi-machine dotfiles operations)
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- dot fleet commands (observe & operate across machines) ---
printf 'Fleet cockpit dashboard:          dot fleet cockpit\n'
printf 'Show configuration drift:         dot fleet drift\n'
printf 'Recent fleet events:              dot fleet events\n'
printf 'List / select a namespace:        dot fleet namespace\n'
printf 'Inspect a node:                   dot fleet node <name>\n'

# --- Underlying fleet command (repo source of truth) ---
printf 'Fleet command:  %s\n' "$repo_root/scripts/dot/commands/fleet.sh"

# Fleet reads per-node state and reports drift versus the declarative
# chezmoi source, so a whole workstation fleet stays converged.
printf 'Fleet example complete.\n'
