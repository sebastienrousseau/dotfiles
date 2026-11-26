#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# test_runner.sh PATTERN runs tests/unit/**/test_PATTERN.sh. A pattern that
# selects no file has tested nothing, so the run fails rather than passing
# with "Total tests run: 0": cross-platform-test.yml looked for files that
# were not where its glob pointed and reported success for months.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/runner-pattern-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/tests/unit/fixture"
cp -R "$REPO_ROOT/tests/framework" "$WORK/tests/framework"
cat >"$WORK/tests/unit/fixture/test_pfixture_ok.sh" <<'EOF'
echo "RESULTS:1:1:0"
EOF

# run PATTERN: the copied runner, unit tests only; sets rc and out.
run() {
  rc=0
  out="$(bash "$WORK/tests/framework/test_runner.sh" --unit-only "$1" 2>&1)" || rc=$?
}

test_start "a_matching_pattern_runs_its_files"
run 'pfixture_*'
assert_equals "0" "$rc" "the matching file passes"
assert_contains "UNIT TESTS (1 files)" "$out" "one file ran"

test_start "a_pattern_that_selects_nothing_fails"
run 'nomatch_*'
assert_equals "1" "$rc" "no file selected is a failure"
assert_contains "No unit tests found matching pattern: nomatch_*" "$out" "and says which pattern"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
