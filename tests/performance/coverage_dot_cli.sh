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
# 1. Enumerate top-level dot commands. Sources:
#   a. scripts/dot/commands/*.sh — each module's case labels
#   b. bin/dot-* executables — first-class dispatcher entries
#   c. bin/dot's own top-level case (agents / init / registry / ...)
# ---------------------------------------------------------------------------
commands=()

# (a) Case labels inside every command-module file.
while IFS= read -r label; do
  # Split alternates on |, strip whitespace, drop wildcard / flag-like.
  IFS='|' read -ra parts <<< "$label"
  for p in "${parts[@]}"; do
    p="${p## }"; p="${p%% }"
    [[ -z "$p" || "$p" == "*" || "$p" == "\"\"" || "$p" =~ ^- ]] && continue
    commands+=("$p")
  done
done < <(grep -h "^  [a-z][a-zA-Z0-9_-]*[)|]" \
           "$REPO_ROOT/scripts/dot/commands"/*.sh 2>/dev/null |
         sed -E 's/^  ([^)]+)\).*/\1/')

# (b) bin/dot-<name> executables.
while IFS= read -r f; do
  base="${f##*/}"
  commands+=("${base#dot-}")
done < <(find "$REPO_ROOT/bin" -maxdepth 1 -name 'dot-*' -type f)

# (c) bin/dot's own top-level cases (route-mode dispatch).
while IFS= read -r line; do
  IFS='|' read -ra parts <<< "$line"
  for p in "${parts[@]}"; do
    p="${p## }"; p="${p%% }"
    [[ -z "$p" || "$p" == "*" || "$p" =~ ^- ]] && continue
    commands+=("$p")
  done
done < <(sed -n '/^case "\$route" in/,/^esac/p' "$DOT_BIN" |
         grep -E "^  [a-z][a-zA-Z0-9_ |-]+\)" |
         sed -E 's/^  ([^)]+)\).*/\1/')

# Dedupe + drop known non-commands.
mapfile -t commands < <(
  printf '%s\n' "${commands[@]}" |
    grep -Ev '^(help|\*|"")$' |
    sort -u |
    grep -v '^$'
)

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
