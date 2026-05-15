#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Tests for scripts/ci/dot-cli-startup-bench.sh — sub-100ms CLI
# cold-start gate. Covers existence, syntax, help, and a relaxed
# bench run against a comfortable budget.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/ci/dot-cli-startup-bench.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/ci/dot-cli-startup-bench.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "script_help"
if bash "$SCRIPT_FILE" --help 2>&1 | grep -q 'cold-start'; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# Run a small bench with a deliberately loose budget so the test
# remains stable across diverse CI runners. We only verify the
# pipeline runs end-to-end and prints a median; the per-OS gate
# budgets live in `.github/workflows/dot-cli-bench.yml`.
test_start "script_executes_5_runs"
out="$(bash "$SCRIPT_FILE" --runs 5 --budget-ms 5000 2>&1 || true)"
if [[ "$out" == *"median:"* ]] && [[ "$out" == *"within budget"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
  printf '    last 5 lines:\n%s\n' "$(printf '%s' "$out" | tail -5)"
fi

# Bench should refuse unknown flags (defensive).
test_start "script_rejects_unknown_flag"
if bash "$SCRIPT_FILE" --definitely-not-a-real-flag 2>/dev/null; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: should have rejected"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
