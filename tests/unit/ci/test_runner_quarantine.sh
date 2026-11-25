#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The test runner honours tests/quarantine.tsv: a quarantined file still
# runs and is reported, but its failures do not fail the run until the
# entry expires.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/runner-quarantine-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/tests/unit/fixture"
cp -R "$REPO_ROOT/tests/framework" "$WORK/tests/framework"
cat >"$WORK/tests/unit/fixture/test_qfixture_fails.sh" <<'EOF'
#!/usr/bin/env bash
echo "RESULTS:1:0:1"
EOF

# run_fixture QUARANTINE_LINE: run the copied runner on the failing fixture;
# sets rc and out.
run_fixture() {
  printf '%s\n' "$1" >"$WORK/quarantine.tsv"
  rc=0
  out="$(QUARANTINE_FILE="$WORK/quarantine.tsv" bash "$WORK/tests/framework/test_runner.sh" 'qfixture_*' 2>&1)" || rc=$?
}

future="$(date -v+10d +%Y-%m-%d 2>/dev/null || date -d '+10 days' +%Y-%m-%d)"
past="$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d '-1 day' +%Y-%m-%d)"

test_start "unquarantined_failure_fails_the_run"
run_fixture "# no entries"
assert_equals "1" "$rc" "a failing file fails the run"
assert_contains "Failed test files (1)" "$out" "it is listed as failed"

test_start "quarantined_failure_is_reported_not_fatal"
run_fixture "$(printf 'test_qfixture_fails.sh\tsebastienrousseau\t%s\tfixture' "$future")"
assert_equals "0" "$rc" "a quarantined failure does not fail the run"
assert_contains "Quarantined test files (1)" "$out" "it is listed as quarantined"
assert_contains "test_qfixture_fails.sh" "$out" "the file is named"

test_start "expired_quarantine_fails_the_run"
run_fixture "$(printf 'test_qfixture_fails.sh\tsebastienrousseau\t%s\tfixture' "$past")"
assert_equals "1" "$rc" "an expired entry no longer protects the file"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
