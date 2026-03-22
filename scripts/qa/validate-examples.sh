#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXAMPLES_DIR="$REPO_ROOT/examples"

if [ ! -d "$EXAMPLES_DIR" ]; then
  echo "No examples directory found: $EXAMPLES_DIR" >&2
  exit 1
fi

found=0
while IFS= read -r -d '' example; do
  found=1
  printf 'Running example: %s\n' "$(basename "$example")"
  bash "$example"
done < <(find "$EXAMPLES_DIR" -maxdepth 1 -type f -name "*.sh" -print0 | sort -z)

if [ "$found" -eq 0 ]; then
  echo "No executable examples found in $EXAMPLES_DIR" >&2
  exit 1
fi

printf 'Examples passed.\n'
