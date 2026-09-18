#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Cross-CLI symbol coverage report. For every top-level `dot <cmd>` in
# bin/dot, count whether at least one file under tests/ mentions it by
# name. Missing = untested at any level.
#
# Emits:
#   * Colour table (default)
#   * JSON (--json)
#   * Fails when below MIN_COVERAGE (env, default 80).
#
# Usage:
#   bash tests/performance/coverage_dot_cli.sh
#   bash tests/performance/coverage_dot_cli.sh --json
#   MIN_COVERAGE=90 bash tests/performance/coverage_dot_cli.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
TESTS_ROOT="$REPO_ROOT/tests"
DOT_BIN="$REPO_ROOT/bin/dot"

_json=false
[[ "${1:-}" == "--json" ]] && _json=true
MIN_COVERAGE="${MIN_COVERAGE:-80}"

# ---------------------------------------------------------------------------
# 1. Enumerate top-level dot commands via the shared authoritative
# extractor. Reads bin/dot's _dot_command_routes() heredoc plus
# bin/dot-* executables. Same source as tests/unit/commands/
# test_cli_docs_sync.sh so both reports agree on the denominator.
# ---------------------------------------------------------------------------
# shellcheck source=../framework/docs_sync_helpers.sh
source "$REPO_ROOT/tests/framework/docs_sync_helpers.sh"
mapfile -t commands < <(_docs_extract_top_level_commands "$REPO_ROOT" | grep -v '^help$')

# ---------------------------------------------------------------------------
# 2. Search test corpus.
# ---------------------------------------------------------------------------
_reference_count() {
  local sym="$1"
  # Anchor so `set` doesn't match `reset`, `sync` doesn't match `syncthing`.
  grep -rlE "\\b${sym}\\b" "$TESTS_ROOT"/{unit,regression,integration} 2>/dev/null | wc -l
}

declare -A depth=()
hits=()
misses=()
shallow=()  # commands with only 1 test file mention — candidates for deeper coverage
for cmd in "${commands[@]}"; do
  count=$(_reference_count "$cmd")
  depth[$cmd]=$count
  if (( count == 0 )); then
    misses+=("$cmd")
  else
    hits+=("$cmd")
    (( count == 1 )) && shallow+=("$cmd")
  fi
done

total=${#commands[@]}
hit=${#hits[@]}
percent=$(( total > 0 ? hit * 100 / total : 100 ))

# ---------------------------------------------------------------------------
# 3. Emit.
# ---------------------------------------------------------------------------
if [[ "$_json" == true ]]; then
  printf '{\n'
  printf '  "coverage_pct": %d,\n' "$percent"
  printf '  "total": %d,\n' "$total"
  printf '  "covered": %d,\n' "$hit"
  if (( ${#misses[@]} > 0 )); then
    printf '  "missing": [%s],\n' \
      "$(printf '"%s",' "${misses[@]}" | sed 's/,$//')"
  else
    printf '  "missing": [],\n'
  fi
  printf '  "threshold": %d,\n' "$MIN_COVERAGE"
  printf '  "meets_threshold": %s\n' "$(if (( percent >= MIN_COVERAGE )); then echo true; else echo false; fi)"
  printf '}\n'
else
  printf '\e[1;36m=== dot CLI command coverage ===\e[0m\n\n'
  printf '  Commands covered: \e[32m%d\e[0m / %d (\e[1;32m%d%%\e[0m)\n' \
    "$hit" "$total" "$percent"
  if (( ${#misses[@]} > 0 )); then
    printf '\n  Untested commands:\n'
    for m in "${misses[@]}"; do
      printf '    \e[33m-\e[0m %s\n' "$m"
    done
  fi
  if (( ${#shallow[@]} > 0 )); then
    printf '\n  Shallowly-tested commands (1 test file mention only):\n'
    for s in "${shallow[@]}"; do
      printf '    \e[36m~\e[0m %s\n' "$s"
    done
  fi
  printf '\n  Threshold: %d%%\n' "$MIN_COVERAGE"
fi

if (( percent < MIN_COVERAGE )); then
  echo ""
  printf '\e[31mFAIL: coverage %d%% is below threshold %d%%\e[0m\n' \
    "$percent" "$MIN_COVERAGE"
  exit 1
fi
