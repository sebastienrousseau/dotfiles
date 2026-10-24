#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Regenerate docs/manual/command-index.md from the command table
# (lib/dot/data/commands.txt, generated from the plugin manifests): every
# `dot <domain> [object] <verb>` with its summary, the shortcuts, and the
# old names with the release they stop working in. Keeps the manual's
# index in step with the CLI (ADR-020, N0.4).
#
# Usage:
#   tools/docs/generate-command-index.sh           # write
#   tools/docs/generate-command-index.sh --check   # exit 1 if stale
#
# Exit codes:
#   0  index written / already in sync
#   1  --check mode and drift detected
#   2  bad usage / table missing
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

target="docs/manual/command-index.md"
table="lib/dot/data/commands.txt"
case "${1:-}" in
  "" | --check) ;;
  -h | --help)
    sed -n '5,18p' "$0" | sed 's/^# \{0,1\}//'
    exit 0
    ;;
  *)
    echo "unknown flag: $1" >&2
    exit 2
    ;;
esac
[[ -r "$table" ]] || {
  echo "table not found: $table" >&2
  exit 2
}

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
{
  cat <<'HEAD'
---
render_with_liquid: false
---

# Command Index

Every `dot` command, generated from the plugin manifests through
`lib/dot/data/commands.txt` (ADR-020). A command marked *planned* is
declared but not built yet. To refresh after changing a manifest, run
`tools/docs/generate-command-index.sh`; the Doc Drift job fails when this
file is stale. `dot help <command>` shows one command and its flags.

| Command | Summary |
|---------|---------|
HEAD
  awk -F'|' '$1 == "cmd" { printf "| `dot %s` | %s%s |\n", $2, $5, ($3 == "" ? " *(planned)*" : "") }' "$table"
  printf '\n## Shortcuts\n\n| Shortcut | Runs |\n|----------|------|\n'
  awk -F'|' '$1 == "alias" && $3 == "shortcut" { printf "| `dot %s` | `dot %s` |\n", $2, $4 }' "$table"
  printf '\n## Old names\n\nEach one runs, and prints its new name, until the release shown; from that release it exits 127 with the new name.\n\n'
  printf '| Old name | New name | Until |\n|----------|----------|-------|\n'
  awk -F'|' '$1 == "alias" && $3 != "shortcut" { printf "| `dot %s` | `dot %s` | %s |\n", $2, $4, ($5 == "" ? "removed" : $5) }' "$table"
} >"$tmp"

if [[ "${1:-}" == --check ]]; then
  if ! cmp -s "$tmp" "$target"; then
    echo "$target is stale. Run tools/docs/generate-command-index.sh." >&2
    diff -u "$target" "$tmp" 2>/dev/null | head -20 >&2 || true
    exit 1
  fi
  echo "command-index.md is in sync"
  exit 0
fi
cp "$tmp" "$target"
echo "Wrote $target"
