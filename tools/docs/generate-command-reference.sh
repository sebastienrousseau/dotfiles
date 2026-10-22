#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Regenerate examples/command-reference.txt from lib/dot/data/commands.txt
# (generated from the plugin manifests): one line per built command, by
# domain as in `dot help all`, then the shortcuts. Planned commands are left
# out. examples/example-command-reference.sh prints it, and
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

table="lib/dot/data/commands.txt"
target="examples/command-reference.txt"
[[ -r "$table" ]] || {
  echo "command table not found: $table" >&2
  exit 2
}

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Records: dom|name|default|route|summary, cmd|spelling|route|effect|summary
# (an empty route is planned), alias|name|kind|target|until.
awk -F'|' '
  $1 == "dom" { order[++n] = $2; about[$2] = $5 }
  $1 == "cmd" && $3 != "" {
    split($2, w, " ")
    lines[w[1]] = lines[w[1]] sprintf("  dot %s — %s\n", $2, $5)
  }
  $1 == "alias" && $3 == "shortcut" { short = short sprintf("  dot %s — short for dot %s\n", $2, $4) }
  END {
    print "dot — one command for this machine. Built commands, by domain:"
    for (i = 1; i <= n; i++) {
      d = order[i]
      if (lines[d] != "") printf "\n[%s] %s\n%s", d, about[d], lines[d]
    }
    printf "\n[shortcuts]\n%s", short
  }
' "$table" >"$tmp"

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
