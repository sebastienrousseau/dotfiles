#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Contract of _ai_in_scratch_dir in lib/dot/ai-install.sh when no scratch
# directory can be created: the helper returns 1 and never runs the
# command, so a caller such as `dot ai` reports the install as failed
# instead of running an npm install script in an unknown directory. The
# mutation gate found the failure return unprotected.
#
# Two ways the directory can fail to appear are exercised: a TMPDIR whose
# parent does not exist (real mktemp fails) and a mktemp that itself exits
# non-zero (a stub on a stub-only PATH). Everything lives in a mktemp dir.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

AI_INSTALL="$REPO_ROOT/lib/dot/ai-install.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ai-scratch-fail.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

BASE="$WORK/base"
NOMKTEMP="$WORK/nomktemp"
mkdir -p "$BASE" "$NOMKTEMP" "$WORK/tmp"
ln -sf "${BASH:-$(command -v bash)}" "$BASE/bash"
for tool in sh dirname mktemp rm touch; do
  resolved="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$resolved" ]] && ln -sf "$resolved" "$BASE/$tool"
done
printf '#!/usr/bin/env bash\necho "mktemp: refused" >&2\nexit 1\n' >"$NOMKTEMP/mktemp"
chmod +x "$NOMKTEMP/mktemp"

RC=0
# run_helper <tmpdir> <path> <marker> — source the lib and ask
# _ai_in_scratch_dir to touch <marker>; sets RC.
run_helper() {
  RC=0
  TMPDIR="$1" PATH="$2" "${BASH:-bash}" -c '
    source "$1"
    _ai_in_scratch_dir touch "$2"
  ' _ "$AI_INSTALL" "$3" 2>/dev/null || RC=$?
}

test_start "ai_install_missing_tmpdir_fails_without_running"
run_helper "$WORK/absent" "$BASE" "$WORK/ran-1"
assert_equals 1 "$RC" "returns 1 when the scratch dir cannot be created"
assert_file_not_exists "$WORK/ran-1" "the command is not run"

test_start "ai_install_mktemp_failure_fails_without_running"
run_helper "$WORK/tmp" "$NOMKTEMP:$BASE" "$WORK/ran-2"
assert_equals 1 "$RC" "returns 1 when mktemp fails"
assert_file_not_exists "$WORK/ran-2" "the command is not run"
assert_equals "" "$(ls -A "$WORK/tmp")" "nothing is left in TMPDIR"

test_start "ai_install_scratch_dir_runs_the_command"
run_helper "$WORK/tmp" "$BASE" "$WORK/ran-3"
assert_equals 0 "$RC" "returns 0 when the scratch dir exists"
assert_file_exists "$WORK/ran-3" "the command runs"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
