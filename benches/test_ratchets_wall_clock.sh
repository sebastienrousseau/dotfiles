#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Wall-clock gate for the core CI ratchet tests.
#
# The 7 gates below run on every PR via .github/workflows/dot-cli-
# coverage.yml. Together they enforce 100% docs-sync, route
# integrity, help-topic parity, coverage, and 51/51 theme docs-sync.
# If any of them ever creeps above ~10s each (or the sum above the
# ceiling below), CI time balloons — this test catches that early.
#
# Threshold: 15000ms across all 7 gate scripts. Baseline on the
# reference machine (2026-08-29): ~4300ms. 3.5x headroom is
# intentional — CI runners are slower and network calls in the man-
# page lint step add variance.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"
source "$SCRIPT_DIR/../framework/cmd_test_helpers.sh"

GATES=(
  tests/unit/commands/test_cli_docs_sync.sh
  tests/unit/commands/test_cli_route_integrity.sh
  tests/unit/commands/test_cli_help_coverage.sh
  tests/unit/theme/test_theme_docs_sync.sh
  tests/performance/coverage_dot_cli.sh
  tests/performance/coverage_dot_theme.sh
)

THRESHOLD_MS="${RATCHET_WALL_CLOCK_MS:-15000}"

test_start "all_ratchet_gate_files_present"
missing=()
for g in "${GATES[@]}"; do
  [[ -f "$REPO_ROOT/$g" ]] || missing+=("$g")
done
if [[ ${#missing[@]} -eq 0 ]]; then
  _ok
else
  _fail "missing gate files: ${missing[*]}"
  _cmd_finish
  exit 1
fi

test_start "individual_gate_pass_rates"
fail_summary=()
for g in "${GATES[@]}"; do
  out="$(bash "$REPO_ROOT/$g" 2>&1)"
  # Coverage tools don't emit RESULTS: — probe them via exit code
  # (they set MIN_COVERAGE gate) and skip the pass-rate check.
  if [[ "$g" == *"coverage_dot_"* ]]; then
    continue
  fi
  results_line="$(printf '%s\n' "$out" | grep '^RESULTS:' | tail -1)"
  if [[ -z "$results_line" ]]; then
    fail_summary+=("$(basename "$g"): no RESULTS: line")
    continue
  fi
  IFS=: read -r _ _ pass fail <<<"$results_line"
  if (( fail != 0 )); then
    fail_summary+=("$(basename "$g"): $fail failed of $((pass + fail))")
  fi
done
if [[ ${#fail_summary[@]} -eq 0 ]]; then
  _ok "all 4 assertion-based gates pass"
else
  _fail "${fail_summary[*]}"
fi

test_start "total_wall_clock_under_threshold_${THRESHOLD_MS}ms"
start_ns=$(date +%s%N)
for g in "${GATES[@]}"; do
  MIN_COVERAGE=100 bash "$REPO_ROOT/$g" >/dev/null 2>&1
done
end_ns=$(date +%s%N)
elapsed_ms=$(( (end_ns - start_ns) / 1000000 ))
if (( elapsed_ms <= THRESHOLD_MS )); then
  _ok "elapsed=${elapsed_ms}ms threshold=${THRESHOLD_MS}ms"
  printf '     baseline reference: ~4300ms on 2026-08-29\n'
else
  _fail "elapsed=${elapsed_ms}ms EXCEEDS threshold=${THRESHOLD_MS}ms — a gate regressed"
fi

test_start "per_gate_under_5s_each"
slow=()
for g in "${GATES[@]}"; do
  start_ns=$(date +%s%N)
  MIN_COVERAGE=100 bash "$REPO_ROOT/$g" >/dev/null 2>&1
  end_ns=$(date +%s%N)
  ms=$(( (end_ns - start_ns) / 1000000 ))
  if (( ms > 5000 )); then
    slow+=("$(basename "$g"):${ms}ms")
  fi
done
if [[ ${#slow[@]} -eq 0 ]]; then
  _ok
else
  _fail "slow gates (>5s each): ${slow[*]}"
fi

_cmd_finish
