#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC2015,SC2034,SC2155
set -euo pipefail

# Performance benchmark runner for shell functions
# Measures execution time and memory usage per shell with baseline tracking

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# Results storage for regression tracking
RESULTS_DIR="${RESULTS_DIR:-$HOME/.local/share/dotfiles/benchmarks}"
RESULTS_FILE="$RESULTS_DIR/benchmark_$(date +%Y%m%d_%H%M%S).json"
BASELINE_FILE="$RESULTS_DIR/baseline.json"

# Thresholds (in milliseconds)
# CI environments may be slower, so thresholds are set conservatively
SHELL_STARTUP_THRESHOLD_MS="${DOTFILES_STARTUP_THRESHOLD:-500}"
FUNCTION_LOAD_THRESHOLD_MS=200
CD_OPERATION_THRESHOLD_MS=50

# Exit code tracking
BENCH_FAILURES=0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

# Store benchmark result in JSON format for regression tracking
store_result() {
  local metric="$1" value="$2" threshold="$3" status="$4"
  mkdir -p "$RESULTS_DIR"

  # Append to JSON results
  cat >>"$RESULTS_FILE" <<EOF
{"timestamp": "$(date -Iseconds)", "metric": "$metric", "value": $value, "threshold": $threshold, "status": "$status"}
EOF
}

measure_time_ms() {
  local start end
  # Use perl for portable millisecond timing (works on macOS and Linux)
  if command -v perl >/dev/null 2>&1; then
    start=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000')
    "$@" >/dev/null 2>&1 || true
    end=$(perl -MTime::HiRes=time -e 'printf "%.0f\n", time * 1000')
    echo $((end - start))
  else
    # Fallback: use seconds only (less precise but portable)
    start=$(date +%s)
    "$@" >/dev/null 2>&1 || true
    end=$(date +%s)
    echo $(((end - start) * 1000))
  fi
}

# Benchmark a single shell's startup time
benchmark_single_shell() {
  local shell_name="$1"
  local shell_cmd="$2"
  local threshold="${3:-$SHELL_STARTUP_THRESHOLD_MS}"

  if ! command -v "$shell_cmd" >/dev/null 2>&1; then
    printf '%b\n' "  ${YELLOW}⚠ SKIP${NC}: $shell_name not available"
    return 0
  fi

  local total=0
  local iterations=5

  for ((i = 1; i <= iterations; i++)); do
    local time_ms
    if [[ "$shell_cmd" == "fish" ]]; then
      time_ms=$(measure_time_ms fish -c 'exit')
    else
      time_ms=$(measure_time_ms "$shell_cmd" -i -c 'exit')
    fi
    total=$((total + time_ms))
  done

  local avg=$((total / iterations))
  local status

  if [[ $avg -gt $threshold ]]; then
    status="FAIL"
    printf '%b\n' "  ${RED}✗ FAIL${NC}: $shell_name startup ${avg}ms exceeds ${threshold}ms"
    store_result "${shell_name}_startup" "$avg" "$threshold" "$status"
    ((BENCH_FAILURES++))
  else
    status="PASS"
    printf '%b\n' "  ${GREEN}✓ PASS${NC}: $shell_name startup ${avg}ms (threshold: ${threshold}ms)"
    store_result "${shell_name}_startup" "$avg" "$threshold" "$status"
  fi
}

benchmark_shell_startup() {
  echo "Benchmarking per-shell startup time..."
  benchmark_single_shell "bash" "bash" "$SHELL_STARTUP_THRESHOLD_MS"
  benchmark_single_shell "zsh" "zsh" "$SHELL_STARTUP_THRESHOLD_MS"
  benchmark_single_shell "fish" "fish" "$SHELL_STARTUP_THRESHOLD_MS"
  if command -v nu >/dev/null 2>&1; then
    benchmark_single_shell "nushell" "nu" "$SHELL_STARTUP_THRESHOLD_MS"
  fi
}

