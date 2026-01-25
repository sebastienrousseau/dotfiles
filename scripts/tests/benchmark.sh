#!/usr/bin/env bash

# standard-benchmarks.sh
# Measures shell startup time. Optional threshold enforcement via DOTFILES_BENCH_MAX_MS.

set -euo pipefail

log_info() { echo -e "\n[INFO] $*"; }

MAX_MS="${DOTFILES_BENCH_MAX_MS:-}"

# Check for hyperfine (preferred) or fall back to simplified loop
if command -v hyperfine >/dev/null; then
  log_info "Running benchmark with hyperfine..."
  tmp_json="$(mktemp)"
  hyperfine --warmup 3 --min-runs 10 --export-json "$tmp_json" "zsh -i -c exit"

  if [[ -n "$MAX_MS" ]] && command -v python3 >/dev/null; then
    python3 - "$tmp_json" "$MAX_MS" <<'PY'
import json, sys
path, max_ms = sys.argv[1], float(sys.argv[2])
with open(path, "r", encoding="utf-8") as f:
    data = json.load(f)
mean_s = data["results"][0]["mean"]
mean_ms = mean_s * 1000.0
print(f"[INFO] Mean startup: {mean_ms:.1f} ms (limit: {max_ms:.1f} ms)")
if mean_ms > max_ms:
    print(f"[FAIL] Startup time exceeded limit: {mean_ms:.1f} ms > {max_ms:.1f} ms")
    sys.exit(1)
PY
  fi
  rm -f "$tmp_json"
else
  log_info "Hyperfine not found. Using simple loop..."
  echo "Running 10 iterations of 'zsh -i -c exit'..."
  for _ in {1..10}; do
    time zsh -i -c exit
  done
fi
