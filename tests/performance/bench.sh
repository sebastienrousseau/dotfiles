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
# nu was briefly raised to 200 on 2026-08-20 on the theory that nushell itself
# had regressed to a 136ms floor. That was wrong: `nu` on PATH was a mise shim,
# so the measurement included the shim re-execing a 137MB mise binary. With
# mise's tool directories promoted above the shims, nu starts in 15ms — so the
# original 60ms gate was right all along, and is restored.
#
#     nu via mise shim                112ms
#     nu direct, with our config        15ms
#     nu direct, --no-config-file        7ms
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
  # Gate on the MINIMUM, not the mean.
  #
  # This is a regression gate for *our* init code, and the mean measures the
  # machine's spare capacity as much as the shell. Timed on 2026-08-20 while a
  # Rust build was running (load 6.08 on 6 cores), fish reported mean=428ms
  # against min=73ms — 5.9x apart, and a red gate for a config that had not
  # changed. zsh reported mean=129ms / min=82ms, failing its 90ms threshold on
  # the mean and passing on the min.
  #
  # The minimum of ten runs approximates the uncontended cost, which is the
  # thing a regression gate is actually asking about. It cannot mask a real
  # regression: work added to an rc file raises the floor too.
  result=$(hyperfine -N -i --warmup 3 --runs 10 "$shell_cmd" --export-json "$bench_json" >/dev/null 2>&1 &&
    jq -r '.results[0].min * 1000' "$bench_json")
  rm -f "$bench_json"

  local min_ms
  min_ms=$(printf "%.0f" "$result")

  if [[ $min_ms -le $threshold ]]; then
    printf '  \033[38;5;42m✓\033[0m %-12s %dms\n' "$label" "$min_ms"
  else
    printf '  \033[38;5;196m✗\033[0m %-12s %dms (> %dms)\n' "$label" "$min_ms" "$threshold"
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
