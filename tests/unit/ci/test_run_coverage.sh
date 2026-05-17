#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Tests for tools/ci/run-coverage.sh — the xtrace-based bash
# coverage runner introduced by Slice 1 of #883. Asserts file
# structure + entry-point behaviour; the runner itself is exercised
# end-to-end by the Coverage / kcov workflow.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/tools/ci/run-coverage.sh"

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "run-coverage.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "uses_strict_mode"
# `set -uo pipefail` (no -e because we want failures-don't-kill-the-run
# semantics inside the xargs loop). Just confirm the safety opts are
# enabled at the top.
assert_file_contains "$SCRIPT_FILE" "set -uo pipefail" "must enable -u and pipefail"

test_start "defines_min_coverage_pct"
assert_file_contains "$SCRIPT_FILE" 'MIN_COVERAGE_PCT=' "must declare MIN_COVERAGE_PCT"

test_start "uses_bash_xtrace_mechanism"
assert_file_contains "$SCRIPT_FILE" "PS4=" "must set PS4 for line-marker capture"
assert_file_contains "$SCRIPT_FILE" "BASH_ENV=" "must export BASH_ENV to enable xtrace in children"

test_start "parallel_via_xargs"
assert_file_contains "$SCRIPT_FILE" "xargs -I" "must parallelize via xargs"

test_start "macos_supported"
# Earlier kcov-based runner had a Darwin skip; xtrace works on macOS
# too. Make sure no `uname` Darwin-skip path was reintroduced.
if grep -qE 'uname.*Darwin.*skip|skip.*Darwin' "$SCRIPT_FILE"; then
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: runner re-introduced a macOS skip"
else
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
fi

# Note: do NOT add cov_exercise_script here. This test asserts properties
# of the coverage runner itself; running the runner during a coverage run
# would spawn nested traces and pollute the parent's aggregation.

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
