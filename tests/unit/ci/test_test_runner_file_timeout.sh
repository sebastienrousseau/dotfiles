#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# The test runner must kill a test file that exceeds TEST_FILE_TIMEOUT,
# name it as timed out, count it as a failure, and still run and tally the
# other files, in serial and in parallel mode. Before this a hung file
# held a CI lane until the job's six-hour limit with nothing naming it.
#
# A copy of the framework runs against a throwaway tests tree: one file
# that sleeps past the limit and one that passes.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/runner-timeout.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/tests/framework" "$WORK/tests/unit" "$WORK/tests/regression"
cp "$REPO_ROOT/tests/framework/test_runner.sh" "$REPO_ROOT/tests/framework/assertions.sh" "$WORK/tests/framework/"

# The sleeper carries a unique argv (exec -a) so the orphan check cannot
# match another test's sleep when the suite runs in parallel.
TAG="rt-hang-$$"
cat >"$WORK/tests/unit/test_hangs.sh" <<EOF
#!/usr/bin/env bash
echo "started"
exec -a "$TAG" sleep 60 &
wait
echo "RESULTS:1:1:0"
EOF
cat >"$WORK/tests/unit/test_quick.sh" <<'EOF'
#!/usr/bin/env bash
echo "RESULTS:2:2:0"
EOF

# run <extra runner args...>: two-second limit; captures output and rc.
run() {
  rc=0
  TEST_FILE_TIMEOUT=2 bash "$WORK/tests/framework/test_runner.sh" --unit-only "$@" >"$WORK/out" 2>&1 || rc=$?
}
strip() { sed -E 's/\x1b\[[0-9;]*m//g' "$WORK/out"; }

for mode in "" "--jobs 2"; do
  label="serial"
  [[ -n "$mode" ]] && label="parallel"
  test_start "runner_${label}_kills_and_names_the_hung_file"
  start=$SECONDS
  # shellcheck disable=SC2086
  run $mode
  elapsed=$((SECONDS - start))
  assert_true "[[ $elapsed -lt 30 ]]" "the run ends well before the 60s sleep (took ${elapsed}s)"
  assert_equals "1" "$rc" "a timed-out file fails the run"
  assert_true "strip | grep -q 'ERROR: test_hangs.sh timed out after 2s'" "the hung file is named as timed out"
  test_start "runner_${label}_still_tallies_the_other_file"
  assert_true "strip | grep -q 'Total passed: 2'" "the quick file's two passes are counted"
  assert_true "strip | grep -q 'Total failed: 1'" "the timeout counts as one failure"
  test_start "runner_${label}_leaves_no_orphan"
  assert_equals "0" "$(pgrep -f "$TAG" | wc -l | tr -d ' ')" "the hung file's sleep was killed with it"
done

test_start "runner_timeout_off_runs_to_completion"
rc=0
TEST_FILE_TIMEOUT=0 bash "$WORK/tests/framework/test_runner.sh" --unit-only quick >"$WORK/out" 2>&1 || rc=$?
assert_equals "0" "$rc" "with the limit off a passing file passes"
assert_true "strip | grep -q 'Total passed: 2'" "tally unchanged"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
