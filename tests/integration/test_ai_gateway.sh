#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Integration test for the dot-ai-serve gateway (Phase 2/3). Starts the real
# stdlib server against a mock `claude` CLI and exercises both protocols,
# streaming, observability, auth, budget, model routing, and graceful
# handling of tools/images.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

GATEWAY="$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai-serve"

# Skip cleanly where the toolchain isn't available.
if ! command -v python3 >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1; then
  echo "RESULTS:0:0:0"
  exit 0
fi

if ! python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));s.close()' >/dev/null 2>&1; then
  echo "SKIP: loopback port binding is unavailable in this environment"
  echo "RESULTS:0:0:0"
  exit 0
fi

WORK="$(mktemp -d)"
# Keep the auto-generated gateway token out of the real state dir.
export XDG_STATE_HOME="$WORK/state"
cleanup() {
  # start_server runs inside $(...), so its PIDs are recorded in a file.
  local p
  while read -r p; do kill "$p" 2>/dev/null || true; done <"$WORK/pids" 2>/dev/null
  rm -rf "$WORK"
}
trap cleanup EXIT

# ── mock claude CLI: emits stream-json (two assistant snapshots → deltas) ──
MOCK="$WORK/claude"
cat >"$MOCK" <<'MK'
#!/usr/bin/env bash
cat >/dev/null   # consume the prompt on stdin
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"Hello"}]}}'
printf '%s\n' '{"type":"assistant","message":{"content":[{"type":"text","text":"Hello world"}]}}'
printf '%s\n' '{"type":"result","is_error":false,"result":"Hello world","usage":{"input_tokens":10,"output_tokens":5}}'
MK
chmod +x "$MOCK"

# mock that reports an engine error
MOCKERR="$WORK/claude-err"
cat >"$MOCKERR" <<'MK'
#!/usr/bin/env bash
cat >/dev/null
printf '%s\n' '{"type":"result","is_error":true,"result":"boom from engine","usage":{}}'
MK
chmod +x "$MOCKERR"

# mock that records its argv and working directory
MOCKREC="$WORK/claude-rec"
cat >"$MOCKREC" <<MK
#!/usr/bin/env bash
cat >/dev/null
{ printf 'cwd=%s\n' "\$PWD"; printf 'arg=[%s]\n' "\$@"; } >"$WORK/rec.log"
printf '%s\n' '{"type":"result","is_error":false,"result":"ok","usage":{}}'
MK
chmod +x "$MOCKREC"

free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }

# start_server <var-prefix> [ENV=val ...] — sets ${prefix}_PORT, appends PID.
start_server() {
  local port
  port="$(free_port)"
  # Default bin first (so "$@" can override it); host/port last (fixed).
  env DOT_AI_CLAUDE_BIN="$MOCK" "$@" DOT_AI_HOST=127.0.0.1 DOT_AI_PORT="$port" \
    python3 "$GATEWAY" >"$WORK/srv-$port.log" 2>&1 &
  echo "$!" >>"$WORK/pids"
  local i
  for i in $(seq 1 50); do
    curl -fsS "http://127.0.0.1:$port/health" >/dev/null 2>&1 && {
      echo "$port"
      return 0
    }
    sleep 0.1
  done
  echo "0"
  return 1
}

KEY="main-test-key"
GET() { curl -fsS -H "x-api-key: $KEY" "$@" 2>/dev/null; }
POST() { curl -fsS -X POST -H 'Content-Type: application/json' -H "x-api-key: $KEY" "$@" 2>/dev/null; }
code_of() { curl -s -o /dev/null -w '%{http_code}' "$@"; }

# ───────────────────────── main server ─────────────────────────
PORT="$(start_server DOT_AI_API_KEY="$KEY")"
BASE="http://127.0.0.1:$PORT"

test_start "gateway_starts_and_is_healthy"
assert_not_equals "0" "$PORT" "server should bind a port"
health="$(GET "$BASE/health")"
assert_contains "healthy" "$health" "/health reports healthy with a found engine"
assert_contains '"streaming": true' "$health" "/health advertises streaming"

test_start "models_endpoint"
models="$(GET "$BASE/v1/models")"
assert_contains "claude-opus-4-8" "$models" "/v1/models lists the fleet"

