#!/usr/bin/env bash

# Script: test-aliases.sh
# Description: Verifies disjoint alias files for syntax errors.

set -e

echo "Testing alias syntax..."

ALIAS_DIR="$HOME/.local/share/chezmoi/.chezmoitemplates/aliases"

find "$ALIAS_DIR" -name "*.aliases.sh" | while read -r file; do
  # Check for syntax errors using bash -n
  if bash -n "$file"; then
    echo "✅ Checked: $(basename "$file")"
  else
    echo "❌ Syntax Error: $(basename "$file")"
    exit 1
  fi
done

echo "All alias files passed syntax check."
