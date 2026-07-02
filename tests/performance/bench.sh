#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles Startup Benchmark
# Measures REAL interactive shell initialization latency using hyperfine.
#
# Honesty: every shell is timed as an INTERACTIVE session (the flag a real
# terminal uses), because non-interactive startup skips the rc entirely and
# wildly understates the truth (e.g. `fish -c exit` reports ~12ms while
# `fish -i -c exit` is ~130ms). `-N` runs the target shell directly with no
# intermediate wrapper shell. The <30ms aspirational target and the phased
# plan to reach it are tracked in docs/operations/ARCHITECTURE_ROADMAP.md;
# the thresholds below are REGRESSION gates (current measured + headroom),
# not the aspiration.

set -euo pipefail

# Regression thresholds (ms). Measured 2026-07 medians: zsh ~66, bash ~51,
# fish ~129, nu ~25 — thresholds sit above those with headroom for noise.
THRESHOLD_MS_BASH=75
THRESHOLD_MS_ZSH=90
THRESHOLD_MS_FISH=200
THRESHOLD_MS_NU=60

if ! command -v hyperfine >/dev/null 2>&1; then
  echo "hyperfine not found."
  exit 1
fi

FAILED=0

run_bench() {
  local shell_cmd=$1
  local label=$2
  local threshold=$3

  local result
  local bench_json
  bench_json=$(umask 077 && mktemp)
  result=$(hyperfine -N -i --warmup 3 --runs 10 "$shell_cmd" --export-json "$bench_json" >/dev/null 2>&1 &&
    jq -r '.results[0].mean * 1000' "$bench_json")
  rm -f "$bench_json"

  local mean_ms
  mean_ms=$(printf "%.0f" "$result")

  if [[ $mean_ms -le $threshold ]]; then
    printf '  \033[38;5;42m✓\033[0m %-12s %dms\n' "$label" "$mean_ms"
  else
    printf '  \033[38;5;196m✗\033[0m %-12s %dms (> %dms)\n' "$label" "$mean_ms" "$threshold"
    FAILED=1
  fi
}

if command -v zsh >/dev/null 2>&1; then
  run_bench "zsh -i -c exit" "zsh" "$THRESHOLD_MS_ZSH"
fi

if command -v fish >/dev/null 2>&1; then
  # -i so fish actually loads config.fish/conf.d (a fresh terminal is
  # interactive); `fish -c exit` skips all of it and is not representative.
  run_bench "fish -i -c exit" "fish" "$THRESHOLD_MS_FISH"
fi

if command -v bash >/dev/null 2>&1; then
  run_bench "bash -i -c exit" "bash" "$THRESHOLD_MS_BASH"
fi

if command -v nu >/dev/null 2>&1; then
  # nushell loads env.nu/config.nu on `-c`; there is no separate -i flag.
  run_bench "nu -c exit" "nu" "$THRESHOLD_MS_NU"
fi

if [[ $FAILED -eq 0 ]]; then
  exit 0
else
  exit 1
fi
