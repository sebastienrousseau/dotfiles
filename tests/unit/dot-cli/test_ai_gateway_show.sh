#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# dot ai gateway show (plugins/ai/libexec/gateway.sh, plan P1.2): the
# running gateway's statistics from its /v1/usage, read with the gateway's
# own token. Runs the real dot-ai-serve on a free loopback port against a
# mock engine, through bin/dot in a sandboxed home.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v python3 >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
  echo "SKIP: python3, curl and jq are needed"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-gw-show.XXXXXX")"
PID=""
trap '[[ -z "$PID" ]] || kill "$PID" 2>/dev/null; rm -rf "$WORK"' EXIT
H="$WORK/home"
STATE="$H/.local/state"
mkdir -p "$STATE"
COV_ENV=()
for v in BASH_ENV PS4 COV_TRACE_FILE COV_ROOT; do
  [[ -z "${!v:-}" ]] || COV_ENV+=("$v=${!v}")
done

cat >"$WORK/claude" <<'EOF'
#!/bin/sh
cat >/dev/null
printf '%s\n' '{"type":"result","is_error":false,"result":"hi","usage":{"input_tokens":1000,"output_tokens":20}}'
EOF
chmod +x "$WORK/claude"
PORT="$(python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()')"

# The gateway keeps its token in $XDG_STATE_HOME/dot/ai/serve/gateway.token.
env XDG_STATE_HOME="$STATE" DOT_AI_CLAUDE_BIN="$WORK/claude" DOT_AI_PORT="$PORT" DOT_AI_DAILY_BUDGET=5 \
  DOT_AI_POLICY="$WORK/no-policy.toml" python3 "$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai-serve" \
  >"$WORK/serve.log" 2>&1 &
PID=$!
for _ in $(seq 1 50); do
  [[ -s "$STATE/dot/ai/serve/gateway.token" ]] && curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && break
  sleep 0.1
done
KEY="$(cat "$STATE/dot/ai/serve/gateway.token")"
ask() {
  curl -fsS -H "x-api-key: $KEY" -H 'Content-Type: application/json' "http://127.0.0.1:$PORT$1" -d "$2" >/dev/null
}
ask /v1/messages '{"model":"haiku","messages":[{"role":"user","content":"a"}]}'
ask /v1/messages '{"model":"haiku","stream":true,"messages":[{"role":"user","content":"b"}]}'
ask /v1/chat/completions '{"model":"sonnet","messages":[{"role":"user","content":"c"}]}'

# show ARGS...: `dot ai gateway show ARGS...`; sets RC and OUT (stdout and
# stderr). Extra NAME=value pairs go in E.
E=()
show() {
  RC=0
  OUT="$(env -i ${COV_ENV[@]+"${COV_ENV[@]}"} HOME="$H" XDG_STATE_HOME="$STATE" PATH="/usr/bin:/bin:$(dirname "$(command -v jq)")" \
    NO_COLOR=1 TERM=dumb LC_ALL=C DOT_AI_PORT="$PORT" ${E[@]+"${E[@]}"} \
    bash "$REPO_ROOT/bin/dot" ai gateway show "$@" 2>&1 </dev/null)" || RC=$?
}

test_start "show_summarises_the_running_gateway"
show
assert_equals "0" "$RC" "exit 0"
assert_contains "gateway      http://127.0.0.1:$PORT, up " "$OUT" "where it runs"
assert_contains "requests     3, 0 errors, 1 streamed" "$OUT" "its requests"
assert_contains "tokens       3000 in, 60 out" "$OUT" "its tokens"
assert_contains "images       0" "$OUT" "images"
assert_contains "tool calls   0" "$OUT" "tool calls"
assert_contains 'cost         $0.0051 estimated; today $0.0051 of $5.00' "$OUT" "its cost against the budget"
assert_contains 'haiku        2 requests, $0.0018' "$OUT" "per model"
assert_contains 'sonnet       1 request, $0.0033' "$OUT" "one request is singular"

test_start "json_is_the_usage_report"
show --json
assert_equals "0|ai/gateway-usage.v1|3" "$RC|$(jq -r '.schema' <<<"$OUT")|$(jq -r '.requests' <<<"$OUT")" "the report, with its schema id"

test_start "the_api_key_wins_over_the_token_file"
E=(DOT_AI_API_KEY=wrong)
show
assert_equals "1" "$RC" "a key the gateway refuses: exit 1"
assert_contains "the gateway refused the key" "$OUT" "says so"

test_start "a_gateway_that_is_not_running"
kill "$PID" 2>/dev/null
wait "$PID" 2>/dev/null
PID=""
E=()
show
assert_equals "1" "$RC" "exit 1"
assert_contains "no gateway answers on http://127.0.0.1:$PORT" "$OUT" "says where it looked"
assert_contains "dot ai gateway serve" "$OUT" "and how to start one"

test_start "no_token_at_all"
rm -f "$STATE/dot/ai/serve/gateway.token"
show
assert_equals "1" "$RC" "exit 1"
assert_contains "no gateway token" "$OUT" "says what is missing"

test_start "gateway_sh_rejects_another_word"
RC=0
OUT="$(bash "$REPO_ROOT/plugins/ai/libexec/gateway.sh" frob 2>&1)" || RC=$?
assert_equals "1" "$RC" "exit 1"
assert_contains "Usage: dot ai gateway show [--json]" "$OUT" "usage"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
