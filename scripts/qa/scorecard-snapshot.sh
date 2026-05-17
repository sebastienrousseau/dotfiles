#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
#
# Fetch the current OpenSSF Scorecard result and refresh the
# per-check posture table in docs/security/SCORECARD.md.
#
# The narrative sections (open findings, exceptions, closed-this-
# cycle log) are preserved as-is — only the auto-generated
# baseline block between the BEGIN/END markers is rewritten.
#
# Usage:
#   scripts/qa/scorecard-snapshot.sh           # refresh
#   scripts/qa/scorecard-snapshot.sh --check   # exit 1 if stale
#
# Exit codes:
#   0  snapshot up-to-date / written
#   1  --check mode and content drifted
#   2  bad usage / Scorecard API unreachable

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

api='https://api.scorecard.dev/projects/github.com/sebastienrousseau/dotfiles'
target='docs/security/SCORECARD.md'

[[ -f "$target" ]] || {
  echo "target not found: $target" >&2
  exit 2
}

if ! command -v jq >/dev/null 2>&1; then
  echo "jq required" >&2
  exit 2
fi

payload="$(curl -sSfL "$api")" || {
  echo "Scorecard API unreachable: $api" >&2
  exit 2
}

aggregate="$(printf '%s' "$payload" | jq -r '.score')"
date="$(printf '%s' "$payload" | jq -r '.date')"

# Build the auto-block: per-check status + score, one row each.
block="$(mktemp)"
trap 'rm -f "$block"' EXIT

{
  printf '<!-- BEGIN scorecard-snapshot (auto-generated, do not edit by hand) -->\n'
  printf 'Aggregate score **%s / 10** at %s.\n\n' "$aggregate" "$date"
  printf '| Check | Score | Reason |\n'
  printf '|---|---:|---|\n'
  printf '%s' "$payload" |
    jq -r '.checks
        | sort_by(.name)
        | .[]
        | [.name, (.score|tostring), ((.reason // "") | gsub("\\|"; "\\|") | .[0:100])]
        | "| " + (. | join(" | ")) + " |"'
  # shellcheck disable=SC2016 # backticks here are markdown code-spans, not subshells
  printf '\n_Refresh: `scripts/qa/scorecard-snapshot.sh` · CI check: `lint/scorecard-snapshot` (planned)._\n'
  printf '<!-- END scorecard-snapshot -->\n'
} >"$block"

# Splice the block into the target. Find the BEGIN/END markers; if
# they're not yet present, append the block after the "## Live
# score" section header.
out="$(mktemp)"
trap 'rm -f "$block" "$out"' EXIT

if grep -q '<!-- BEGIN scorecard-snapshot' "$target"; then
  awk -v blockfile="$block" '
    BEGIN { skip = 0 }
    /<!-- BEGIN scorecard-snapshot/ {
      skip = 1
      while ((getline line < blockfile) > 0) print line
      close(blockfile)
      next
    }
    /<!-- END scorecard-snapshot -->/ {
      skip = 0
      next
    }
    skip == 0 { print }
  ' "$target" >"$out"
else
  # First run — inject right after the "## Live score" h2.
  awk -v blockfile="$block" '
    { print }
    /^## Live score$/ && !inserted {
      print ""
      while ((getline line < blockfile) > 0) print line
      close(blockfile)
      inserted = 1
    }
  ' "$target" >"$out"
fi

if [[ "$mode" == "check" ]]; then
  if ! diff -q "$target" "$out" >/dev/null 2>&1; then
    echo "SCORECARD.md snapshot is stale (live score: $aggregate)." >&2
    diff -u "$target" "$out" | head -50 >&2
    exit 1
  fi
  echo "SCORECARD.md snapshot is in sync (aggregate: $aggregate)"
  exit 0
fi

mv "$out" "$target"
trap - EXIT
echo "Refreshed $target (aggregate: $aggregate as of $date)"
