#!/usr/bin/env bash
# MIT License
# Copyright (c) 2026 Sebastien Rousseau
# See LICENSE file for details.

# Script: test-aliases.sh
# Description: Verifies disjoint alias files for syntax errors.

set -euo pipefail

echo "Testing alias syntax..."

ALIAS_DIR="$HOME/.dotfiles/.chezmoitemplates/aliases"
fail=0

# Use process substitution so the while loop runs in the main shell,
# allowing the fail variable to propagate correctly.
while IFS= read -r file; do
  if bash -n "$file"; then
    echo " Checked: $(basename "$file")"
  else
    echo " Syntax Error: $(basename "$file")"
    fail=1
  fi
done < <(find "$ALIAS_DIR" -name "*.aliases.sh")

if [[ "$fail" -ne 0 ]]; then
  exit 1
fi

echo "All alias files passed syntax check."
