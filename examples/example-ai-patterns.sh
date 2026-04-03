#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: AI steering patterns and identity configuration
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'AI identity: %s\n' "$repo_root/dot_config/ai/identity.md"
printf '\nSteering patterns:\n'
for pattern in "$repo_root"/dot_config/ai/patterns/*.md; do
  [[ -f "$pattern" ]] || continue
  name="$(basename "$pattern" .md)"
  printf '  %-14s %s\n' "$name" "$pattern"
done

# Verify AI command module syntax
bash -n "$repo_root/scripts/dot/commands/ai.sh" || { printf 'FAIL: ai.sh\n' >&2; exit 1; }
bash -n "$repo_root/scripts/ops/ai-setup.sh" || { printf 'FAIL: ai-setup.sh\n' >&2; exit 1; }
printf '\nAI scripts pass syntax check.\n'
