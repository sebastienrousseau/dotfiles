#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Main test runner for dotfiles test suite
# Discovers and runs all test files, reports results.
#
# Parallelism (closes #867):
#   --jobs N      run N test files concurrently (default: 1)
#   --jobs auto   use the detected CPU count (nproc on Linux,
#                 `sysctl -n hw.ncpu` on macOS)
#
# Per-file output is captured to a private tempfile so concurrent
# runs don't interleave. With --jobs 1, output is streamed live; with
# --jobs >1 it's collected and replayed in completion order.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$(dirname "$SCRIPT_DIR")"
REPO_ROOT="$(dirname "$TESTS_DIR")"

if [[ ! -d "$REPO_ROOT" ]]; then
  echo "Error: REPO_ROOT is not a valid directory: $REPO_ROOT" >&2
  exit 1
fi

# Export paths for test files
export TESTS_DIR
export REPO_ROOT
export FRAMEWORK_DIR="$SCRIPT_DIR"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------

detect_cores() {
  if command -v nproc >/dev/null 2>&1; then
    nproc
  elif command -v sysctl >/dev/null 2>&1; then
    sysctl -n hw.ncpu 2>/dev/null || echo 1
  else
    echo 1
  fi
}

# Run a single test file in serial mode (live output).
run_test_file_serial() {
  local test_file="$1"
  local temp_results
  temp_results=$(mktemp)
  # Double-quote: $temp_results captured at trap-registration time, so
  # the trap fires correctly even when run from a calling function that
  # has `set -u` enabled.
  # shellcheck disable=SC2064
  trap "rm -f '$temp_results'" RETURN

  echo ""
  echo "Running: $(basename "$test_file")"
  echo "─────────────────────────────────────"

  local exit_status=0
  bash "$test_file" </dev/null 2>&1 | tee "$temp_results" || exit_status=$?

  local results_line
  results_line=$(grep "^RESULTS:" "$temp_results" | tail -1) || true
  if [[ -n "$results_line" ]]; then
    local run passed failed
    IFS=':' read -r _ run passed failed <<<"$results_line"
    TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + passed))
    TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + failed))
    TOTAL_TESTS_RUN=$((TOTAL_TESTS_RUN + passed + failed))
    if [[ "$failed" -gt 0 ]]; then TOTAL_FAILED_FILES+=("$(basename "$test_file") ($failed failed)"); fi
  elif [[ $exit_status -ne 0 ]]; then
    printf '%b\n' "\033[0;31mERROR: $(basename "$test_file") crashed (exit $exit_status) without producing results\033[0m"
    TOTAL_TESTS_RUN=$((TOTAL_TESTS_RUN + 1))
    TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + 1))
    TOTAL_FAILED_FILES+=("$(basename "$test_file") (crashed exit=$exit_status)")
  fi
}

# Worker for parallel mode: write per-file output to its own file.
# Invoked via xargs -I {} so it receives one filename per invocation.
run_test_file_worker() {
  local test_file="$1"
  local out_dir="$2"
  local out_file="$out_dir/$(basename "$test_file").out"

  {
    echo ""
    echo "Running: $(basename "$test_file")"
    echo "─────────────────────────────────────"
    local exit_status=0
    bash "$test_file" </dev/null 2>&1 || exit_status=$?
    # Append exit status sentinel for the aggregator
    printf 'EXIT_STATUS:%d\n' "$exit_status"
  } >"$out_file" 2>&1
}

