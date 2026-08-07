#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
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

test_start "enables_xtrace_in_child_shells"
assert_file_contains "$SCRIPT_FILE" "BASH_ENV=" "must export BASH_ENV to enable xtrace in children"

test_start "counts_nested_xtrace_records"
assert_file_contains "$SCRIPT_FILE" 'hit_re = re.compile(r"^\++@COV@:' \
  "must count commands executed inside command substitutions and subshells"

test_start "parallel_via_xargs"
assert_file_contains "$SCRIPT_FILE" "xargs -I" "must parallelize via xargs"

test_start "traces_mandatory_regression_suite"
assert_file_contains "$SCRIPT_FILE" '"$TESTS_DIR/regression"' \
  "coverage must include regressions run by the authoritative test runner"

test_start "trace_names_include_relative_path"
assert_file_contains "$SCRIPT_FILE" 'relative="${f#"$COV_TESTS_DIR"/}"' \
  "trace names must not collide when test basenames match"

test_start "source_paths_are_cached_during_aggregation"
assert_file_contains "$SCRIPT_FILE" "source_cache = {}" \
  "coverage aggregation must not resolve a source path for every trace line"

test_start "function_probe_traces_are_replayed"
assert_file_contains "$SCRIPT_FILE" "export DOTFILES_COV_ECHO_STDERR=1" \
  "function-body xtrace captured by coverage helpers must reach the aggregator"

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
