#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

TEST_SCRIPT="$REPO_ROOT/scripts/diagnostics/perf.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "perf_exists"
assert_file_exists "$TEST_SCRIPT" "perf.sh should exist"

test_start "perf_syntax"
if bash -n "$TEST_SCRIPT" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: valid syntax"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: syntax error"
fi

# Each short flag does what its long form does. Timings differ run to run,
# so the JSON is compared by what the flags set (runs, target_ms, keys).
perf_json_fields() {
  bash "$TEST_SCRIPT" "$@" 2>/dev/null |
    python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["runs"], d["target_ms"], " ".join(sorted(d)))'
}
test_start "perf_flag_aliases"
long_fields="$(perf_json_fields --json --runs 1 --target 999)"
assert_contains "1 999 " "$long_fields" "--json --runs 1 --target 999 is honoured"
assert_equals "$long_fields" "$(perf_json_fields -j -r 1 -t 999)" "-j -r -t match their long forms"
perf_profile_marker() { bash "$TEST_SCRIPT" "$@" 2>&1 | grep -c 'Top contributors (zprof)' || true; }
assert_equals "0" "$(perf_profile_marker -r 1)" "no profile without the flag"
assert_equals "1" "$(perf_profile_marker --profile -r 1)" "--profile adds the zprof section"
assert_equals "1" "$(perf_profile_marker -p -r 1)" "-p does the same"

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$TEST_SCRIPT"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
