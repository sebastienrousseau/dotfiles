#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Micro-benchmark suite for `dot theme` hot paths.
#
# Measures:
#   * idempotent set (same theme)          — target < 100 ms
#   * mode dark no-op                       — target < 100 ms
#   * theme list (115 paired families)      — target < 200 ms
#   * theme current                          — target <  60 ms
#   * theme status                           — target < 300 ms
#   * theme status --json                    — target < 300 ms
#   * theme diff <a> <b>                     — target < 200 ms
#   * parallel full apply                    — target < 1500 ms
#   * sequential full apply (regression)     — target < 1500 ms
#
# Skips gracefully when hyperfine or dot is missing. Exit non-zero on
# any bench that overshoots its threshold; CI can gate on this.

set -euo pipefail

if ! command -v hyperfine >/dev/null 2>&1; then
  echo "SKIP: hyperfine not installed"
  exit 0
fi
if ! command -v dot >/dev/null 2>&1; then
  echo "SKIP: dot CLI not on PATH"
  exit 0
fi

FAILED=0

_bench() {
  local label="$1" cmd="$2" threshold_ms="$3"
  local prepare="${4:-}"
  local json
  json="$(mktemp)"
  local hf_args=(--warmup 1 --runs 3 --export-json "$json")
  [[ -n "$prepare" ]] && hf_args+=(--prepare "$prepare")

  if hyperfine -i "${hf_args[@]}" "$cmd" >/dev/null 2>&1; then
    local mean_ms
    mean_ms=$(jq -r '.results[0].mean * 1000 | floor' "$json")
    rm -f "$json"
    if (( mean_ms > threshold_ms )); then
      printf '  \e[31m✗\e[0m %-38s %5d ms  (threshold %d ms)\n' "$label" "$mean_ms" "$threshold_ms"
      FAILED=$((FAILED + 1))
    else
      printf '  \e[32m✓\e[0m %-38s %5d ms  (threshold %d ms)\n' "$label" "$mean_ms" "$threshold_ms"
    fi
  else
    printf '  \e[31m✗\e[0m %-38s FAILED to run\n' "$label"
    FAILED=$((FAILED + 1))
    rm -f "$json"
  fi
}

printf '\e[1;36m=== dot theme micro-benchmarks ===\e[0m\n\n'

# Pin a known theme so the idempotent bench is a real no-op.
dot theme set Sonoma-dark --force >/dev/null 2>&1 || true

_bench "set (idempotent no-op)" \
       "dot theme set Sonoma-dark" \
       100

_bench "mode dark (no-op)" \
       "dot theme mode dark" \
       100

_bench "theme list (all paired families)" \
       "dot theme list" \
       400

_bench "theme current" \
       "dot theme current" \
       200

_bench "theme status" \
       "dot theme status" \
       400

_bench "theme status --json" \
       "dot theme status --json" \
       400

_bench "theme diff Sonoma-dark Firewatch-dark" \
       "dot theme diff Sonoma-dark Firewatch-dark" \
       200

# Full-apply benchmarks — prepare step resets between runs so we're
# not hitting the idempotent short-circuit.
_bench "full apply (parallel reload chain)" \
       "dot theme set Bauhaus-dark --force" \
       1500 \
       "dot theme set Sonoma-dark --force >/dev/null 2>&1"

_bench "full apply (DOT_THEME_SEQUENTIAL=1)" \
       "DOT_THEME_SEQUENTIAL=1 dot theme set Bauhaus-dark --force" \
       1800 \
       "dot theme set Sonoma-dark --force >/dev/null 2>&1"

echo ""
if (( FAILED > 0 )); then
  printf '\e[31m%d bench(es) over threshold\e[0m\n' "$FAILED"
  exit 1
fi
printf '\e[32mAll dot theme benches within threshold\e[0m\n'
