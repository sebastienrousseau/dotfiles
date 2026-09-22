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

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
