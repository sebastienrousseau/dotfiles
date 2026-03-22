#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Main test runner for dotfiles test suite
# Discovers and runs all test files, reports results

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

# Run a single test file and capture results
run_test_file() {
  local test_file="$1"
  local temp_results
  temp_results=$(mktemp)
  # Ensure temp file is cleaned up even on early exit
  trap 'rm -f "$temp_results"' RETURN

  echo ""
  echo "Running: $(basename "$test_file")"
  echo "─────────────────────────────────────"

  # Run test as a separate process (not subshell with source)
  # This avoids trap interference from double-sourcing framework files
  local exit_status=0
  bash "$test_file" </dev/null 2>&1 | tee "$temp_results" || exit_status=$?

  # Parse results from output
  local results_line
  results_line=$(grep "^RESULTS:" "$temp_results" | tail -1) || true
  if [[ -n "$results_line" ]]; then
    local run passed failed
    IFS=':' read -r _ run passed failed <<<"$results_line"
    TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + passed))
    TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + failed))
    # Derive run count from assertions to avoid test-case vs assertion mismatch
    TOTAL_TESTS_RUN=$((TOTAL_TESTS_RUN + passed + failed))
  elif [[ $exit_status -ne 0 ]]; then
    # Test file crashed without producing RESULTS -- count as failure
    printf '%b\n' "\033[0;31mERROR: $(basename "$test_file") crashed (exit $exit_status) without producing results\033[0m"
    TOTAL_TESTS_RUN=$((TOTAL_TESTS_RUN + 1))
    TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + 1))
  fi
}

# Show usage
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

Arguments:
  pattern             Run only tests matching pattern (e.g., 'extract', 'backup')

Examples:
  $(basename "$0")                    # Run all unit tests
  $(basename "$0") extract            # Run only extract tests
  $(basename "$0") -i                 # Run unit and integration tests
  RUN_INTEGRATION=1 $(basename "$0")  # Alternative way to run integration tests

Environment Variables:
  RUN_INTEGRATION=1   Enable integration tests
  VERBOSE=1           Enable verbose output
EOF
}

main() {
  local test_pattern="*"
  local run_integration="${RUN_INTEGRATION:-0}"
  local verbose="${VERBOSE:-0}"
  local unit_only=0

  # Initialize global counters
  TOTAL_TESTS_RUN=0
  TOTAL_TESTS_PASSED=0
  TOTAL_TESTS_FAILED=0

  # Parse arguments
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
  echo ""

  local test_count=0

  # Run unit tests
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "UNIT TESTS"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  while IFS= read -r -d '' test_file; do
    run_test_file "$test_file"
    ((test_count++)) || true
  done < <(find "$TESTS_DIR"/unit -name "test_${test_pattern}.sh" -type f -print0 | sort -z)

  if [[ $test_count -eq 0 ]]; then
    echo "No unit tests found matching pattern: $test_pattern"
  fi

  # Run integration tests if requested
  if [[ "$run_integration" == "1" && "$unit_only" != "1" ]]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "INTEGRATION TESTS"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local integration_count=0
    for test_file in "$TESTS_DIR"/integration/test_*.sh; do
      if [[ -f "$test_file" ]]; then
        run_test_file "$test_file"
        ((integration_count++)) || true
      fi
    done

    if [[ $integration_count -eq 0 ]]; then
      echo "No integration tests found."
    fi
  fi

  # Print final summary
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "FINAL SUMMARY"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  printf '%b\n' "Total tests run: $TOTAL_TESTS_RUN"
  printf '%b\n' "\033[0;32mTotal passed: $TOTAL_TESTS_PASSED\033[0m"
  printf '%b\n' "\033[0;31mTotal failed: $TOTAL_TESTS_FAILED\033[0m"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  if [[ $TOTAL_TESTS_FAILED -gt 0 ]]; then
    exit 1
  fi
  exit 0
}

main "$@"
