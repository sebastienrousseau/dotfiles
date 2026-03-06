#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# Dotfiles Startup Benchmark (The 50ms Rule)
# Measures shell initialization latency using hyperfine.

set -euo pipefail

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# Constraints
THRESHOLD_MS=50

# Ensure hyperfine is installed
if ! command -v hyperfine >/dev/null 2>&1; then
    echo "hyperfine not found. Please install it first."
    exit 1
fi

echo "--- 🏎️  Dotfiles Performance Audit ---"
echo "Target: Shell startup latency < ${THRESHOLD_MS}ms"
echo ""

FAILED=0

run_bench() {
    local shell_cmd=$1
    local label=$2

    echo "Testing $label..."

    # Run hyperfine and extract mean time in milliseconds
    # We use -i to ignore shell non-zero exit codes if any (often happens in CI)
    local result
    result=$(hyperfine -i --warmup 3 --runs 10 "$shell_cmd" --export-json /tmp/bench.json >/dev/null 2>&1 &&
             jq -r '.results[0].mean * 1000' /tmp/bench.json)

    # Format to integer for comparison
    local mean_ms
    mean_ms=$(printf "%.0f" "$result")

    if [[ $mean_ms -le $THRESHOLD_MS ]]; then
        printf "  ${GREEN}✓${NC} %-10s: %dms (Pass)
" "$label" "$mean_ms"
    else
        printf "  ${RED}✗${NC} %-10s: %dms (Fail - Exceeds %dms threshold)
" "$label" "$mean_ms" "$THRESHOLD_MS"
        FAILED=1
    fi
}

# Benchmark Zsh
if command -v zsh >/dev/null 2>&1; then
    run_bench "zsh -i -c exit" "Zsh"
fi

# Benchmark Fish
if command -v fish >/dev/null 2>&1; then
    run_bench "fish -c exit" "Fish"
fi

# Benchmark Bash
if command -v bash >/dev/null 2>&1; then
    run_bench "bash --norc -i -c exit" "Bash (Raw)"
    run_bench "bash -i -c exit" "Bash"
fi

echo ""
if [[ $FAILED -eq 0 ]]; then
    echo "✅ Performance audit passed!"
    exit 0
else
    echo "❌ Performance audit failed. Optimize shell initialization."
    exit 1
fi
