#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behaviour of tools/ci/flake-report.py against fixture runner logs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

REPORT="$REPO_ROOT/tools/ci/flake-report.py"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/flake-report-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# runlog FILE FAILED...: a runner summary whose failed and quarantined lists
# are given as "f:name" or "q:name".
runlog() {
  local file="$1" item
  shift
  {
    printf 'Total tests run: 10\nTotal passed: 9\nTotal failed: 1\n'
    printf 'Failed test files (%s):\n' "$#"
    for item in "$@"; do [[ "$item" == f:* ]] && printf '  - %s (1 failed)\n' "${item#f:}"; done
    printf 'Quarantined test files (%s):\n' "$#"
    for item in "$@"; do [[ "$item" == q:* ]] && printf '  - %s (1 failed)\n' "${item#q:}"; done
    printf '━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n'
  } >"$file"
}

: >"$WORK/quarantine.tsv"
printf 'test_known.sh\tsebastienrousseau\t2026-12-20\tseen 2 of 50\n' >"$WORK/quarantine.tsv"

# report LOG...: run the report; sets rc and out.
report() {
  rc=0
  out="$(python3 "$REPORT" --quarantine "$WORK/quarantine.tsv" "$@" 2>&1)" || rc=$?
}

test_start "clean_runs_pass"
runlog "$WORK/a.log"
runlog "$WORK/b.log"
report "$WORK/a.log" "$WORK/b.log"
assert_equals "0" "$rc" "no failures in any run passes"

test_start "new_flake_fails"
runlog "$WORK/c.log" f:test_new.sh
runlog "$WORK/d.log"
runlog "$WORK/e.log"
report "$WORK/c.log" "$WORK/d.log" "$WORK/e.log"
assert_equals "1" "$rc" "a test failing in some runs and not quarantined fails the job"
assert_contains "flaky: test_new.sh failed 1 of 3 runs" "$out" "the flake and its rate are named"

test_start "quarantined_flake_is_reported_not_fatal"
runlog "$WORK/f.log" q:test_known.sh
runlog "$WORK/g.log"
report "$WORK/f.log" "$WORK/g.log"
assert_equals "0" "$rc" "a quarantined flake does not fail the job"
assert_contains "quarantined: test_known.sh failed 1 of 2 runs" "$out" "it is still reported"

test_start "consistent_failure_fails"
runlog "$WORK/h.log" f:test_broken.sh
runlog "$WORK/i.log" f:test_broken.sh
report "$WORK/h.log" "$WORK/i.log"
assert_equals "1" "$rc" "a test failing in every run fails the job"
assert_contains "broken: test_broken.sh failed 2 of 2 runs" "$out" "it is named as broken, not flaky"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
