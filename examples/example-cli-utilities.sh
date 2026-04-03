#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: CLI utility scripts deployed to ~/.local/bin
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Verify all executable scripts have valid syntax
count=0
for script in "$repo_root"/dot_local/bin/executable_*; do
  [[ -d "$script" ]] && continue
  # Skip non-shell files
  head -1 "$script" | grep -q 'bash\|sh' || continue
  bash -n "$script" || { printf 'FAIL: %s\n' "$script" >&2; exit 1; }
  count=$((count + 1))
done
printf 'All %d CLI utilities pass syntax check.\n' "$count"

# List key utilities with descriptions
printf '\nKey CLI utilities:\n'
printf '  dot           — Dotfiles management CLI\n'
printf '  dot-ai        — AI RAG query tool\n'
printf '  ai_core       — AI operations wrapper\n'
printf '  ai-update     — AI tools updater\n'
printf '  git-ai-commit — AI commit message generator\n'
printf '  git-ai-diff   — AI code review\n'
printf '  tour          — Interactive dotfiles tour\n'
printf '  extract       — Universal archive extractor\n'
printf '  kill-port     — Kill process on port\n'
printf '  myip          — Show public IP\n'
printf '  uuid          — Generate UUID\n'
printf '  pw            — Password generator\n'
printf '  epoch         — Epoch timestamp converter\n'
printf '  b64           — Base64 encode/decode\n'
printf '  hex           — Hex encode/decode\n'
printf '  hash          — File hash calculator\n'
printf '  jsonv         — JSON validator\n'
printf '  yamlv         — YAML validator\n'
printf '  regex         — Regex tester\n'
printf '  lorem         — Lorem ipsum generator\n'
printf '  up            — Directory traversal helper\n'
