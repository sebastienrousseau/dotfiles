#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Example: Shell function library categories
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
funcs_dir="$repo_root/.chezmoitemplates/functions"

printf 'Function library: %s\n\n' "$funcs_dir"

# List categories and their functions
for category in "$funcs_dir"/*/; do
  [[ -d "$category" ]] || continue
  name="$(basename "$category")"
  count="$(find "$category" -name "*.sh" | wc -l | tr -d ' ')"
  printf '  %-14s %s functions\n' "$name/" "$count"
done

# Validate all function files have valid syntax
printf '\nSyntax validation:\n'
count=0
for script in "$funcs_dir"/**/*.sh; do
  [[ -f "$script" ]] || continue
  bash -n "$script" || { printf 'FAIL: %s\n' "$script" >&2; exit 1; }
  count=$((count + 1))
done
printf '  All %d function files pass syntax check.\n' "$count"
