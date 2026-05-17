#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
#
# Regenerate docs/manual/command-index.md from `dot help all`.
# Solves the perennial drift between the live CLI surface and
# the manual's index — flagged in R1/R2/R3/R4 audits.
#
# Usage:
#   scripts/docs/generate-command-index.sh           # write
#   scripts/docs/generate-command-index.sh --check   # exit 1 if stale
#
# Exit codes:
#   0  index written / already in sync
#   1  --check mode and drift detected
#   2  bad usage / can't reach dot CLI

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

mode="write"
for arg in "$@"; do
  case "$arg" in
    --check) mode="check" ;;
    -h | --help)
      sed -n '2,16p' "$0"
      exit 0
      ;;
    *)
      echo "unknown flag: $arg" >&2
      exit 2
      ;;
  esac
done

target="docs/manual/command-index.md"
[[ -f "$target" ]] || {
  echo "target not found: $target" >&2
  exit 2
}

dot_bin="dot_local/bin/executable_dot"
[[ -x "$dot_bin" ]] || {
  echo "dot CLI not found at $dot_bin" >&2
  exit 2
}

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# Header preserved verbatim from the existing file.
cat >"$tmp" <<'EOF'
---
render_with_liquid: false
---

# Command Index

Generated from `dot help all`. To refresh after adding or renaming
a subcommand, run `scripts/docs/generate-command-index.sh`. The CI
job `lint/command-index` fails when this file is stale.

| Command | Summary |
|---------|---------|
EOF

# Extract every "  •  NAME  DESC" line from `dot help all`, sort
# alphabetically by NAME, and render as a markdown table row.
bash "$dot_bin" help all 2>/dev/null |
  awk '
    /^  •  [a-z]/ {
      # Strip the leading "  •  " bullet and any trailing whitespace
      sub(/^  •  +/, "")
      # Split into command (first whitespace-delimited token) and the rest
      cmd  = $1
      desc = ""
      if (NF > 1) {
        $1 = ""
        desc = $0
        sub(/^ +/, "", desc)
      }
      # Escape pipe characters in desc to avoid breaking the markdown table
      gsub(/\|/, "\\|", desc)
      printf "%s\t%s\n", cmd, desc
    }
  ' |
  sort -u |
  awk -F'\t' '{ printf "| `dot %s` | %s |\n", $1, $2 }' \
    >>"$tmp"

if [[ "$mode" == "check" ]]; then
  if ! diff -q "$target" "$tmp" >/dev/null 2>&1; then
    echo "command-index.md is stale. Run scripts/docs/generate-command-index.sh to refresh." >&2
    diff -u "$target" "$tmp" | head -40 >&2
    exit 1
  fi
  echo "command-index.md is in sync"
  exit 0
fi

mv "$tmp" "$target"
trap - EXIT
echo "Wrote $target ($(grep -c '^| \`dot' "$target") commands)"
