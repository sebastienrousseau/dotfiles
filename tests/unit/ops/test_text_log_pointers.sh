#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# The plain-text logs stay in their formats, but each writer logs one
# log.v1 text_log event naming its file (O6), so they can be found from the
# log.v1 logs: dot_log_pointer, once per process and file, and the rollback
# writer. (dot system schedule run's is in test_system_schedule.sh.)
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BASH_BIN="$(command -v bash)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
LOG="$WORK/home/.local/state/dot/cli/log.jsonl"
mkdir -p "$WORK/home"

test_start "pointer_once_per_file"
env -i HOME="$WORK/home" PATH="$PATH" "$BASH_BIN" -c '
  source "$1/lib/dot/log.sh"
  dot_log_pointer /x/a.log writer-a
  dot_log_pointer /x/a.log writer-a
  dot_log_pointer /x/b.log writer-b' _ "$REPO_ROOT"
assert_equals "2" "$(grep -c '"event":"text_log"' "$LOG" 2>/dev/null)" "one event per file"
assert_contains '"data":{"path":"/x/a.log","writer":"writer-a","format":"text"}' "$(cat "$LOG" 2>/dev/null)" "naming the file and its writer"

test_start "rollback_points_at_rollback_log"
rm -f "$LOG"
env -i HOME="$WORK/home" PATH="$PATH" TERM=dumb NO_COLOR=1 DOTFILES_DIR="$WORK/none" XDG_RUNTIME_DIR="$WORK" \
  "$BASH_BIN" "$REPO_ROOT/scripts/ops/rollback.sh" backup </dev/null >/dev/null 2>&1
assert_file_exists "$WORK/home/.local/state/dot/doctor/rollback.log" "the plain log is written as before"
assert_contains "\"path\":\"$WORK/home/.local/state/dot/doctor/rollback.log\"" "$(grep '"event":"text_log"' "$LOG" 2>/dev/null)" "and log.v1 points at it"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
