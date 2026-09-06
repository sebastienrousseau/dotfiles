#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Regenerate docs/manual/command-index.md from `dot help all`.
# Solves the perennial drift between the live CLI surface and
# the manual's index — flagged in R1/R2/R3/R4 audits.
#
# Usage:
#   tools/docs/generate-command-index.sh           # write
#   tools/docs/generate-command-index.sh --check   # exit 1 if stale
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

dot_bin="bin/dot"
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

Generated from `dot help all` plus the `dot help <command>` detail
registry, so a command that is routable and has help text is listed
even when it is absent from the compact overview. To refresh after
adding or renaming a subcommand, run
`tools/docs/generate-command-index.sh`. The CI job
`lint/command-index` fails when this file is stale.

| Command | Summary |
|---------|---------|
EOF

# ── Source 1: the compact overview (`dot help all`). ────────────────────────
# Extract every "  •  NAME  DESC" line, one row per entry.
overview_rows() {
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
    '
}

# ── Source 2: routable commands documented only in the detail registry. ─────
# `dot help <cmd>` resolves its summary from _dot_help_details() first and
# falls back to _dot_help_specs(). Commands present only in the detail table
# therefore answer `dot help <cmd>` but never appear in `dot help all` — and
# so used to be missing from this index even though they are fully routable
# and documented (init, health, security-score, heal, manual, …). Read the
# two static registries straight out of bin/dot: no extra subprocess per
# command, and the same parse the help-registry symmetry regression test uses.
detail_only_rows() {
  awk '
    /^_dot_command_routes\(\)/  { in_routes  = 1; next }
    /^_dot_help_details\(\)/    { in_details = 1; next }
    in_routes  && /^EOF$/ { in_routes  = 0; next }
    in_details && /^EOF$/ { in_details = 0; next }

    # Route table lines are "<command>|<module>"; keep the command.
    in_routes && /^[a-z][a-z0-9-]*\|[a-z]+$/ {
      split($0, r, "|")
      routed[r[1]] = 1
      next
    }

    # Detail lines are "<command>|<summary>|<examples>".
    in_details {
      n = split($0, d, "|")
      if (n >= 2 && d[1] ~ /^[a-z][a-z0-9-]*$/ && d[2] != "") {
        summary[d[1]] = d[2]
      }
      next
    }

    END {
      for (cmd in summary) {
        if (!(cmd in routed)) continue   # phantom entry — not our concern here
        desc = summary[cmd]
        gsub(/\|/, "\\|", desc)
        printf "%s\t%s\n", cmd, desc
      }
    }
  ' "$dot_bin"
}

# Merge both sources. The overview is authoritative: it emits SEVERAL rows per
# command (one per subcommand — `dot fleet`, `dot fleet drift`, …), so its rows
# are never deduplicated against each other. A detail row is appended only for
# a command the overview does not mention at all; otherwise the two registries'
# different wording of the same command would yield a duplicate row.
overview_tmp="$(mktemp)"
trap 'rm -f "$tmp" "$overview_tmp"' EXIT
overview_rows >"$overview_tmp"

{
  cat "$overview_tmp"
  # `NR == FNR` loads the overview's command names, then the second stream is
  # filtered against them.
  detail_only_rows |
    awk -F'\t' 'NR == FNR { seen[$1] = 1; next } !($1 in seen)' \
      "$overview_tmp" -
} |
  LC_ALL=C sort -u |
  awk -F'\t' '{ printf "| `dot %s` | %s |\n", $1, $2 }' \
    >>"$tmp"

rm -f "$overview_tmp"
trap 'rm -f "$tmp"' EXIT

if [[ "$mode" == "check" ]]; then
  if ! diff -q "$target" "$tmp" >/dev/null 2>&1; then
    echo "command-index.md is stale. Run tools/docs/generate-command-index.sh to refresh." >&2
    diff -u "$target" "$tmp" | head -40 >&2
    exit 1
  fi
  echo "command-index.md is in sync"
  exit 0
fi

mv "$tmp" "$target"
trap - EXIT
echo "Wrote $target ($(grep -c '^| \`dot' "$target") commands)"
