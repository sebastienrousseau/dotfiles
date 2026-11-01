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

test_start "a_domain_that_is_not_a_name_logs_to_cli"
DOT_LOG_DOMAIN="../../escape" lib "$WORK/dn/state" 'dot_log info e' >/dev/null
DOT_LOG_DOMAIN="Theme" lib "$WORK/dn/state" 'dot_log info e' >/dev/null
assert_equals "cli" "$(ls "$WORK/dn/state/dot")" "only the cli log is written"
assert_equals "no" "$([[ -e "$WORK/dn/escape" || -e "$WORK/escape" ]] && echo yes || echo no)" "nothing is written outside the state dir"

test_start "readers_refuse_a_domain_that_is_not_a_name"
mkdir -p "$WORK/rd/dot/cli" "$WORK/rd/escape"
printf '{"event":"secret_x"}\n' >"$WORK/rd/escape/log.jsonl"
out="$(lib "$WORK/rd" 'dot_log_path ../escape; echo "path=$?"; dot_log_tail ../escape 5 secret_; echo "tail=$?"')"
assert_equals $'path=64\ntail=64' "$out" "dot_log_path and dot_log_tail return 64 and read nothing outside"

test_start "prune_says_so_when_date_cannot_compute_the_cutoff"
mkdir -p "$WORK/olddate"
printf '#!/bin/sh\nexit 1\n' >"$WORK/olddate/date"
chmod +x "$WORK/olddate/date"
out="$(PATH="$WORK/olddate:/usr/bin:/bin" lib "$S" 'dot_log_prune; echo "rc=$?"')"
assert_contains "the logs were not pruned" "$out" "a date without -d or -v is reported"
assert_contains "rc=1" "$out" "and prune fails, so the maintenance step shows it"

test_start "values_of_secret_keys_are_redacted"
out="$(lib "$S" 'dot_log_record info e token=abc API_KEY=k1 apikey=k2 Password=p client_secret=s auth=a name=dot count=3')"
for k in token API_KEY apikey Password client_secret auth; do
  assert_contains "\"$k\":\"***\"" "$out" "$k is written as ***"
done
assert_contains '"name":"dot","count":"3"' "$out" "other values are kept"
assert_false '[[ "$out" == *abc* ]]' "the secret value is not written"

test_start "prune_keeps_a_record_written_while_it_runs"
pr="$WORK/pr"
mkdir -p "$pr/state/dot/theme" "$pr/bin"
printf '%s\n' '{"schema":"cli/log.v1","time":"2020-01-01T00:00:00Z","event":"old"}' >"$pr/state/dot/theme/log.jsonl"
real_awk="$(command -v awk)"
# A stand-in awk: the real one, then a writer appending to the live log, as
# dot_log does from another process while prune runs.
printf '#!/bin/sh\n%s "$@"; rc=$?\nprintf "%%s\\n" "{\\"schema\\":\\"cli/log.v1\\",\\"time\\":\\"2099-01-01T00:00:00Z\\",\\"event\\":\\"during\\"}" >>"%s"\nexit $rc\n' \
  "$real_awk" "$pr/state/dot/theme/log.jsonl" >"$pr/bin/awk"
chmod +x "$pr/bin/awk"
PATH="$pr/bin:$PATH" lib "$pr/state" 'dot_log_prune' >/dev/null
assert_equals "0|1" "$(grep -c '"old"' "$pr/state/dot/theme/log.jsonl")|$(grep -c '"during"' "$pr/state/dot/theme/log.jsonl")" \
  "the old record goes and the one written during the prune stays"
assert_equals "0" "$(find "$pr/state/dot/theme" -name 'log.jsonl.*' | wc -l | tr -d ' ')" "no temporary file is left"

test_start "prune_keeps_a_write_to_the_renamed_log"
# A writer that opened the log before the prune renamed it appends to the
# renamed file after the prune read it: this awk writes there once it ran.
printf '%s\n' '{"schema":"cli/log.v1","time":"2020-01-01T00:00:00Z","event":"old"}' >"$pr/state/dot/theme/log.jsonl"
printf '#!/bin/sh\n%s "$@"; rc=$?\nfor f in "%s".prune.*; do printf "%%s\\n" "{\\"time\\":\\"2099-01-01T00:00:00Z\\",\\"event\\":\\"late\\"}" >>"$f"; done\nexit $rc\n' \
  "$real_awk" "$pr/state/dot/theme/log.jsonl" >"$pr/bin/awk"
PATH="$pr/bin:$PATH" lib "$pr/state" 'dot_log_prune' >/dev/null
assert_equals "0|1" "$(grep -c '"old"' "$pr/state/dot/theme/log.jsonl")|$(grep -c '"late"' "$pr/state/dot/theme/log.jsonl")" \
  "a record written to the renamed log after it was read is kept"

test_start "prune_adopts_what_a_dead_prune_left"
printf '%s\n' '{"schema":"cli/log.v1","time":"2099-01-01T00:00:00Z","event":"stranded"}' >"$pr/state/dot/theme/log.jsonl.prune.999999999"
printf '%s\n' '{"schema":"cli/log.v1","time":"2099-01-02T00:00:00Z","event":"current"}' >"$pr/state/dot/theme/log.jsonl"
lib "$pr/state" 'dot_log_prune' >/dev/null
assert_equals "stranded current" "$(grep -o '"event":"[a-z]*"' "$pr/state/dot/theme/log.jsonl" | cut -d'"' -f4 | tr '\n' ' ' | sed 's/ $//')" \
  "the stranded records come back, in front"
