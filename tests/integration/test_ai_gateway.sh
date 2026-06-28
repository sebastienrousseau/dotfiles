#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
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

WORK="$(mktemp -d)"
PIDS=()
cleanup() {
  for p in "${PIDS[@]:-}"; do kill "$p" 2>/dev/null || true; done
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

free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }

# start_server <var-prefix> [ENV=val ...] — sets ${prefix}_PORT, appends PID.
start_server() {
  local port
  port="$(free_port)"
  # Default bin first (so "$@" can override it); host/port last (fixed).
  env DOT_AI_CLAUDE_BIN="$MOCK" "$@" DOT_AI_HOST=127.0.0.1 DOT_AI_PORT="$port" \
    python3 "$GATEWAY" >"$WORK/srv-$port.log" 2>&1 &
  PIDS+=("$!")
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

GET() { curl -fsS "$@" 2>/dev/null; }
POST() { curl -fsS -X POST -H 'Content-Type: application/json' "$@" 2>/dev/null; }

# ───────────────────────── main server ─────────────────────────
PORT="$(start_server)"
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
ERRPORT="$(start_server DOT_AI_CLAUDE_BIN="$MOCKERR")"
# override the per-call bin by pointing the whole server at the error mock
code="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
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
BPORT="$(start_server DOT_AI_DAILY_BUDGET=0.0000001)"
# First request runs (spent starts at 0), pushing spend over the tiny cap.
POST "http://127.0.0.1:$BPORT/v1/messages" -d '{"model":"sonnet","messages":[{"role":"user","content":"hi"}]}' >/dev/null
overcode="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
  "http://127.0.0.1:$BPORT/v1/messages" -d '{"model":"sonnet","messages":[{"role":"user","content":"hi"}]}')"
assert_equals "429" "$overcode" "second request over budget returns 429"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
