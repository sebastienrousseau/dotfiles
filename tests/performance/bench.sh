#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Dotfiles Startup Benchmark (The 50ms Rule)
# Measures shell initialization latency using hyperfine.

set -euo pipefail

THRESHOLD_MS=15

if ! command -v hyperfine >/dev/null 2>&1; then
  echo "hyperfine not found."
  exit 1
fi

FAILED=0

run_bench() {
  local shell_cmd=$1
  local label=$2

  local result
  result=$(hyperfine -i --warmup 3 --runs 10 "$shell_cmd" --export-json /tmp/bench.json >/dev/null 2>&1 &&
    jq -r '.results[0].mean * 1000' /tmp/bench.json)

  local mean_ms
  mean_ms=$(printf "%.0f" "$result")

  if [[ $mean_ms -le $THRESHOLD_MS ]]; then
    printf '  \033[38;5;42m✓\033[0m %-12s %dms\n' "$label" "$mean_ms"
  else
    printf '  \033[38;5;196m✗\033[0m %-12s %dms (> %dms)\n' "$label" "$mean_ms" "$THRESHOLD_MS"
    FAILED=1
  fi
}

if command -v zsh >/dev/null 2>&1; then
  run_bench "zsh -i -c exit" "zsh"
fi

if command -v fish >/dev/null 2>&1; then
  run_bench "fish -c exit" "fish"
fi

if command -v bash >/dev/null 2>&1; then
  run_bench "bash -i -c exit" "bash"
fi

if [[ $FAILED -eq 0 ]]; then
  exit 0
else
  exit 1
fi
