#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# vibe-delegate's scratch files must live in a private per-run directory
# under $TMPDIR. BSD mktemp keeps the X's literal when a suffix follows,
# so the old `mktemp /tmp/vibe-cmd-XXXXXX.sh` names were fixed paths in
# the shared /tmp: concurrent runs collided and another user could
# pre-create them.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DELEGATE="$REPO_ROOT/defaults/dot_claude/skills/vibe/tools/executable_vibe-delegate"

if ! command -v python3 >/dev/null 2>&1; then
  echo "SKIP: python3 not installed"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d -t vibe-tmp.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stubs" "$WORK/home" "$WORK/tmp" "$WORK/repo"
git -C "$WORK/repo" init -q

# vibe stub: records where its scratch files are, then succeeds.
cat >"$WORK/stubs/vibe" <<STUB
#!/usr/bin/env bash
ls "\$TMPDIR" >>"$WORK/seen.log"
echo '{"role":"assistant","content":"ok"}'
exit 0
STUB
chmod +x "$WORK/stubs/vibe"

run_delegate() {
  HOME="$WORK/home" TMPDIR="$WORK/tmp" PATH="$WORK/stubs:$PATH" \
    bash "$DELEGATE" "$WORK/repo" "say ok" 1 "" 30 >"$WORK/out.$1" 2>&1
}

test_start "vibe_delegate_concurrent_runs_complete"
run_delegate a &
pid_a=$!
run_delegate b &
pid_b=$!
wait "$pid_a" "$pid_b"
# The stub does no work, so the delegation's own verdict is not the point;
# both runs must get through to the summary without a temp-file collision.
done_count="$(cat "$WORK/out.a" "$WORK/out.b" | grep -c '^Tool calls:')"
assert_equals "2" "$done_count" "two concurrent delegations both run to completion"
test_start "vibe_delegate_no_tempfile_collision"
assert_output_not_contains "File exists" cat "$WORK/out.a" "$WORK/out.b"

test_start "vibe_delegate_uses_private_tmpdir"
assert_contains "vibe-delegate." "$(cat "$WORK/seen.log" 2>/dev/null)" \
  "scratch files are in a per-run directory under TMPDIR"

test_start "vibe_delegate_cleans_up"
assert_equals "" "$(ls -A "$WORK/tmp")" "the per-run directory is removed afterwards"

# run_delegate_on PATH NAME BUDGET: one delegation with PATH ahead of the
# stubs' directory; sets RC to its exit status.
run_delegate_on() {
  RC=0
  HOME="$WORK/home" TMPDIR="$WORK/tmp" PATH="$WORK/stubs:$1" \
    bash "$DELEGATE" "$WORK/repo" "say ok" 1 "" "$3" >"$WORK/out.$2" 2>&1 || RC=$?
}

# A run that changes nothing and leaves no session log is a success: under
# set -e, `grep -c` finding no changed files and `ls` finding no log both
# used to end the script with status 1.
test_start "vibe_delegate_quiet_run_exits_0"
run_delegate_on "$PATH" quiet 30
assert_equals "0" "$RC" "exit 0"
assert_contains "[vibe] ok" "$(cat "$WORK/out.quiet")" "the delegate's reply is read"

# macOS before 27 ships no timeout(1). The delegation still runs there.
NO_TIMEOUT_PATH="$(path_without "$WORK/nt-bin" timeout gtimeout)"
test_start "vibe_delegate_runs_without_timeout_binary"
run_delegate_on "$NO_TIMEOUT_PATH" nt 30
assert_equals "0" "$RC" "exit 0"
assert_contains "[vibe] ok" "$(cat "$WORK/out.nt")" "the delegate runs and its reply is read"
assert_output_not_contains "VIBE TIMEOUT" cat "$WORK/out.nt"

# A delegate that outlives its budget is stopped, reported and exits 124,
# with or without timeout(1). The failing pipeline used to end the script
# under set -e before the report.
cat >"$WORK/stubs/vibe" <<'STUB'
sleep 60
STUB
for case in "with_timeout_binary:$PATH" "without_timeout_binary:$NO_TIMEOUT_PATH"; do
  test_start "vibe_delegate_reports_a_timeout_${case%%:*}"
  start=$SECONDS
  run_delegate_on "${case#*:}" "hang-${case%%:*}" 2
  assert_equals "124" "$RC" "exit 124"
  assert_contains "VIBE TIMEOUT" "$(cat "$WORK/out.hang-${case%%:*}")" "the timeout is reported"
  assert_equals "true" "$([[ $((SECONDS - start)) -lt 30 ]] && echo true || echo false)" \
    "and the delegate is stopped near its budget"
done

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
