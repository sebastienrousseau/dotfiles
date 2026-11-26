#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Drill A1, the newcomer: on a fresh machine, run every command of the
# README's Install and Quick Start blocks, in order and as written, then
# `dot doctor --json`. Passes when that reports no failures and the whole
# drill took at most DRILL_BUDGET seconds (default 1200: the full toolchain
# took about 14 minutes on Ubuntu 24.04, 4 CPUs, in November 2026). Nothing
# is added that the README does not show: no environment variable, no extra
# step.
#
#   tools/ci/drill-newcomer.sh            # run the drill (changes $HOME)
#   tools/ci/drill-newcomer.sh --print    # print the commands it would run
#   tools/ci/drill-newcomer.sh --judge ELAPSED <report.json   # the verdict
#
# Run it only on a disposable machine (a CI runner): the README's
# installer applies the dotfiles to $HOME.
set -euo pipefail

README="${DRILL_README:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/README.md}"
BUDGET="${DRILL_BUDGET:-1200}"

# readme_block HEADING: the first ```bash block under `## HEADING`.
readme_block() {
  awk -v heading="## $1" '
    $0 == heading { in_section = 1; next }
    in_section && /^## / { exit }
    in_section && !in_block && /^```bash[[:space:]]*$/ { in_block = 1; next }
    in_block && /^```[[:space:]]*$/ { exit }
    in_block { print }
  ' "$README"
}

drill_script() {
  local install quick
  install="$(readme_block Install)"
  quick="$(readme_block "Quick Start")"
  if [[ -z "$install" || -z "$quick" ]]; then
    echo "drill: README has no bash block under Install or Quick Start" >&2
    return 1
  fi
  printf '%s\n%s\n' "$install" "$quick"
}

# judge ELAPSED: read `dot doctor --json` on stdin; pass (exit 0) when it
# reports no failures and ELAPSED is within the budget.
judge() {
  local elapsed="$1" report failures
  report="$(cat)"
  failures="$(printf '%s' "$report" | python3 -c 'import json,sys; print(json.load(sys.stdin)["failures"])')"
  echo "drill: dot doctor --json reports $failures failure(s); ${elapsed}s of a ${BUDGET}s budget"
  if [[ "$failures" != "0" ]]; then
    printf '%s' "$report" | python3 -c 'import json,sys
for r in json.load(sys.stdin).get("results", []):
    if str(r.get("status", "")).lower() in ("fail", "failed", "error"):
        print("  failed:", r.get("check") or r.get("name") or r)'
    return 1
  fi
  if ((elapsed > BUDGET)); then
    echo "drill: over the ${BUDGET}s budget" >&2
    return 1
  fi
  echo "drill: passed"
}

case "${1:-}" in
  --print)
    drill_script
    exit
    ;;
  --judge)
    judge "${2:?usage: drill-newcomer.sh --judge ELAPSED <report.json}"
    exit
    ;;
esac

script="$(drill_script)"
echo "drill: running the README's Install and Quick Start blocks:"
printf '%s\n' "$script" | sed 's/^/  | /'
start=$SECONDS
# One shell, as a reader pasting both blocks into one terminal would use:
# Install's $installer_dir and Quick Start's PATH carry over.
bash -e -c "$script" </dev/null
report="$(PATH="$HOME/.local/bin:$PATH" dot doctor --json)"
printf '%s' "$report" | judge "$((SECONDS - start))"
