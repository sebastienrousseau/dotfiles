#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# dot ai cost show (plan P1.3): the cockpit binary's cost report, built from
# defaults/dot_local/share/dot-ai-tui and run through bin/dot in a sandboxed
# home holding one Claude Code transcript (with a subagent) and one Codex
# rollout. The binary's own tests cover the pricing; this covers the route,
# the flags and the output a person and a script read.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v go >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: go and jq are needed"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-ai-cost.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
H="$WORK/home"
mkdir -p "$H/bin"
if ! (cd "$REPO_ROOT/defaults/dot_local/share/dot-ai-tui" && GOFLAGS=-mod=mod go build -o "$H/bin/dot-ai-tui" .) >"$WORK/build.log" 2>&1; then
  echo "SKIP: dot-ai-tui does not build here: $(tail -1 "$WORK/build.log")"
  echo "RESULTS:0:0:0"
  exit 0
fi

TODAY="$(date -u +%Y-%m-%d)"
P="$H/.claude/projects/-w-shop"
mkdir -p "$P/s-one/subagents" "$H/.codex/sessions/$(date +%Y/%m/%d)"
claude_line() { # SESSION ID MODEL INPUT OUTPUT
  printf '{"type":"assistant","sessionId":"%s","timestamp":"%sT10:00:00Z","message":{"id":"%s","model":"%s","usage":{"input_tokens":%s,"cache_creation_input_tokens":0,"cache_read_input_tokens":0,"output_tokens":%s}}}\n' \
    "$1" "$TODAY" "$2" "$3" "$4" "$5"
}
{
  claude_line s-one m1 claude-opus-5-5 1000000 0
  claude_line s-one m2 claude-sonnet-5-5 0 1000000
} >"$P/s-one.jsonl"
claude_line s-one m3 claude-haiku-5-5 100000 0 >"$P/s-one/subagents/agent-a.jsonl"
cat >"$H/.codex/sessions/$(date +%Y/%m/%d)/rollout-x-th-7.jsonl" <<JSONL
{"timestamp":"${TODAY}T08:00:00Z","type":"session_meta","payload":{"id":"th-7"}}
{"timestamp":"${TODAY}T08:00:01Z","type":"turn_context","payload":{"model":"gpt-5.5"}}
{"timestamp":"${TODAY}T08:00:05Z","type":"event_msg","payload":{"type":"token_count","info":{"total_token_usage":{"input_tokens":200000,"cached_input_tokens":0,"output_tokens":0}}}}
JSONL

cost() {
  RC=0
  OUT="$(env -i HOME="$H" PATH="$H/bin:/usr/bin:/bin" NO_COLOR=1 TERM=dumb LC_ALL=C \
    bash "$REPO_ROOT/bin/dot" ai cost "$@" 2>&1 </dev/null)" || RC=$?
}

test_start "cost_show_by_agent"
cost show
assert_equals "0" "$RC" "exit 0"
# Opus 5.5 $4, Sonnet 5.5 $10, the subagent's Haiku 5.5 $0.01; Codex gpt-5.5 $1.
assert_contains "claude" "$OUT" "claude"
assert_contains '$14.01' "$OUT" "claude's cost, its subagent included"
assert_contains '$1.00' "$OUT" "codex's"
assert_contains '$15.01' "$OUT" "the total"
assert_contains "not a bill" "$OUT" "says what the figure is"

test_start "cost_of_one_session"
cost show --session s-o
assert_equals "0" "$RC" "a unique prefix: exit 0"
assert_contains "Session s-one (claude)" "$OUT" "names it"
assert_contains "claude-haiku-5-5" "$OUT" "by model, the subagent's included"

test_start "cost_by_day_json"
cost show --by day --json
assert_equals "0|ai/cost-report.v1|$TODAY|15.01" \
  "$RC|$(jq -r .schema <<<"$OUT")|$(jq -r '.rows[0].key' <<<"$OUT")|$(jq -r '.total.cost_usd * 100 | round / 100' <<<"$OUT")" \
  "the report, by day"

test_start "cost_rejects_a_bad_flag"
cost show --by planet
assert_equals "1" "$RC" "exit 1"
assert_contains "usage: dot ai cost show" "$OUT" "usage"

test_start "the_cache_is_private"
cost show
# GNU stat first: on Linux, stat -f is the file system's status, and works.
mode="$(stat -c %a "$H/.cache/dot/ai/cost-index.json" 2>/dev/null || stat -f %Lp "$H/.cache/dot/ai/cost-index.json")"
assert_equals "600" "$mode" "0600"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
