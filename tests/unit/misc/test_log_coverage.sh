#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Behavioural coverage for lib/dot/log.sh: file logging + rotation, JSON
# stdout logging, metrics, agent session log, checkpoints (jq and no-jq
# forms), the ui_* wrappers, and the unwritable-state-dir early returns.
# Every write lands in a mktemp XDG_STATE_HOME; nothing else is touched.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

LOG_LIB="$REPO_ROOT/lib/dot/log.sh"
REAL_BASH="${BASH:-$(command -v bash)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/log-cov.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# lib <state-home> <snippet> — source log.sh in a fresh bash and run snippet.
lib() {
  local state="$1" snippet="$2"
  XDG_STATE_HOME="$state" HOME="$WORK/home" DOT_TRACE_ID="trace42" \
    "$REAL_BASH" -c "source '$LOG_LIB'; $snippet" 2>&1
}

S="$WORK/state"
D="$S/dotfiles"

test_start "reload_guard_keeps_trace_id"
out="$(lib "$S" 'a=$DOT_TRACE_ID; DOT_TRACE_ID=changed; source "'"$LOG_LIB"'"; echo "$a $DOT_TRACE_ID"')"
assert_equals "trace42 changed" "$out" "re-sourcing is a no-op"

test_start "file_log_and_rotation"
mkdir -p "$D"
head -c 1048600 /dev/zero >"$D/dot.log"
lib "$S" 'dot_log_file info evt a=1 b=2' >/dev/null
assert_file_exists "$D/dot.log.1" "oversized log is rotated"
assert_file_contains "$D/dot.log" "[info] [trace42] evt a=1 b=2" "new log line written"

test_start "json_stdout_log"
out="$(DOTFILES_JSON_LOG=1 DOT_COMMAND=cov lib "$S" 'dot_log warn thing k=v x=y')"
assert_contains '"level":"warn","event":"thing","command":"cov","trace_id":"trace42","k":"v","x":"y"}' "$out" "JSON line emitted"
out="$(lib "$S" 'dot_log info quiet')"
assert_empty "$out" "silent without DOTFILES_JSON_LOG"

test_start "metrics_and_summary"
out="$(lib "$WORK/fresh" 'dot_metrics_summary')"
assert_contains "No metrics collected yet." "$out" "empty metrics state"
lib "$S" 'dot_metric startup 142; dot_metric size 3 kb' >/dev/null
out="$(lib "$S" 'dot_metrics_summary 1')"
assert_contains '"metric":"size","value":3,"unit":"kb"' "$out" "last metric shown"

test_start "agent_session_log_and_tail"
out="$(lib "$WORK/fresh2" 'dot_agent_session_tail')"
assert_contains "No agent sessions recorded yet." "$out" "empty session state"
lib "$S" 'dot_agent_session_log start plan ok tool=claude; dot_agent_session_log stop plan' >/dev/null
out="$(lib "$S" 'dot_agent_session_tail 5')"
assert_contains '"event":"start","profile":"plan","status":"ok"' "$out" "session recorded"
assert_contains '"tool":"claude"}' "$out" "extra fields appended"

test_start "checkpoint_with_jq"
if command -v jq >/dev/null 2>&1; then
  f="$(DOT_AGENT_CHECKPOINT_ID=cp1 DOT_AGENT_NETWORK=off lib "$S" 'dot_agent_checkpoint_create apply ready one "two words"')"
  assert_file_exists "$f" "checkpoint written"
  assert_equals '["one","two words"]' "$(jq -c .argv "$f")" "argv captured"
  assert_equals "off" "$(jq -r .env.network "$f")" "env captured"
else
  f="$(DOT_AGENT_CHECKPOINT_ID=cp1 lib "$S" 'dot_agent_checkpoint_create apply ready')"
  assert_file_exists "$f" "checkpoint written"
fi

test_start "checkpoint_without_jq"
NOJQ="$WORK/nojq"
mkdir -p "$NOJQ"
for c in date mkdir tail head cat find sort; do
  ln -s "$(command -v "$c")" "$NOJQ/$c"
done
f="$(PATH="$NOJQ" DOT_AGENT_CHECKPOINT_ID=cp2 DOT_COMMAND=agent lib "$S" 'dot_agent_checkpoint_create ask')"
assert_file_contains "$f" '{"id":"cp2","created_at":' "printf fallback used"
assert_file_contains "$f" '"profile":"ask","status":"ready","trace_id":"trace42","command":"agent"}' "fallback fields"

test_start "checkpoint_tail"
out="$(lib "$S" 'dot_agent_checkpoint_tail 5')"
assert_contains '"id": "cp1"' "$out" "first checkpoint listed"
assert_contains '"id":"cp2"' "$out" "second checkpoint listed"
out="$(lib "$WORK/none" 'dot_agent_checkpoint_tail; echo rc=$?')"
assert_equals "rc=0" "$out" "no checkpoint dir is fine"
assert_equals "$WORK/none/dotfiles/checkpoints" "$(lib "$WORK/none" dot_agent_checkpoint_dir)" "dir helper"

test_start "unwritable_state_dir_returns_quietly"
: >"$WORK/blocker"
out="$(lib "$WORK/blocker" 'dot_jsonl_append x.jsonl "{}"; echo a=$?; dot_log_file info e; echo b=$?; dot_metric m 1; echo c=$?; dot_agent_checkpoint_create p; echo d=$?')"
assert_contains "a=0" "$out" "jsonl append returns 0"
assert_contains "b=0" "$out" "file log returns 0"
assert_contains "c=0" "$out" "metric returns 0"
assert_contains "d=0" "$out" "checkpoint returns 0"

test_start "unwritable_log_files_are_ignored"
U="$WORK/unwritable"
mkdir -p "$U/dotfiles/dot.log" "$U/dotfiles/metrics.jsonl"
out="$(lib "$U" 'dot_log_file info e x=1; echo a=$?; dot_metric m 1; echo b=$?')"
assert_contains "a=0" "$out" "a log path that cannot be appended to is ignored"
assert_contains "b=0" "$out" "a metrics path that cannot be appended to is ignored"

test_start "semantic_wrappers_call_ui"
out="$(lib "$S" 'ui_info(){ echo "I:$*"; }; ui_warn(){ echo "W:$*"; }; ui_err(){ echo "E:$*"; }; ui_ok(){ echo "O:$*"; }; log_info a b; log_warn c; log_error d; log_success e')"
assert_equals $'I:a b\nW:c\nE:d\nO:e' "$out" "wrappers delegate to ui_*"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