# Aggregate per-file outputs (for parallel mode), replay them in
# alphabetical order, and tally results.
aggregate_parallel_results() {
  local out_dir="$1"
  local f

  for f in "$out_dir"/*.out; do
    [[ -f "$f" ]] || continue
    cat "$f"

    local results_line exit_status_line exit_status=0
    results_line=$(grep "^RESULTS:" "$f" | tail -1) || true
    exit_status_line=$(grep "^EXIT_STATUS:" "$f" | tail -1) || true
    if [[ -n "$exit_status_line" ]]; then
      exit_status=${exit_status_line#EXIT_STATUS:}
    fi

    if [[ -n "$results_line" ]]; then
      local run passed failed
      IFS=':' read -r _ run passed failed <<<"$results_line"
      TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + passed))
      TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + failed))
      TOTAL_TESTS_RUN=$((TOTAL_TESTS_RUN + passed + failed))
      if [[ "$failed" -gt 0 ]]; then TOTAL_FAILED_FILES+=("$(basename "$f" .out) ($failed failed)"); fi
    elif [[ $exit_status -ne 0 ]]; then
      printf '%b\n' "\033[0;31mERROR: $(basename "$f" .out) crashed (exit $exit_status) without producing results\033[0m"
      TOTAL_TESTS_RUN=$((TOTAL_TESTS_RUN + 1))
      TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + 1))
      TOTAL_FAILED_FILES+=("$(basename "$f" .out) (crashed exit=$exit_status)")
    fi
  done
}

# Run a list of test files. Honours $JOBS (set by main).
# Args: <header-text> <test-file...>
run_test_list() {
  local header="$1"
  shift
  [[ $# -eq 0 ]] && return 0

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$header"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ "$JOBS" -le 1 ]]; then
    local f
    for f in "$@"; do
      run_test_file_serial "$f"
    done
  else
    local out_dir
    out_dir=$(mktemp -d)
    # shellcheck disable=SC2064  # capture $out_dir at trap-registration time
    trap "rm -rf '$out_dir'" RETURN

    export -f run_test_file_worker
    # shellcheck disable=SC2016  # $0 inside xargs invocation
    printf '%s\n' "$@" | xargs -I{} -P "$JOBS" \
      bash -c 'run_test_file_worker "$@"' _ {} "$out_dir"

    aggregate_parallel_results "$out_dir"
  fi
}

# -----------------------------------------------------------------------------
# CLI
# -----------------------------------------------------------------------------

usage() {
  cat <<EOF
Dotfiles Test Runner

Usage:
  $(basename "$0") [options] [pattern]

Options:
  -h, --help          Show this help message
  -v, --verbose       Verbose output
  -i, --integration   Include integration tests
  -u, --unit-only     Run only unit tests
  --jobs N            Run N test files in parallel (default 1)
  --jobs auto         Use the detected CPU count

Arguments:
  pattern             Run only tests matching pattern (e.g., 'extract', 'backup')

Examples:
  $(basename "$0")                    # Run all unit tests serially
  $(basename "$0") --jobs auto        # Run all unit tests in parallel
  $(basename "$0") extract            # Run only extract tests
  $(basename "$0") -i                 # Run unit and integration tests
  RUN_INTEGRATION=1 $(basename "$0")  # Alternative way to run integration tests

Environment Variables:
  RUN_INTEGRATION=1   Enable integration tests
  VERBOSE=1           Enable verbose output
  TEST_JOBS=N         Default parallelism (overridden by --jobs)
EOF
}

main() {
  local test_pattern="*"
  local run_integration="${RUN_INTEGRATION:-0}"
  local verbose="${VERBOSE:-0}"
  local unit_only=0
  JOBS="${TEST_JOBS:-1}"

  TOTAL_TESTS_RUN=0
  TOTAL_TESTS_PASSED=0
  TOTAL_TESTS_FAILED=0
  TOTAL_FAILED_FILES=()

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      -v | --verbose)
        verbose=1
        shift
        ;;
      -i | --integration)
        run_integration=1
        shift
        ;;
      -u | --unit-only)
        unit_only=1
        shift
        ;;
      --jobs)
        shift
        case "${1:-}" in
          auto) JOBS=$(detect_cores) ;;
          [0-9]*) JOBS="$1" ;;
          *)
            echo "Error: --jobs requires a positive integer or 'auto'" >&2
            exit 1
            ;;
        esac
        shift
        ;;
      --jobs=*)
        case "${1#*=}" in
          auto) JOBS=$(detect_cores) ;;
          [0-9]*) JOBS="${1#*=}" ;;
          *)
            echo "Error: --jobs requires a positive integer or 'auto'" >&2
            exit 1
            ;;
        esac
        shift
        ;;
      -*)
        echo "Unknown option: $1" >&2
        usage
        exit 1
        ;;
      *)
        test_pattern="$1"
        shift
        ;;
    esac
  done

  echo "╔═══════════════════════════════════════╗"
  echo "║     Dotfiles Test Suite               ║"
  echo "╚═══════════════════════════════════════╝"
  echo ""
  echo "Repository: $REPO_ROOT"
  echo "Tests Dir:  $TESTS_DIR"
  echo "Parallelism: $JOBS"
  echo ""

  # Collect unit tests
  local unit_files=()
  while IFS= read -r -d '' f; do
    unit_files+=("$f")
  done < <(find "$TESTS_DIR"/unit -name "test_${test_pattern}.sh" -type f -print0 | sort -z)

  if [[ ${#unit_files[@]} -eq 0 ]]; then
    echo "No unit tests found matching pattern: $test_pattern"
  else
    run_test_list "UNIT TESTS (${#unit_files[@]} files)" "${unit_files[@]}"
  fi

  # Collect + run regression tests. These are always run alongside unit
  # tests (issue #868 — regressions must always be exercised), but only
  # when the user is running the full suite. When a `pattern` argument
  # narrows the unit set (e.g. `--jobs 1 secrets_*` from
  # test_runner_parallel_invariant.sh), skip regression tests to avoid
  # recursive self-invocation through the parallel-invariant guard.
  if [[ "$unit_only" != "1" && "$test_pattern" == "*" ]]; then
    local regression_files=()
    while IFS= read -r -d '' f; do
      regression_files+=("$f")
    done < <(find "$TESTS_DIR"/regression -name "test_*.sh" -type f -print0 | sort -z)
    if [[ ${#regression_files[@]} -gt 0 ]]; then
      run_test_list "REGRESSION TESTS (${#regression_files[@]} files)" "${regression_files[@]}"
    fi
  fi

  # Collect + run integration tests if requested. Same pattern-gate
  # as the regression block above: when a `pattern` narrows the unit
  # set (e.g. `--jobs auto secrets_*` from
  # test_runner_parallel_invariant.sh), skip integration tests too.
  # Without this gate the inner parallel run pulls in every
  # integration test whenever RUN_INTEGRATION was inherited from the
  # outer reliability-audit --with-integration invocation, which
  # turned into a flaky chezmoi-apply assertion on macOS Reliability.
  if [[ "$run_integration" == "1" && "$unit_only" != "1" && "$test_pattern" == "*" ]]; then
    local integration_files=()
    for f in "$TESTS_DIR"/integration/test_*.sh; do
      [[ -f "$f" ]] && integration_files+=("$f")
    done
    if [[ ${#integration_files[@]} -gt 0 ]]; then
      run_test_list "INTEGRATION TESTS (${#integration_files[@]} files)" "${integration_files[@]}"
    else
      echo "No integration tests found."
    fi
  fi

  # Final summary
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "FINAL SUMMARY"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf '%b\n' "Total tests run: $TOTAL_TESTS_RUN"
  printf '%b\n' "\033[0;32mTotal passed: $TOTAL_TESTS_PASSED\033[0m"
  printf '%b\n' "\033[0;31mTotal failed: $TOTAL_TESTS_FAILED\033[0m"
  if [[ "${#TOTAL_FAILED_FILES[@]}" -gt 0 ]]; then
    printf '%b\n' "\033[0;31mFailed test files (${#TOTAL_FAILED_FILES[@]}):\033[0m"
    printf '  - %s\n' "${TOTAL_FAILED_FILES[@]}"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ $TOTAL_TESTS_FAILED -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
