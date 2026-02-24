#!/usr/bin/env bash
# shellcheck disable=SC2034
# Regression detection for performance benchmarks
# Compares current results against baseline
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Results storage
RESULTS_DIR="${RESULTS_DIR:-$HOME/.local/share/dotfiles/benchmarks}"
BASELINE_FILE="$RESULTS_DIR/baseline.json"

# Regression threshold (percentage)
REGRESSION_THRESHOLD_PCT=10
SIGNIFICANT_IMPROVEMENT_PCT=5

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;34m'
NC='\033[0m'

echo "Performance Regression Detection"
echo "================================="
echo ""

usage() {
  cat <<EOF
Usage: $(basename "$0") [COMMAND]

Commands:
  baseline    Create baseline from recent benchmarks
  check       Compare current performance against baseline
  history     Show performance history
  clean       Remove old benchmark results

Options:
  -h, --help  Show this help
EOF
}

create_baseline() {
  echo "Creating performance baseline..."
  echo ""

  # Run all benchmark suites
  local benchmark_files=(
    "$SCRIPT_DIR/benchmark_runner.sh"
    "$SCRIPT_DIR/benchmark_components.sh"
    "$SCRIPT_DIR/benchmark_memory.sh"
    "$SCRIPT_DIR/benchmark_commands.sh"
  )

  local temp_baseline
  temp_baseline=$(mktemp)

  for bench_file in "${benchmark_files[@]}"; do
    if [[ -x "$bench_file" ]]; then
      echo "Running: $(basename "$bench_file")..."
      bash "$bench_file" 2>/dev/null || true
    fi
  done

  # Combine all results
  echo "[]" >"$temp_baseline"

  for result_file in "$RESULTS_DIR"/*.json; do
    [[ -f "$result_file" ]] || continue
    [[ "$result_file" == "$BASELINE_FILE" ]] && continue

    # Append to baseline
    while IFS= read -r line; do
      echo "$line" >>"$temp_baseline"
    done <"$result_file"
  done

  mv "$temp_baseline" "$BASELINE_FILE"

  echo ""
  echo "Baseline created: $BASELINE_FILE"
  echo "Total metrics: $(wc -l <"$BASELINE_FILE")"
}

check_regression() {
  if [[ ! -f "$BASELINE_FILE" ]]; then
    echo "${RED}Error:${NC} No baseline found. Run 'baseline' first."
    exit 1
  fi

  echo "Checking for performance regressions..."
  echo ""

  local regressions=0
  local improvements=0
  local unchanged=0

  # Run current benchmarks
  bash "$SCRIPT_DIR/benchmark_runner.sh" >/dev/null 2>&1 || true
  bash "$SCRIPT_DIR/benchmark_components.sh" >/dev/null 2>&1 || true

  # Find most recent results
  local latest_result
  latest_result=$(ls -t "$RESULTS_DIR"/*.json 2>/dev/null | grep -v baseline | head -1)

  if [[ -z "$latest_result" ]]; then
    echo "${YELLOW}Warning:${NC} No recent benchmark results found."
    return 1
  fi

  echo "Comparing against baseline..."
  echo ""

  printf "  %-30s %10s %10s %10s\n" "Metric" "Baseline" "Current" "Change"
  printf "  %-30s %10s %10s %10s\n" "------" "--------" "-------" "------"

  # Compare metrics
  while IFS= read -r current_line; do
    # Extract metric name and value
    local metric value_ms
    metric=$(echo "$current_line" | grep -o '"metric":"[^"]*"' | cut -d'"' -f4)
    [[ -z "$metric" ]] && metric=$(echo "$current_line" | grep -o '"component":"[^"]*"' | cut -d'"' -f4)
    [[ -z "$metric" ]] && metric=$(echo "$current_line" | grep -o '"command":"[^"]*"' | cut -d'"' -f4)

    value_ms=$(echo "$current_line" | grep -oE '"value(_ms)?":[0-9]+' | grep -oE '[0-9]+' | head -1)

    [[ -z "$metric" || -z "$value_ms" ]] && continue

    # Find baseline value
    local baseline_value
    baseline_value=$(grep "\"$metric\"" "$BASELINE_FILE" 2>/dev/null |
      grep -oE '"value(_ms)?":[0-9]+' | grep -oE '[0-9]+' | head -1)

    [[ -z "$baseline_value" ]] && continue

    # Calculate change
    local diff_pct
    if [[ $baseline_value -gt 0 ]]; then
      diff_pct=$(((value_ms - baseline_value) * 100 / baseline_value))
    else
      diff_pct=0
    fi

    # Determine status
    local status_color change_str
    if [[ $diff_pct -gt $REGRESSION_THRESHOLD_PCT ]]; then
      status_color="$RED"
      change_str="+${diff_pct}% ⚠"
      ((regressions++))
    elif [[ $diff_pct -lt -$SIGNIFICANT_IMPROVEMENT_PCT ]]; then
      status_color="$GREEN"
      change_str="${diff_pct}% ✓"
      ((improvements++))
    else
      status_color="$NC"
      change_str="${diff_pct}%"
      ((unchanged++))
    fi

    printf "  %-30s %10d %10d ${status_color}%10s${NC}\n" \
      "$metric" "$baseline_value" "$value_ms" "$change_str"

  done <"$latest_result"

  echo ""
  echo "Summary:"
  echo "  Regressions:   $regressions"
  echo "  Improvements:  $improvements"
  echo "  Unchanged:     $unchanged"

  if [[ $regressions -gt 0 ]]; then
    echo ""
    echo "${RED}⚠ Performance regressions detected!${NC}"
    return 1
  else
    echo ""
    echo "${GREEN}✓ No significant regressions${NC}"
    return 0
  fi
}

show_history() {
  echo "Performance History"
  echo "-------------------"
  echo ""

  if [[ ! -d "$RESULTS_DIR" ]]; then
    echo "No benchmark history found."
    return
  fi

  echo "Recent benchmark runs:"
  ls -lht "$RESULTS_DIR"/*.json 2>/dev/null | head -10

  echo ""
  echo "Shell startup time trend (last 10 runs):"

  for result_file in $(ls -t "$RESULTS_DIR"/*.json 2>/dev/null | head -10); do
    [[ -f "$result_file" ]] || continue
    local timestamp value
    timestamp=$(basename "$result_file" .json)
    value=$(grep "shell_startup" "$result_file" 2>/dev/null |
      grep -oE '"value(_ms)?":[0-9]+' | grep -oE '[0-9]+' | head -1)

    [[ -n "$value" ]] && printf "  %s: %dms\n" "$timestamp" "$value"
  done
}

clean_old_results() {
  echo "Cleaning old benchmark results..."

  # Keep last 30 days of results
  find "$RESULTS_DIR" -name "*.json" -type f -mtime +30 -delete 2>/dev/null || true

  echo "Done."
}

# Main
case "${1:-check}" in
  baseline)
    create_baseline
    ;;
  check)
    check_regression
    ;;
  history)
    show_history
    ;;
  clean)
    clean_old_results
    ;;
  -h | --help)
    usage
    ;;
  *)
    echo "Unknown command: $1"
    usage
    exit 1
    ;;
esac
