#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: the `dot ai` fleet — command surface, steering styles, gateway.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

printf 'The dot ai command surface:\n'
cat <<'SURFACE'
  dot ai                      open the cockpit (Bubble Tea TUI)
  dot ai "fix the bug"        one-shot on Claude
  dot ai codex "add tests"    one-shot on a named tool
  dot ai chat [tool]          interactive session
  dot ai tools                install / manage the fleet
  dot ai install [all|<tool>] install fleet tools
  dot ai serve [stop|status]  local Claude gateway (start also routes the fleet)
  dot ai cost                 spend report
  dot ai login [tool]         authenticate
  dot ai doctor               health-check fleet + gateway
SURFACE

printf '\nAI identity: %s\n' "$repo_root/dot_config/ai/identity.md"
printf '\nSteering styles (use with --style <name>):\n'
for pattern in "$repo_root"/dot_config/ai/patterns/*.md; do
  [[ -f "$pattern" ]] || continue
  name="$(basename "$pattern" .md)"
  printf '  %-14s %s\n' "$name" "$pattern"
done

printf '\nLocal Claude gateway (dot ai serve):\n'
printf '  Serves your Claude subscription over the Anthropic (/v1/messages)\n'
printf '  and OpenAI (/v1/chat/completions) protocols at http://127.0.0.1:3456.\n'

# Verify the AI command modules parse.
for f in \
  "scripts/dot/commands/ai.sh" \
  "lib/dot/ai-commands.sh" \
  "lib/dot/ai-install.sh" \
  "scripts/ops/ai-setup.sh"; do
  bash -n "$repo_root/$f" || {
    printf 'FAIL: %s\n' "$f" >&2
    exit 1
  }
done
printf '\nAI scripts pass syntax check.\n'