benchmark_function_sourcing() {
  echo "Benchmarking function file sourcing..."
  local failures=0

  for func_file in "$REPO_ROOT"/.chezmoitemplates/functions/*.sh; do
    [[ -f "$func_file" ]] || continue
    local name
    name=$(basename "$func_file")
    local time_ms
    time_ms=$(measure_time_ms source "$func_file")

    if [[ $time_ms -gt $FUNCTION_LOAD_THRESHOLD_MS ]]; then
      printf '%b\n' "  ${YELLOW}⚠ WARN${NC}: $name took ${time_ms}ms to source"
      ((failures++))
    fi
  done

  if [[ $failures -eq 0 ]]; then
    printf '%b\n' "  ${GREEN}✓ PASS${NC}: All functions load within threshold"
  fi
}

benchmark_memory_usage() {
  echo "Benchmarking memory usage..."

  # Get baseline memory
  local baseline
  baseline=$(ps -o rss= -p $$ | tr -d ' ')

  # Source all functions
  for func_file in "$REPO_ROOT"/.chezmoitemplates/functions/*.sh; do
    [[ -f "$func_file" ]] && source "$func_file" 2>/dev/null || true
  done

  # Get memory after loading
  local after
  after=$(ps -o rss= -p $$ | tr -d ' ')

  local diff_kb=$((after - baseline))
  local diff_mb=$((diff_kb / 1024))
  local status

  echo "  Memory increase after loading functions: ${diff_mb}MB (${diff_kb}KB)"

  # Fail if memory usage exceeds 50MB
  if [[ $diff_mb -gt 50 ]]; then
    status="FAIL"
    printf '%b\n' "  ${RED}✗ FAIL${NC}: Memory usage ${diff_mb}MB exceeds 50MB threshold"
    store_result "memory_usage_kb" "$diff_kb" "51200" "$status"
    ((BENCH_FAILURES++))
  else
    status="PASS"
    printf '%b\n' "  ${GREEN}✓ PASS${NC}: Memory usage within acceptable limits"
    store_result "memory_usage_kb" "$diff_kb" "51200" "$status"
  fi
}

# Compare current results against baseline and flag regressions
check_regression() {
  if [[ ! -f "$BASELINE_FILE" ]]; then
    printf '%b\n' "\n${CYAN}ℹ INFO${NC}: No baseline file found. Saving current run as baseline."
    cp "$RESULTS_FILE" "$BASELINE_FILE"
    return 0
  fi

  echo ""
  echo "Checking for regressions against baseline..."
  local regression_threshold=20 # % increase to flag

  while IFS= read -r line; do
    local metric value
    metric=$(echo "$line" | grep -o '"metric": "[^"]*"' | cut -d'"' -f4)
    value=$(echo "$line" | grep -o '"value": [0-9]*' | cut -d' ' -f2)
    [[ -z "$metric" || -z "$value" ]] && continue

    # Find matching baseline
    local baseline_value
    baseline_value=$(grep "\"metric\": \"$metric\"" "$BASELINE_FILE" 2>/dev/null | tail -1 | grep -o '"value": [0-9]*' | cut -d' ' -f2 || echo "")
    [[ -z "$baseline_value" ]] && continue

    if [[ $baseline_value -gt 0 ]]; then
      local pct_change=$(((value - baseline_value) * 100 / baseline_value))
      if [[ $pct_change -gt $regression_threshold ]]; then
        printf '%b\n' "  ${RED}⚠ REGRESSION${NC}: $metric increased ${pct_change}% (${baseline_value}ms -> ${value}ms)"
        ((BENCH_FAILURES++))
      elif [[ $pct_change -lt -5 ]]; then
        printf '%b\n' "  ${GREEN}✓ IMPROVEMENT${NC}: $metric decreased ${pct_change#-}% (${baseline_value}ms -> ${value}ms)"
      fi
    fi
  done <"$RESULTS_FILE"
}

generate_report() {
  echo ""
  echo "╔═══════════════════════════════════════╗"
  echo "║     Performance Benchmark Report      ║"
  echo "╚═══════════════════════════════════════╝"
  echo ""

  benchmark_shell_startup
  echo ""
  benchmark_function_sourcing
  echo ""
  benchmark_memory_usage
  check_regression
}

main() {
  generate_report

  echo ""
  if [[ $BENCH_FAILURES -gt 0 ]]; then
    printf '%b\n' "${RED}BENCHMARK FAILED${NC}: $BENCH_FAILURES threshold(s) exceeded"
    exit 1
  else
    printf '%b\n' "${GREEN}ALL BENCHMARKS PASSED${NC}"
    exit 0
  fi
}

main "$@"
