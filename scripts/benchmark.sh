#!/usr/bin/env bash

# standard-benchmarks.sh
# Measures shell startup time to ensure performance goals (<20ms) are met.

set -euo pipefail

log_info() { echo -e "\n[INFO] $*"; }

# Check for hyperfine (preferred) or fall back to simplified loop
if command -v hyperfine >/dev/null; then
  log_info "Running benchmark with hyperfine..."
  hyperfine --warmup 3 --min-runs 10 "zsh -i -c exit"
else
  log_info "Hyperfine not found. Using simple loop..."
  echo "Running 10 iterations of 'zsh -i -c exit'..."
  for _ in {1..10}; do
    time zsh -i -c exit
  done
fi
