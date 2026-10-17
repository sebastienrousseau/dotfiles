#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# AI Steering Patterns Management.
# Usage: dot patterns [list|view|edit] [name]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"

PATTERN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ai/patterns"
mkdir -p "$PATTERN_DIR"

command="${1:-list}"
name="${2:-}"

_view_pattern() {
  local pat_name="$1" pattern_file
  if [[ -z "$pat_name" ]]; then
    ui_err "Missing pattern name" "Usage: dot patterns view <name>"
    exit 1
  fi
  pattern_file="$PATTERN_DIR/${pat_name}.md"
  if [[ ! -f "$pattern_file" ]]; then
    ui_err "Pattern not found" "$pat_name"
    exit 1
  fi
  ui_header "Pattern: $pat_name"
  if has_command glow && glow --version >/dev/null 2>&1; then
    glow "$pattern_file"
  else
    cat "$pattern_file"
  fi
}

case "$command" in
  list)
    ui_header "AI Steering Patterns"
    ls -1 "$PATTERN_DIR" | sed 's/\.md$//' | while read -r p; do
      ui_bullet "$p"
    done
    ;;
  view)
    _view_pattern "$name"
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
