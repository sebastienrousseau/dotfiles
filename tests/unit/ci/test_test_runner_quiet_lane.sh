#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# A test file marked `# test-lane: quiet` must not share the machine with
# the parallel pool: the runner starts it only after every other file has
# finished, and still tallies it.
#
# tests/regression/test_gate_integrity.sh times the real performance gate
# and asserts it passes within budget. Inside `--jobs auto` the rest of the
# suite loaded the machine past the gate's 4x runner cap, the gate refused
# to give a verdict, and the meta-test failed the pre-push audit while
# passing on every run on its own.
#
# A copy of the framework runs against a throwaway tests tree: a slow file
# that logs when it finishes, and a quiet-lane file that logs when it
# starts. The quiet file sorts first, so without the lane it starts first.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/runner-quiet.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/tests/framework" "$WORK/tests/unit" "$WORK/tests/regression"
cp "$REPO_ROOT/tests/framework/test_runner.sh" "$REPO_ROOT/tests/framework/assertions.sh" \
  "$REPO_ROOT/tests/framework/git_env.sh" "$WORK/tests/framework/"

LOG="$WORK/order.log"
cat >"$WORK/tests/unit/test_a_quiet.sh" <<EOF
#!/usr/bin/env bash
# test-lane: quiet
echo "quiet-start" >>"$LOG"
echo "RESULTS:1:1:0"
EOF
cat >"$WORK/tests/unit/test_b_busy.sh" <<EOF
#!/usr/bin/env bash
echo "busy-start" >>"$LOG"
sleep 2
echo "busy-end" >>"$LOG"
echo "RESULTS:2:2:0"
EOF

strip() { sed -E 's/\x1b\[[0-9;]*m//g' "$WORK/out"; }

test_start "runner_parallel_runs_quiet_lane_after_the_pool"
rc=0
bash "$WORK/tests/framework/test_runner.sh" --unit-only --jobs 2 >"$WORK/out" 2>&1 || rc=$?
assert_equals "0" "$rc" "both files pass"
assert_equals "busy-start busy-end quiet-start" "$(tr '\n' ' ' <"$LOG" | sed 's/ $//')" \
  "the quiet file starts only after the busy file has finished"

test_start "runner_parallel_tallies_the_quiet_lane"
assert_true "strip | grep -q 'Total passed: 3'" "the quiet file's pass is counted with the pool's"
assert_true "strip | grep -q 'Running: test_a_quiet.sh'" "the quiet file's output is replayed"

test_start "runner_serial_ignores_the_lane"
: >"$LOG"
rc=0
bash "$WORK/tests/framework/test_runner.sh" --unit-only >"$WORK/out" 2>&1 || rc=$?
assert_equals "0" "$rc" "both files pass serially"
assert_true "strip | grep -q 'Total passed: 3'" "serial mode tallies both"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
