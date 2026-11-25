#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behaviour of tools/ci/check-quarantine.py against fixture quarantine files.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CHECK="$REPO_ROOT/tools/ci/check-quarantine.py"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/quarantine-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/tests/unit"
: >"$WORK/tests/unit/test_flaky.sh"

# check FILE: run the checker on a fixture tree dated 2026-11-25; sets rc, out.
check() {
  rc=0
  out="$(python3 "$CHECK" --file "$1" --tests-dir "$WORK/tests" --today 2026-11-25 2>&1)" || rc=$?
}

# entry FIELDS...: one tab-separated quarantine line.
entry() { (IFS=$'\t' && printf '%s\n' "$*"); }

test_start "empty_quarantine_passes"
printf '# file\towner\texpires\treason\n' >"$WORK/empty.tsv"
check "$WORK/empty.tsv"
assert_equals "0" "$rc" "a quarantine with only its header passes"

test_start "valid_entry_passes"
entry test_flaky.sh sebastienrousseau 2026-12-20 "fails 2 of 50 nightly runs" >"$WORK/valid.tsv"
check "$WORK/valid.tsv"
assert_equals "0" "$rc" "an owned, explained entry inside 60 days passes"

test_start "expired_entry_fails"
entry test_flaky.sh sebastienrousseau 2026-11-24 "fails 2 of 50 nightly runs" >"$WORK/expired.tsv"
check "$WORK/expired.tsv"
assert_equals "1" "$rc" "an expired entry fails"
assert_contains "test_flaky.sh: expired on 2026-11-24" "$out" "the expiry is named"

test_start "far_expiry_fails"
entry test_flaky.sh sebastienrousseau 2027-06-01 "fails 2 of 50 nightly runs" >"$WORK/far.tsv"
check "$WORK/far.tsv"
assert_equals "1" "$rc" "an expiry more than 60 days out fails"
assert_contains "more than 60 days" "$out" "the limit is named"

test_start "unknown_file_fails"
entry test_gone.sh sebastienrousseau 2026-12-20 "fails 2 of 50" >"$WORK/gone.tsv"
check "$WORK/gone.tsv"
assert_equals "1" "$rc" "an entry for a missing test file fails"
assert_contains "test_gone.sh: no such test file" "$out" "the missing file is named"

test_start "missing_reason_fails"
printf 'test_flaky.sh\tsebastienrousseau\t2026-12-20\t\n' >"$WORK/noreason.tsv"
check "$WORK/noreason.tsv"
assert_equals "1" "$rc" "an entry without a reason fails"
assert_contains "test_flaky.sh: needs a file, owner, expiry and reason" "$out" "the gap is named"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
