#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Behavioural coverage for lib/dot/log.sh: log.v1 events in each domain's
# log (tests/unit/dot-cli/test_log_v1_schema.py checks them against the
# schema), JSON stdout logging, metrics, agent session log, checkpoints (jq
# and no-jq forms), the ui_* wrappers, and the unwritable-state-dir returns.
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

test_start "reload_guard_keeps_trace_id"
out="$(lib "$S" 'a=$DOT_TRACE_ID; DOT_TRACE_ID=changed; source "'"$LOG_LIB"'"; echo "$a $DOT_TRACE_ID"')"
assert_equals "trace42 changed" "$out" "re-sourcing is a no-op"

test_start "events_go_to_the_domain_log"
lib "$S" 'dot_log info evt a=1 b=2; DOT_LOG_DOMAIN=theme dot_log info themed' >/dev/null
assert_file_contains "$S/dot/cli/log.jsonl" '"level":"info","domain":"cli","event":"evt"' "an event outside a domain goes to cli"
assert_file_contains "$S/dot/cli/log.jsonl" '"trace_id":"trace42"' "with the trace id"
assert_file_contains "$S/dot/cli/log.jsonl" '"data":{"a":"1","b":"2"}}' "and its fields"
assert_file_contains "$S/dot/theme/log.jsonl" '"event":"themed"' "DOT_LOG_DOMAIN picks the domain's log"
assert_equals "$S/dot/fleet/log.jsonl" "$(lib "$S" 'dot_log_path fleet')" "dot_log_path names a domain's log"

test_start "json_stdout_log"
out="$(DOTFILES_JSON_LOG=1 DOT_COMMAND=cov lib "$S" 'dot_log warn thing k=v x=y')"
assert_contains '"level":"warn","domain":"cli","event":"thing","command":"cov","trace_id":"trace42"' "$out" "JSON line emitted"
assert_contains '"data":{"k":"v","x":"y"}}' "$out" "with its fields"
out="$(lib "$S" 'dot_log info quiet')"
assert_empty "$out" "silent without DOTFILES_JSON_LOG"

test_start "metrics_and_summary"
out="$(lib "$WORK/fresh" 'dot_metrics_summary')"
assert_contains "No metrics collected yet." "$out" "empty metrics state"
lib "$S" 'dot_metric startup 142; dot_metric size 3 kb' >/dev/null
out="$(lib "$S" 'dot_metrics_summary 1')"
assert_contains '"event":"metric"' "$out" "last metric shown"
assert_contains '"data":{"name":"size","value":"3","unit":"kb"}}' "$out" "with its name, value and unit"
assert_not_contains '"name":"startup"' "$out" "and only the last one"

test_start "agent_session_log_and_tail"
out="$(lib "$WORK/fresh2" 'dot_agent_session_tail')"
assert_contains "No agent sessions recorded yet." "$out" "empty session state"
# Nothing recorded is not an error: `dot agent sessions` must exit 0.
out="$(lib "$WORK/fresh3" 'dot_agent_session_tail; echo "rc=$?"')"
assert_contains "rc=0" "$out" "an empty session log exits 0"
lib "$S" 'dot_agent_session_log start plan ok tool=claude; dot_agent_session_log stop plan' >/dev/null
out="$(lib "$S" 'dot_agent_session_tail 5')"
assert_contains '"domain":"agent","event":"session_start"' "$out" "session recorded in the agent log"
assert_contains '"data":{"profile":"plan","status":"ok","tool":"claude"}}' "$out" "extra fields appended"

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
out="$(lib "$WORK/blocker" 'dot_jsonl_append x.jsonl "{}"; echo a=$?; dot_log info e; echo b=$?; dot_metric m 1; echo c=$?; dot_agent_checkpoint_create p; echo d=$?')"
assert_contains "a=0" "$out" "jsonl append returns 0"
assert_contains "b=0" "$out" "file log returns 0"
assert_contains "c=0" "$out" "metric returns 0"
assert_contains "d=0" "$out" "checkpoint returns 0"

test_start "unwritable_log_files_are_ignored"
U="$WORK/unwritable"
mkdir -p "$U/dot/cli/log.jsonl" "$U/dot/doctor/log.jsonl"
out="$(lib "$U" 'dot_log info e x=1; echo a=$?; DOT_LOG_DOMAIN=doctor dot_metric m 1; echo b=$?')"
assert_contains "a=0" "$out" "a log path that cannot be appended to is ignored"
assert_contains "b=0" "$out" "a metrics path that cannot be appended to is ignored"

test_start "semantic_wrappers_call_ui"
out="$(lib "$S" 'ui_info(){ echo "I:$*"; }; ui_warn(){ echo "W:$*"; }; ui_err(){ echo "E:$*"; }; ui_ok(){ echo "O:$*"; }; log_info a b; log_warn c; log_error d; log_success e')"
assert_equals $'I:a b\nW:c\nE:d\nO:e' "$out" "wrappers delegate to ui_*"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
