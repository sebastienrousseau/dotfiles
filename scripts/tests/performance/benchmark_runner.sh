#!/usr/bin/env bash
# shellcheck disable=SC1090,SC2015,SC2034,SC2155
set -euo pipefail

# Performance benchmark runner for shell functions
# Measures execution time and memory usage

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$(dirname "$SCRIPT_DIR")")")"

# Results storage for regression tracking
RESULTS_DIR="${RESULTS_DIR:-$HOME/.local/share/dotfiles/benchmarks}"
RESULTS_FILE="$RESULTS_DIR/benchmark_$(date +%Y%m%d_%H%M%S).json"

# Thresholds (in milliseconds)
# Note: CI environments may be slower, so thresholds are set conservatively
SHELL_STARTUP_THRESHOLD_MS=500
FUNCTION_LOAD_THRESHOLD_MS=200 # Increased for CI compatibility
CD_OPERATION_THRESHOLD_MS=50

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
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

benchmark_shell_startup() {
  echo "Benchmarking shell startup time..."
  local total=0
  local iterations=5

  for ((i = 1; i <= iterations; i++)); do
    local time_ms
    time_ms=$(measure_time_ms "zsh -i -c 'exit' 2>/dev/null || bash -i -c 'exit'")
    total=$((total + time_ms))
  done

  local avg=$((total / iterations))
  local status

  if [[ $avg -gt $SHELL_STARTUP_THRESHOLD_MS ]]; then
    status="FAIL"
    echo -e "${RED}✗ FAIL${NC}: Shell startup ${avg}ms exceeds threshold ${SHELL_STARTUP_THRESHOLD_MS}ms"
    store_result "shell_startup" "$avg" "$SHELL_STARTUP_THRESHOLD_MS" "$status"
    return 1
  else
    status="PASS"
    echo -e "${GREEN}✓ PASS${NC}: Shell startup ${avg}ms (threshold: ${SHELL_STARTUP_THRESHOLD_MS}ms)"
    store_result "shell_startup" "$avg" "$SHELL_STARTUP_THRESHOLD_MS" "$status"
    return 0
  fi
}

benchmark_function_sourcing() {
  echo "Benchmarking function file sourcing..."
  local failures=0

  for func_file in "$REPO_ROOT"/.chezmoitemplates/functions/*.sh; do
    [[ -f "$func_file" ]] || continue
    local name=$(basename "$func_file")
    local time_ms
    time_ms=$(measure_time_ms "source '$func_file'")

    if [[ $time_ms -gt $FUNCTION_LOAD_THRESHOLD_MS ]]; then
      echo -e "${YELLOW}⚠ WARN${NC}: $name took ${time_ms}ms to source"
      ((failures++))
    fi
  done

  if [[ $failures -eq 0 ]]; then
    echo -e "${GREEN}✓ PASS${NC}: All functions load within threshold"
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

  echo "Memory increase after loading functions: ${diff_mb}MB (${diff_kb}KB)"

  # Fail if memory usage exceeds 50MB
  if [[ $diff_mb -gt 50 ]]; then
    status="FAIL"
    echo -e "${RED}✗ FAIL${NC}: Memory usage ${diff_mb}MB exceeds 50MB threshold"
    store_result "memory_usage_kb" "$diff_kb" "51200" "$status"
    return 1
  else
    status="PASS"
    echo -e "${GREEN}✓ PASS${NC}: Memory usage within acceptable limits"
    store_result "memory_usage_kb" "$diff_kb" "51200" "$status"
    return 0
  fi
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
}

main() {
  generate_report
}

main "$@"