assert_equals "0" "$(find "$pr/state/dot/theme" -name 'log.jsonl.*' | wc -l | tr -d ' ')" "and the leftover file goes"

test_start "one_prune_at_a_time"
mkdir -p "$pr/state/dot/log"
sleep 30 &
pruner=$!
ln -sfn "$pruner" "$pr/state/dot/log/lock"
out="$(lib "$pr/state" 'dot_log_prune; echo "rc=$?"')"
kill "$pruner" 2>/dev/null
assert_contains "rc=75" "$out" "a second prune exits 75 while one holds the log lock"
rm -f "$pr/state/dot/log/lock"

test_start "a_prune_that_fails_restores_the_log"
printf '%s\n' '{"schema":"cli/log.v1","time":"2020-01-01T00:00:00Z","event":"old"}' >"$pr/state/dot/theme/log.jsonl"
# This awk fails after a writer appended, so nothing may be lost.
printf '#!/bin/sh\nprintf "%%s\\n" "{\\"event\\":\\"during\\"}" >>"%s"\nexit 1\n' \
  "$pr/state/dot/theme/log.jsonl" >"$pr/bin/awk"
PATH="$pr/bin:$PATH" lib "$pr/state" 'dot_log_prune' >/dev/null
assert_equals "1|1" "$(grep -c '"old"' "$pr/state/dot/theme/log.jsonl")|$(grep -c '"during"' "$pr/state/dot/theme/log.jsonl")" \
  "the log is put back whole, with the record written meanwhile"
assert_equals "0" "$(find "$pr/state/dot/theme" -name 'log.jsonl.*' | wc -l | tr -d ' ')" "and nothing temporary is left"

test_start "logs_and_checkpoints_are_private"
mode() { stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"; }
(umask 022 && lib "$WORK/perm" 'dot_log info e; DOT_AGENT_CHECKPOINT_ID=cpp dot_agent_checkpoint_create plan; umask') >"$WORK/perm.out"
assert_equals "600|700" "$(mode "$WORK/perm/dot/cli/log.jsonl")|$(mode "$WORK/perm/dot/cli")" "a new log is 0600 in a 0700 dir"
assert_equals "600" "$(mode "$WORK/perm/dotfiles/checkpoints/cpp.json")" "a checkpoint is 0600"
assert_equals "0022" "$(tail -n 1 "$WORK/perm.out")" "and the caller's umask is put back"

test_start "an_orphan_whose_suffix_is_not_a_pid_is_left"
mkdir -p "$WORK/orph/dot/theme"
printf '%s\n' '{"event":"keep"}' >"$WORK/orph/dot/theme/log.jsonl"
printf '%s\n' '{"event":"odd"}' >"$WORK/orph/dot/theme/log.jsonl.prune.abc"
lib "$WORK/orph" 'dot_log_prune' >/dev/null
assert_file_exists "$WORK/orph/dot/theme/log.jsonl.prune.abc" "a suffix that is not a PID is never passed to kill"
assert_equals "0" "$(grep -c odd "$WORK/orph/dot/theme/log.jsonl")" "and its file is not adopted"

test_start "debug_events_need_verbose_or_a_level"
lib "$WORK/lv" 'dot_log debug d1' >/dev/null
DOT_VERBOSE=1 lib "$WORK/lv" 'dot_log debug d2' >/dev/null
DOT_VERBOSE=1 DOT_LOG_LEVEL=warn lib "$WORK/lv" 'dot_log info d3' >/dev/null
assert_equals "d2" "$(grep -o '"event":"d[0-9]"' "$WORK/lv/dot/cli/log.jsonl" | cut -d'"' -f4 | tr '\n' ' ' | sed 's/ $//')" \
  "debug is written with -v (DOT_VERBOSE) only, and DOT_LOG_LEVEL overrides -v"

test_start "values_are_escaped_and_control_bytes_dropped"
out="$(lib "$S" $'dot_log_record info e \'q=say "hi"\' \'b=a\\b\' "nl=one\ntwo" "ctl=a\x01b\x1fc"')"
assert_contains '"q":"say \"hi\""' "$out" "quotes are escaped"
assert_contains '"b":"a\\b"' "$out" "backslashes are escaped"
assert_contains '"nl":"one\ntwo"' "$out" "newlines become \\n"
assert_contains '"ctl":"abc"' "$out" "other control bytes are dropped"
assert_equals "1" "$(printf '%s\n' "$out" | wc -l | tr -d ' ')" "and the record stays one line"

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
assert_false '[[ "$out" == *'"'"'"name":"startup"'"'"'* ]]' "and only the last one"

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

test_start "the_checkpoint_fallback_escapes_its_fields"
f="$(PATH="$NOJQ" DOT_AGENT_CHECKPOINT_ID=cpq DOT_COMMAND='a"b' lib "$S" 'dot_agent_checkpoint_create '"'"'pro"file'"'"' "st\\at"')"
assert_file_contains "$f" '"profile":"pro\"file","status":"st\\at"' "quotes and backslashes are escaped"
assert_file_contains "$f" '"command":"a\"b"}' "in every field"

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