test_start "anthropic_non_streaming"
resp="$(POST "$BASE/v1/messages" -d '{"model":"sonnet","messages":[{"role":"user","content":"hi"}]}')"
assert_contains "Hello world" "$resp" "anthropic response carries the text"
assert_contains '"output_tokens": 5' "$resp" "anthropic response carries usage"

test_start "openai_non_streaming"
resp="$(POST "$BASE/v1/chat/completions" -d '{"model":"gpt-4","messages":[{"role":"user","content":"hi"}]}')"
assert_contains "Hello world" "$resp" "openai response carries the text"
assert_contains '"total_tokens": 15' "$resp" "openai response totals tokens"

test_start "anthropic_streaming_deltas"
# Two snapshots → two text deltas ("Hello" then " world"): real streaming.
sse="$(POST "$BASE/v1/messages" -d '{"model":"sonnet","stream":true,"messages":[{"role":"user","content":"hi"}]}')"
assert_contains "message_start" "$sse" "SSE opens with message_start"
deltas="$(printf '%s\n' "$sse" | grep -c '^event: content_block_delta')"
assert_equals "2" "$deltas" "two incremental text deltas (token streaming)"
assert_contains "message_stop" "$sse" "SSE closes with message_stop"

test_start "openai_streaming"
sse="$(POST "$BASE/v1/chat/completions" -d '{"model":"sonnet","stream":true,"messages":[{"role":"user","content":"hi"}]}')"
assert_contains "chat.completion.chunk" "$sse" "openai SSE chunks"
assert_contains "[DONE]" "$sse" "openai SSE terminates with [DONE]"

test_start "multimodal_image_acknowledged"
resp="$(POST "$BASE/v1/messages" -d '{"model":"sonnet","messages":[{"role":"user","content":[{"type":"text","text":"look"},{"type":"image","source":{}}]}]}')"
assert_contains "Hello world" "$resp" "image request still returns a text answer"

test_start "tools_request_answered_in_text"
resp="$(POST "$BASE/v1/chat/completions" -d '{"model":"sonnet","messages":[{"role":"user","content":"hi"}],"tools":[{"type":"function","function":{"name":"x"}}]}')"
assert_contains "Hello world" "$resp" "tools request degrades to a text answer"

test_start "observability_usage_and_metrics"
usage="$(GET "$BASE/v1/usage")"
assert_contains '"object": "usage"' "$usage" "/v1/usage is a usage report"
assert_contains '"requests":' "$usage" "/v1/usage counts requests"
metrics="$(GET "$BASE/metrics")"
assert_contains "dot_ai_requests_total" "$metrics" "/metrics emits prometheus counters"
assert_contains "dot_ai_cost_usd_total" "$metrics" "/metrics emits cost"

test_start "model_routing_records_resolved_model"
# gpt-4 routes to sonnet; usage should attribute to the resolved model.
usage="$(GET "$BASE/v1/usage")"
assert_contains "sonnet" "$usage" "by_model attributes to the resolved (sonnet) model"

test_start "engine_error_surfaces_502"
ERRPORT="$(start_server DOT_AI_CLAUDE_BIN="$MOCKERR" DOT_AI_API_KEY="$KEY")"
# override the per-call bin by pointing the whole server at the error mock
code="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -H "x-api-key: $KEY" \
  "http://127.0.0.1:$ERRPORT/v1/messages" -d '{"model":"sonnet","messages":[{"role":"user","content":"hi"}]}')"
assert_equals "502" "$code" "engine error returns 502"

# ───────────────────────── auth server ─────────────────────────
test_start "api_key_gate"
APORT="$(start_server DOT_AI_API_KEY=s3cret)"
nocode="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
  "http://127.0.0.1:$APORT/v1/messages" -d '{"messages":[{"role":"user","content":"hi"}]}')"
assert_equals "401" "$nocode" "missing key is rejected"
okcode="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
  -H 'x-api-key: s3cret' "http://127.0.0.1:$APORT/v1/messages" \
  -d '{"model":"sonnet","messages":[{"role":"user","content":"hi"}]}')"
assert_equals "200" "$okcode" "valid key is accepted"

