#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Regenerate examples/command-reference.txt from lib/dot/data/help-specs.txt:
# one usage line per public command and subcommand, grouped as in
# `dot help all`. examples/example-command-reference.sh prints it, and
# scripts/qa/examples-coverage.sh finds every command referenced there.
#
# Usage:
#   tools/docs/generate-command-reference.sh           # write
#   tools/docs/generate-command-reference.sh --check   # exit 1 if stale
#
# Exit codes:
#   0  reference written / already in sync
#   1  --check mode and drift detected
#   2  bad usage / registry missing

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

mode="write"
for arg in "$@"; do
  case "$arg" in
    --check) mode="check" ;;
    -h | --help)
      sed -n '2,17p' "$0"
      exit 0
      ;;
    *)
      echo "unknown flag: $arg" >&2
      exit 2
      ;;
  esac
done

specs="lib/dot/data/help-specs.txt"
target="examples/command-reference.txt"
[[ -r "$specs" ]] || {
  echo "registry not found: $specs" >&2
  exit 2
}

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Fields: group|name|summary|hint. A new group opens a "[Group]" heading.
awk -F'|' '
  BEGIN { print "dot — declarative dotfiles CLI. Public commands:"; print "" }
  $1 != group { printf "\n[%s]\n", $1; group = $1 }
  { printf "  dot %s — %s\n", $2, $3 }
' "$specs" >"$tmp"

if [[ "$mode" == "check" ]]; then
  if cmp -s "$tmp" "$target"; then
    echo "$(basename "$target") is in sync"
    exit 0
  fi
  echo "$target is stale; run tools/docs/generate-command-reference.sh" >&2
  diff -u "$target" "$tmp" >&2 || true
  exit 1
fi

cp "$tmp" "$target"
echo "wrote $target"
