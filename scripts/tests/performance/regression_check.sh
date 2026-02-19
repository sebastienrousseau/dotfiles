#!/usr/bin/env bash
# shellcheck disable=SC2012
set -euo pipefail

# Compare current benchmark with historical baseline
RESULTS_DIR="${RESULTS_DIR:-$HOME/.local/share/dotfiles/benchmarks}"
BASELINE_FILE="$RESULTS_DIR/baseline.json"
REGRESSION_THRESHOLD=20 # Percentage increase to flag as regression

check_regression() {
  local metric="$1" current="$2"

  if [[ ! -f "$BASELINE_FILE" ]]; then
    echo "No baseline found. Creating baseline..."
    return 0
  fi

  local baseline
  baseline=$(jq -r "select(.metric == \"$metric\") | .value" "$BASELINE_FILE" | tail -1)

  if [[ -n "$baseline" && "$baseline" != "null" ]]; then
    local pct_change=$(((current - baseline) * 100 / baseline))
    if [[ $pct_change -gt $REGRESSION_THRESHOLD ]]; then
      echo "REGRESSION: $metric increased by ${pct_change}% (baseline: ${baseline}ms, current: ${current}ms)"
      return 1
    fi
    echo "OK: $metric within threshold (baseline: ${baseline}, current: ${current}, change: ${pct_change}%)"
  fi
  return 0
}

main() {
  echo "Checking for performance regressions..."
  echo ""

  # Find latest results file
  local latest
  latest=$(ls -t "$RESULTS_DIR"/benchmark_*.json 2>/dev/null | head -1 || true)

  if [[ -z "$latest" ]]; then
    echo "No benchmark results found. Run benchmark_runner.sh first."
    exit 0
  fi

  echo "Comparing against baseline: $BASELINE_FILE"
  echo "Latest results: $latest"
  echo ""

  local regressions=0

  # Check each metric in the latest results
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local metric value
    metric=$(echo "$line" | jq -r '.metric')
    value=$(echo "$line" | jq -r '.value')

    if ! check_regression "$metric" "$value"; then
      ((regressions++))
    fi
  done <"$latest"

  echo ""
  if [[ $regressions -gt 0 ]]; then
    echo "Found $regressions regression(s)!"
    exit 1
  else
    echo "No regressions detected."
    exit 0
  fi
}

main "$@"
