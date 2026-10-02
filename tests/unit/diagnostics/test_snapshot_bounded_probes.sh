#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# `dot snapshot` asks each tool for its version. rustc behind rustup's
# proxy never answers when HOME has no toolchain, and the snapshot hung
# until whatever ran it gave up. Each probe is now bounded (lib/dot/probe.sh):
# a tool that does not answer is recorded as unknown and the rest are kept.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d -t dot-snapshot.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home"
# A rustc that never answers and leaves a grandchild holding stdout, as
# rustup's proxy does; a git that answers at once.
printf '#!/usr/bin/env bash\nsleep 60 &\nwait\n' >"$WORK/bin/rustc"
printf '#!/usr/bin/env bash\necho "git version 9.8.7"\n' >"$WORK/bin/git"
chmod +x "$WORK/bin/rustc" "$WORK/bin/git"

test_start "snapshot_bounds_a_tool_that_never_answers"
start=$SECONDS
run_with_timeout 40 env PATH="$WORK/bin:/usr/bin:/bin" HOME="$WORK/home" \
  XDG_STATE_HOME="$WORK/home/.local/state" NO_COLOR=1 \
  bash "$REPO_ROOT/scripts/diagnostics/snapshot.sh" -b >"$WORK/out" 2>&1
rc=$?
elapsed=$((SECONDS - start))
assert_equals "0" "$rc" "the snapshot completes (${elapsed}s)"
assert_equals "true" "$([[ $elapsed -lt 20 ]] && echo true || echo false)" \
  "the stuck probe is cut off at its limit, not the 60s it would take (${elapsed}s)"

BASELINE="$WORK/home/.local/state/dotfiles/snapshots/baseline.json"
test_start "snapshot_records_what_answered"
assert_file_exists "$BASELINE" "baseline.json is written"
assert_equals "ok" "$(python3 -c 'import json,sys; json.load(open(sys.argv[1])); print("ok")' "$BASELINE" 2>&1)" \
  "the baseline is valid JSON"
assert_file_contains "$BASELINE" '"git": "9.8.7"' "a tool that answered is recorded"
assert_file_contains "$BASELINE" '"rustc": ""' "the tool that did not answer is left empty"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
