#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Symbol-coverage report for the dot theme subsystem.
#
# For every function defined in bin/dot-theme-sync and every subcommand
# case in scripts/theme/switch.sh, check whether at least one file under
# tests/{unit,regression,integration}/ mentions it. Missing hits become
# the coverage gap.
#
# Emits:
#   * Human-readable table (default)
#   * Machine-readable JSON (--json)
#   * `MIN_COVERAGE=95` env var: exit 1 if % below threshold

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

DOT_THEME_SYNC="$REPO_ROOT/bin/dot-theme-sync"
SWITCH_SH="$REPO_ROOT/scripts/theme/switch.sh"
TESTS_ROOT="$REPO_ROOT/tests"

_json=false
if [[ "${1:-}" == "--json" ]]; then
  _json=true
fi

MIN_COVERAGE="${MIN_COVERAGE:-90}"

# ---------------------------------------------------------------------------
# 1. Enumerate targets to check.
# ---------------------------------------------------------------------------

# All shell functions in dot-theme-sync — public + private (leading _).
mapfile -t sync_functions < <(
  grep -oE '^[a-zA-Z_][a-zA-Z0-9_]*\(\)' "$DOT_THEME_SYNC" |
    sed 's/()$//' | sort -u
)

# All subcommand cases in switch.sh (the strings inside the top-level case).
# We just enumerate the canonical subcommand list here — the docs-sync
# test already asserts every one of these has a case entry, so we're
# not double-checking that.
switch_subcommands=(
  list set toggle mode family random preview undo history current
  status diff accent wallpaper fit export import sync ambient rotate
  reset rebuild help
)

# ---------------------------------------------------------------------------
# 2. Search test corpus for each target.
# ---------------------------------------------------------------------------

_covered_by_tests() {
  local symbol="$1"
  # Anchor the search so 'set' doesn't match 'reset', etc.
  # We look for either function invocation, subcommand string usage, or
  # commit-message style reference.
  grep -rqE "\\b${symbol}\\b" "$TESTS_ROOT"/{unit,regression,integration} 2>/dev/null
}

sync_hits=()
sync_misses=()
for fn in "${sync_functions[@]}"; do
  if _covered_by_tests "$fn"; then
    sync_hits+=("$fn")
  else
    sync_misses+=("$fn")
  fi
done

switch_hits=()
switch_misses=()
for sub in "${switch_subcommands[@]}"; do
  if _covered_by_tests "$sub"; then
    switch_hits+=("$sub")
  else
    switch_misses+=("$sub")
  fi
done

sync_total=${#sync_functions[@]}
sync_hit=${#sync_hits[@]}
switch_total=${#switch_subcommands[@]}
switch_hit=${#switch_hits[@]}

total=$((sync_total + switch_total))
hit=$((sync_hit + switch_hit))
percent=$(( hit * 100 / total ))

# ---------------------------------------------------------------------------
# 3. Emit.
# ---------------------------------------------------------------------------

if [[ "$_json" == true ]]; then
  # Simple hand-rolled JSON; no jq dependency required.
  printf '{\n'
  printf '  "coverage_pct": %d,\n' "$percent"
  printf '  "sync_functions": {\n'
  printf '    "total": %d,\n' "$sync_total"
  printf '    "covered": %d,\n' "$sync_hit"
  if (( ${#sync_misses[@]} > 0 )); then
    printf '    "missing": [%s]\n' \
      "$(printf '"%s",' "${sync_misses[@]}" | sed 's/,$//')"
  else
    printf '    "missing": []\n'
  fi
  printf '  },\n'
  printf '  "switch_subcommands": {\n'
  printf '    "total": %d,\n' "$switch_total"
  printf '    "covered": %d,\n' "$switch_hit"
  if (( ${#switch_misses[@]} > 0 )); then
    printf '    "missing": [%s]\n' \
      "$(printf '"%s",' "${switch_misses[@]}" | sed 's/,$//')"
  else
    printf '    "missing": []\n'
  fi
  printf '  },\n'
  printf '  "threshold": %d,\n' "$MIN_COVERAGE"
  printf '  "meets_threshold": %s\n' "$(if (( percent >= MIN_COVERAGE )); then echo true; else echo false; fi)"
  printf '}\n'
else
  printf '\e[1;36m=== dot theme symbol coverage ===\e[0m\n\n'
  printf '  dot-theme-sync functions: \e[32m%d\e[0m / %d\n' "$sync_hit" "$sync_total"
  if (( ${#sync_misses[@]} > 0 )); then
    printf '    Missing:\n'
    printf '      \e[33m-\e[0m %s\n' "${sync_misses[@]}"
  fi
  echo ""
  printf '  switch.sh subcommands:    \e[32m%d\e[0m / %d\n' "$switch_hit" "$switch_total"
  if (( ${#switch_misses[@]} > 0 )); then
    printf '    Missing:\n'
    printf '      \e[33m-\e[0m %s\n' "${switch_misses[@]}"
  fi
  echo ""
  printf '  Total coverage:           \e[1;32m%d%%\e[0m (%d / %d symbols)\n' \
    "$percent" "$hit" "$total"
  printf '  Threshold:                %d%%\n' "$MIN_COVERAGE"
fi

# Fail the run if below threshold.
if (( percent < MIN_COVERAGE )); then
  echo ""
  printf '\e[31mFAIL: coverage %d%% is below threshold %d%%\e[0m\n' \
    "$percent" "$MIN_COVERAGE"
  exit 1
fi
