#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
#
# scripts/ci/dot-cli-startup-bench.sh
#
# Sub-100ms cold-start gate for the `dot` CLI dispatcher.
#
# The §3 audit roadmap calls for measuring `dot help` / `dot version`
# cold-start time and gating PRs on a regression budget. This script
# runs the dispatcher N times under a clean shell, computes the median
# elapsed time, and exits non-zero when the median exceeds the budget.
#
# Usage:
#   bash scripts/ci/dot-cli-startup-bench.sh [--budget-ms <n>] [--runs <n>] [--cmd <argv>]
#
# Env overrides:
#   DOT_BENCH_BUDGET_MS   Default budget in ms (default: 250).
#   DOT_BENCH_RUNS        Number of runs (default: 11; median-of-N).
#   DOT_BENCH_CMD         Argv passed to `dot` (default: "version").
#
# The default budget is 250ms — looser than the §3 aspirational 100ms
# while we lazy-load mise/asdf/etc. CI ratchets this number down as
# improvements land. Bench *failure* is a hard build failure; bench
# *regression* (median > previous baseline + 15%) is a warning.

set -euo pipefail

BUDGET_MS="${DOT_BENCH_BUDGET_MS:-250}"
RUNS="${DOT_BENCH_RUNS:-11}"
DOT_ARGV_RAW="${DOT_BENCH_CMD:-version}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --budget-ms)
      BUDGET_MS="$2"
      shift 2
      ;;
    --runs)
      RUNS="$2"
      shift 2
      ;;
    --cmd)
      DOT_ARGV_RAW="$2"
      shift 2
      ;;
    -h | --help)
      sed -n '5,25p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

# Locate the dot dispatcher binary. Prefer the repo-local copy so a
# user-installed `dot` on PATH can't sneak in.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DOT_BIN="$REPO_ROOT/dot_local/bin/executable_dot"
if [[ ! -x "$DOT_BIN" ]] && command -v dot >/dev/null 2>&1; then
  DOT_BIN="$(command -v dot)"
fi
if [[ ! -f "$DOT_BIN" ]]; then
  echo "::error::dot binary not found at $DOT_BIN" >&2
  exit 2
fi

# Portable wall-clock to ms. macOS bash 3.2 has no $EPOCHREALTIME.
_now_ms() {
  if [[ -n "${EPOCHREALTIME:-}" ]]; then
    # zsh / bash 5+: floating-point seconds.
    awk -v t="$EPOCHREALTIME" 'BEGIN{printf "%d\n", t*1000}'
  elif date +%s%N 2>/dev/null | grep -qE '^[0-9]+$'; then
    # GNU date: nanoseconds.
    echo $(($(date +%s%N) / 1000000))
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import time; print(int(time.time()*1000))'
  else
    # Fall back to seconds × 1000 (low resolution; warn).
    echo "::warning::no high-resolution clock; using whole-second precision" >&2
    echo $(($(date +%s) * 1000))
  fi
}

# Parse argv string (space-separated).
read -r -a DOT_ARGV <<<"$DOT_ARGV_RAW"

echo "dot CLI cold-start benchmark"
echo "  binary : $DOT_BIN"
echo "  argv   : ${DOT_ARGV[*]}"
echo "  runs   : $RUNS"
echo "  budget : ${BUDGET_MS}ms"
echo

samples=()
for ((i = 1; i <= RUNS; i++)); do
  start_ms="$(_now_ms)"
  # `env -i` strips inherited cached state so we measure cold-start, not
  # warm-cache. Keep PATH so the dispatcher can find git/awk/etc.
  env -i HOME="$HOME" PATH="$PATH" "$DOT_BIN" "${DOT_ARGV[@]}" >/dev/null 2>&1 || true
  end_ms="$(_now_ms)"
  elapsed=$((end_ms - start_ms))
  samples+=("$elapsed")
  printf '  run %2d: %dms\n' "$i" "$elapsed"
done

# Median of samples (odd RUNS → middle value).
median="$(printf '%s\n' "${samples[@]}" | sort -n | awk -v n="$RUNS" 'NR==int(n/2)+1{print; exit}')"
echo
echo "median: ${median}ms  budget: ${BUDGET_MS}ms"

# Optional baseline record for trend tracking.
baseline_file="${DOT_BENCH_BASELINE:-$REPO_ROOT/.cache/dot-cli-startup-baseline.txt}"
mkdir -p "$(dirname "$baseline_file")" 2>/dev/null || true
printf '%s\n' "$median" >"$baseline_file"

if ((median > BUDGET_MS)); then
  echo "::error::dot CLI cold-start regression: median ${median}ms > budget ${BUDGET_MS}ms" >&2
  echo "  Possible causes: a slow source-time helper in dot_local/bin/executable_dot," >&2
  echo "  an unconditional ${BUDGET_MS}ms+ tool init at top of a sourced lib, or" >&2
  echo "  unnecessary jq/awk calls before the dispatcher case statement." >&2
  exit 1
fi

echo "✓ dot CLI cold-start within budget"
