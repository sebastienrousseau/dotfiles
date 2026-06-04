#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for the percentile aggregator inside scripts/diagnostics/perf.sh.
#
# The aggregator reads $XDG_STATE_HOME/dotfiles/eval-timings.jsonl and
# reports count/total/mean/p50/p95/p99 per `_cached_eval` label. The
# test pins the math against known fixtures so a future refactor of
# the embedded Python doesn't quietly change semantics.
#
# Regression for: GH-863
# Why: drift in percentile math would silently break the "regression
# vs baseline" gate that depends on these numbers.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

PERF="$REPO_ROOT/scripts/diagnostics/perf.sh"

# -----------------------------------------------------------------------------
# Structural
# -----------------------------------------------------------------------------

test_start "perf_exists"
assert_file_exists "$PERF" "perf.sh should exist"

test_start "perf_supports_by_tool"
assert_file_contains "$PERF" -- "--by-tool" "perf.sh must accept --by-tool"

test_start "perf_supports_baseline"
assert_file_contains "$PERF" -- "--baseline" "perf.sh must accept --baseline"

test_start "perf_emits_percentiles"
# The Python aggregator must compute p50/p95/p99.
assert_file_contains "$PERF" "p50" "perf.sh aggregator must compute p50"
assert_file_contains "$PERF" "p95" "perf.sh aggregator must compute p95"
assert_file_contains "$PERF" "p99" "perf.sh aggregator must compute p99"

# -----------------------------------------------------------------------------
# Behavioural: feed a synthetic JSONL fixture through the aggregator
# and check the percentile output.
# -----------------------------------------------------------------------------

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

state_dir="$tmp/state/dotfiles"
mkdir -p "$state_dir"
log_file="$state_dir/eval-timings.jsonl"

# 100 samples for 'mise-init': 1..100. P50=50, P95=95, P99=99 (linear-interp default).
for i in $(seq 1 100); do
  printf '{"ts":"2026-05-13T00:00:00Z","shell":"zsh","label":"mise-init","ms":%d,"rc":0}\n' "$i" >> "$log_file"
done
# 10 samples for 'starship-init': all 42. P50=P95=P99=42.
for _ in $(seq 1 10); do
  printf '{"ts":"2026-05-13T00:00:00Z","shell":"zsh","label":"starship-init","ms":42,"rc":0}\n' >> "$log_file"
done

# Invoke the by-tool reader directly via XDG_STATE_HOME override.
# MISE_YES=1: perf.sh's aggregator runs `python3`, which is a mise shim once
# the toolchain is installed. Overriding XDG_STATE_HOME discards mise's trust
# cache, so the shim would otherwise abort on the untrusted repo mise.toml and
# swallow the percentile output. MISE_YES auto-trusts in this isolated env.
out=$(XDG_STATE_HOME="$tmp/state" MISE_YES=1 bash "$PERF" --by-tool 2>&1 || true)

test_start "by_tool_reports_mise_init"
if echo "$out" | grep -q "mise-init"; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # by-tool output missing mise-init row"
fi

test_start "by_tool_p50_correct_for_uniform"
# starship-init: 10 samples of 42ms. P50 must be 42.
if echo "$out" | awk '/starship-init/ {for(i=1;i<=NF;i++) if ($i ~ /^42ms$/) found=1} END {exit !found}'; then
  assert_exit_code 0 "true"
else
  echo "starship-init row didn't show 42ms for percentiles:" >&2
  echo "$out" | grep starship-init >&2 || true
  assert_exit_code 0 "false"
fi

test_start "by_tool_p99_high_for_skewed"
# mise-init: 1..100. P99 must be ≥98 (linear-interp gives 99.01).
mise_row=$(echo "$out" | grep "mise-init")
# Last numeric field before the shells column is p99.
if [[ -n "$mise_row" ]]; then
  # Extract all <num>ms tokens, the 5th-from-end is p99 in our table format
  # (header is: label calls total mean p50 p95 p99 shells)
  p99=$(echo "$mise_row" | grep -oE '[0-9]+ms' | tail -1 | tr -d 'ms')
  if [[ "$p99" -ge 98 ]]; then
    assert_exit_code 0 "true"
  else
    echo "mise-init p99 = $p99, expected ≥98" >&2
    assert_exit_code 0 "false"
  fi
else
  assert_exit_code 0 "false  # mise-init row not found"
fi

# -----------------------------------------------------------------------------
# Baseline write + regression detection
# -----------------------------------------------------------------------------

test_start "baseline_file_created_with_write"
# Run --baseline once; the file should land at $XDG_CACHE_HOME/dotfiles/perf-baseline.json.
# perf.sh --shell zsh requires a working zsh on PATH to measure; on
# minimal CI images that lack zsh, skip rather than fail (this test
# is exercising the aggregator, not zsh availability).
if ! command -v zsh >/dev/null 2>&1; then
  assert_exit_code 0 "true  # skipped: zsh unavailable"
else
  XDG_CACHE_HOME="$tmp/cache" MISE_YES=1 bash "$PERF" --baseline --shell zsh >/dev/null 2>&1 || true
  if [[ -s "$tmp/cache/dotfiles/perf-baseline.json" ]]; then
    assert_exit_code 0 "true"
  else
    assert_exit_code 0 "false  # --baseline did not write the expected file"
  fi
fi

test_start "baseline_file_is_valid_json"
if ! command -v zsh >/dev/null 2>&1; then
  assert_exit_code 0 "true  # skipped: zsh unavailable"
elif [[ -s "$tmp/cache/dotfiles/perf-baseline.json" ]] && \
   python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$tmp/cache/dotfiles/perf-baseline.json" 2>/dev/null; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # baseline file is not valid JSON"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
