#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: dot CLI command modules
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'Core commands: %s\n' "$repo_root/scripts/dot/commands/core.sh"
printf 'AI commands: %s\n' "$repo_root/scripts/dot/commands/ai.sh"
printf 'Agent commands: %s\n' "$repo_root/scripts/dot/commands/agent.sh"
printf 'Aliases commands: %s\n' "$repo_root/scripts/dot/commands/aliases.sh"
printf 'Appearance commands: %s\n' "$repo_root/scripts/dot/commands/appearance.sh"
printf 'Diagnostics commands: %s\n' "$repo_root/scripts/dot/commands/diagnostics.sh"
printf 'Fleet commands: %s\n' "$repo_root/scripts/dot/commands/fleet.sh"
printf 'Lint commands: %s\n' "$repo_root/scripts/dot/commands/lint.sh"
printf 'Meta commands: %s\n' "$repo_root/scripts/dot/commands/meta.sh"
printf 'Patterns commands: %s\n' "$repo_root/scripts/dot/commands/patterns.sh"
printf 'Restore commands: %s\n' "$repo_root/scripts/dot/commands/restore.sh"
printf 'Secrets commands: %s\n' "$repo_root/scripts/dot/commands/secrets.sh"
printf 'Security commands: %s\n' "$repo_root/scripts/dot/commands/security.sh"
printf 'Tools commands: %s\n' "$repo_root/scripts/dot/commands/tools.sh"

# Validate all command modules have valid syntax
for script in "$repo_root"/scripts/dot/commands/*.sh; do
  bash -n "$script" || { printf 'FAIL: %s\n' "$script" >&2; exit 1; }
done
printf 'All %d command modules pass syntax check.\n' "$(find "$repo_root/scripts/dot/commands" -name "*.sh" | wc -l | tr -d ' ')"
