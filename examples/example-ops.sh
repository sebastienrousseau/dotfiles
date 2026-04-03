#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: Operations and maintenance scripts
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'Chezmoi apply: %s\n' "$repo_root/scripts/ops/chezmoi-apply.sh"
printf 'Chezmoi diff: %s\n' "$repo_root/scripts/ops/chezmoi-diff.sh"
printf 'Chezmoi update: %s\n' "$repo_root/scripts/ops/chezmoi-update.sh"
printf 'Chezmoi remove: %s\n' "$repo_root/scripts/ops/chezmoi-remove.sh"
printf 'Prewarm: %s\n' "$repo_root/scripts/ops/prewarm.sh"
printf 'Heal: %s\n' "$repo_root/scripts/ops/heal.sh"
printf 'Heal tools: %s\n' "$repo_root/scripts/ops/heal-tools.sh"
printf 'Heal system: %s\n' "$repo_root/scripts/ops/heal-system.sh"
printf 'Heal chezmoi: %s\n' "$repo_root/scripts/ops/heal-chezmoi.sh"
printf 'Rollback: %s\n' "$repo_root/scripts/ops/rollback.sh"
printf 'Bundle: %s\n' "$repo_root/scripts/ops/bundle.sh"
printf 'Post-apply repair: %s\n' "$repo_root/scripts/ops/post-apply-repair.sh"
printf 'AI setup: %s\n' "$repo_root/scripts/ops/ai-setup.sh"
printf 'Setup: %s\n' "$repo_root/scripts/ops/setup.sh"
printf 'Release: %s\n' "$repo_root/scripts/ops/release.sh"
printf 'Teleport: %s\n' "$repo_root/scripts/ops/teleport.sh"
printf 'Chaos: %s\n' "$repo_root/scripts/ops/chaos.sh"

# Validate all ops scripts have valid syntax
for script in "$repo_root"/scripts/ops/*.sh; do
  bash -n "$script" || { printf 'FAIL: %s\n' "$script" >&2; exit 1; }
done
printf 'All %d ops scripts pass syntax check.\n' "$(find "$repo_root/scripts/ops" -name "*.sh" | wc -l | tr -d ' ')"