# ──────────────────────── budget server ────────────────────────
test_start "daily_budget_cap"
BPORT="$(start_server DOT_AI_DAILY_BUDGET=0.0000001 DOT_AI_API_KEY="$KEY")"
# First request runs (spent starts at 0), pushing spend over the tiny cap.
POST "http://127.0.0.1:$BPORT/v1/messages" -d '{"model":"sonnet","messages":[{"role":"user","content":"hi"}]}' >/dev/null
overcode="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' -H "x-api-key: $KEY" \
  "http://127.0.0.1:$BPORT/v1/messages" -d '{"model":"sonnet","messages":[{"role":"user","content":"hi"}]}')"
assert_equals "429" "$overcode" "second request over budget returns 429"

# ─────────────── default auth: generated token ───────────────
body='{"model":"sonnet","messages":[{"role":"user","content":"hi"}]}'
TOKEN_FILE="$XDG_STATE_HOME/dotfiles/ai-serve/gateway.token"
DPORT="$(start_server)"

test_start "default_requires_token"
code="$(code_of -X POST -H 'Content-Type: application/json' "http://127.0.0.1:$DPORT/v1/messages" -d "$body")"
assert_equals "401" "$code" "no DOT_AI_API_KEY still requires a key"

test_start "default_token_file_private"
perms="$(stat -f '%Lp' "$TOKEN_FILE" 2>/dev/null || stat -c '%a' "$TOKEN_FILE" 2>/dev/null)"
assert_equals "600" "$perms" "generated token file is 0600"

test_start "default_token_accepted"
tok="$(cat "$TOKEN_FILE" 2>/dev/null)"
code="$(code_of -X POST -H 'Content-Type: application/json' -H "authorization: Bearer $tok" \
  "http://127.0.0.1:$DPORT/v1/messages" -d "$body")"
assert_equals "200" "$code" "generated token is accepted as a bearer token"

test_start "print_token_matches_file"
printed="$(perl -e 'alarm 10; exec @ARGV' python3 "$GATEWAY" --print-token 2>/dev/null)"
assert_equals "$tok" "$printed" "--print-token prints the same token"

test_start "wrong_token_rejected"
code="$(code_of -X POST -H 'Content-Type: application/json' -H 'x-api-key: nope' \
  "http://127.0.0.1:$DPORT/v1/messages" -d "$body")"
assert_equals "401" "$code" "wrong key is rejected"

test_start "metrics_require_token"
code="$(code_of "http://127.0.0.1:$DPORT/metrics")"
assert_equals "401" "$code" "/metrics needs the key"

# ─────────────── DNS rebinding: Host allowlist ───────────────
test_start "foreign_host_rejected"
code="$(code_of -H 'Host: attacker.example:'"$DPORT" "http://127.0.0.1:$DPORT/health")"
assert_equals "403" "$code" "foreign Host header is refused"

test_start "foreign_host_rejected_with_key"
code="$(code_of -X POST -H 'Host: attacker.example' -H 'Content-Type: application/json' \
  -H "x-api-key: $tok" "http://127.0.0.1:$DPORT/v1/messages" -d "$body")"
assert_equals "403" "$code" "foreign Host is refused even with a valid key"

test_start "localhost_host_allowed"
code="$(code_of -H "Host: localhost:$DPORT" "http://127.0.0.1:$DPORT/health")"
assert_equals "200" "$code" "localhost:PORT Host is allowed"

# ─────────────── hermetic engine invocation ───────────────
RPORT="$(start_server DOT_AI_CLAUDE_BIN="$MOCKREC" DOT_AI_API_KEY="$KEY")"
POST "http://127.0.0.1:$RPORT/v1/messages" -d "$body" >/dev/null

test_start "engine_tools_disabled"
assert_contains "arg=[--tools]" "$(cat "$WORK/rec.log" 2>/dev/null)" "claude gets --tools"
test_start "engine_tools_empty"
tools_val="$(grep -A1 -F 'arg=[--tools]' "$WORK/rec.log" 2>/dev/null | tail -n 1)"
assert_equals "arg=[]" "$tools_val" "--tools is empty (all tools disabled)"

test_start "engine_runs_in_empty_dir"
engine_cwd="$(sed -n 's/^cwd=//p' "$WORK/rec.log" 2>/dev/null)"
assert_not_equals "$(pwd -P)" "$engine_cwd" "engine does not run in the server cwd"
test_start "engine_cwd_cleaned_up"
if [[ -n "$engine_cwd" && ! -e "$engine_cwd" ]]; then
  assert_exit_code 0 "true"
else
  assert_exit_code 0 "false  # engine cwd left behind: $engine_cwd"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
