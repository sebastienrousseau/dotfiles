#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# AI Steering Patterns Management.
# Usage: dot patterns [list|view|edit] [name]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_DIR/dot/lib/ui.sh"

PATTERN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ai/patterns"
mkdir -p "$PATTERN_DIR"

command="${1:-list}"
name="${2:-}"

case "$command" in
  list)
    ui_header "AI Steering Patterns"
    ls -1 "$PATTERN_DIR" | sed 's/\.md$//' | while read -r p; do
      ui_bullet "$p"
    done
    ;;
  view)
    if [[ -z "$name" ]]; then
      ui_err "Missing pattern name" "Usage: dot patterns view <name>"
      exit 1
    fi
    pattern_file="$PATTERN_DIR/${name}.md"
    if [[ -f "$pattern_file" ]]; then
      ui_header "Pattern: $name"
      if command -v glow >/dev/null 2>&1; then
        glow "$pattern_file"
      else
        cat "$pattern_file"
      fi
    else
      ui_err "Pattern not found" "$name"
    fi
    ;;
  edit)
    if [[ -z "$name" ]]; then
      ui_err "Missing pattern name" "Usage: dot patterns edit <name>"
      exit 1
    fi
    pattern_file="$PATTERN_DIR/${name}.md"
    ${EDITOR:-nvim} "$pattern_file"
    ;;
  *)
    echo "Usage: dot patterns [list|view|edit] [name]"
    exit 1
    ;;
esac
