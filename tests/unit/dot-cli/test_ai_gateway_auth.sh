#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# The gateway's upstream auth (dot-ai-serve resolve_auth, dot-ai-proxy
# start): an Anthropic API key by default; a Claude subscription only on the
# DOT_AI_GATEWAY_SUBSCRIPTION=1 opt-in, which prints Anthropic's terms and,
# without a terminal, needs DOT_AI_GATEWAY_SUBSCRIPTION_ACK=1. Runs the real
# server on free loopback ports against a mock engine that records the
# credentials it was given. Every key here is fake.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

if ! command -v python3 >/dev/null 2>&1 || ! command -v curl >/dev/null 2>&1 || ! command -v perl >/dev/null 2>&1; then
  echo "SKIP: python3, curl and perl are needed"
  echo "RESULTS:0:0:0"
  exit 0
fi

SERVE="$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai-serve"
# The gateway's own client token in these tests: a placeholder, not a key.
GW_CLIENT="gw-client-key"
PROXY="$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai-proxy"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-gw-auth.XXXXXX")"
trap 'while read -r p; do kill "$p" 2>/dev/null; done <"$WORK/pids" 2>/dev/null; rm -rf "$WORK"' EXIT
: >"$WORK/pids"
FAKE_KEY="sk-ant-api03-fake-test-key-not-real"
SYS_PATH="$(dirname "$(command -v python3)"):/usr/bin:/bin"

# The mock engine writes which credentials reached it, then answers.
cat >"$WORK/claude" <<EOF
#!/bin/sh
cat >/dev/null
{
  printf 'api_key=%s\n' "\${ANTHROPIC_API_KEY:-<unset>}"
  printf 'auth_token=%s\n' "\${ANTHROPIC_AUTH_TOKEN:-<unset>}"
  printf 'oauth_token=%s\n' "\${CLAUDE_CODE_OAUTH_TOKEN:-<unset>}"
} >"$WORK/engine.env"
printf '%s\n' '{"type":"result","is_error":false,"result":"ok","usage":{}}'
EOF
chmod +x "$WORK/claude"

# refute_contains NEEDLE ACTUAL MSG — the framework has no negative form.
refute_contains() {
  if [[ "$2" != *"$1"* ]]; then assert_exit_code 0 "true"; else assert_exit_code 0 "false  # $3: found '$1'"; fi
}

free_port() { python3 -c 'import socket;s=socket.socket();s.bind(("127.0.0.1",0));print(s.getsockname()[1]);s.close()'; }

# serve ENV=val... — run the server in the foreground with no terminal, for
# at most 3 s (one that starts serving is stopped by the alarm). Sets RC, OUT.
serve() {
  RC=0
  OUT="$(env -i PATH="$SYS_PATH" HOME="$WORK/home" XDG_STATE_HOME="$WORK/state" \
    DOT_AI_POLICY="$WORK/no-policy.toml" DOT_AI_CLAUDE_BIN="$WORK/claude" DOT_AI_PORT="$(free_port)" \
    "$@" perl -e 'alarm 3; exec @ARGV' python3 "$SERVE" 2>&1 </dev/null)" || RC=$?
}

# start ENV=val... — start the server in the background; sets PORT and LOG.
start() {
  PORT="$(free_port)"
  LOG="$WORK/serve-$PORT.log"
  env -i PATH="$SYS_PATH" HOME="$WORK/home" XDG_STATE_HOME="$WORK/state" \
    DOT_AI_POLICY="$WORK/no-policy.toml" DOT_AI_CLAUDE_BIN="$WORK/claude" DOT_AI_PORT="$PORT" \
    DOT_AI_API_KEY="$GW_CLIENT" "$@" python3 "$SERVE" >"$LOG" 2>&1 </dev/null &
  echo "$!" >>"$WORK/pids"
  for _ in $(seq 1 50); do
    curl -fsS "http://127.0.0.1:$PORT/health" >/dev/null 2>&1 && return 0
    sleep 0.1
  done
  return 1
}

ask() {
  rm -f "$WORK/engine.env"
  curl -fsS -H "x-api-key: $GW_CLIENT" -H 'Content-Type: application/json' \
    "http://127.0.0.1:$PORT/v1/messages" -d '{"model":"sonnet","messages":[{"role":"user","content":"hi"}]}' >/dev/null
}

# ── (a) the default, with no key, refuses with both options ───────────────
case_default_without_a_key() {
  test_start "default_without_a_key_refuses_to_start"
  serve
  assert_equals "2" "$RC" "exit 2, not serving"
  assert_contains "no upstream API key" "$OUT" "says what is missing"
  assert_contains "ANTHROPIC_API_KEY" "$OUT" "names the key"
  assert_contains "dot secret set ANTHROPIC_API_KEY" "$OUT" "and the secret store"
  assert_contains "DOT_AI_GATEWAY_SUBSCRIPTION=1" "$OUT" "and the subscription opt-in"
  assert_contains "never falls back" "$OUT" "and that there is no silent fallback"

  test_start "default_without_a_key_ignores_a_subscription_token"
  serve CLAUDE_CODE_OAUTH_TOKEN=fake-oauth-token
  assert_equals "2" "$RC" "a subscription credential in the env is no fallback"

  test_start "the_gateway_token_is_not_an_upstream_key"
  serve DOT_AI_API_KEY=same-token ANTHROPIC_API_KEY=same-token
  assert_equals "2" "$RC" "exit 2"
  assert_contains "this gateway's own client token" "$OUT" "says why"
}

# ── (b) the default, with a key, runs the engine on that key only ─────────
case_default_with_a_key() {
  test_start "default_with_a_key_uses_api_key_mode"
  start ANTHROPIC_API_KEY="$FAKE_KEY" ANTHROPIC_AUTH_TOKEN=fake-bearer CLAUDE_CODE_OAUTH_TOKEN=fake-oauth-token
  assert_contains '"auth": "api-key"' "$(curl -fsS "http://127.0.0.1:$PORT/health")" "/health reports api-key"
  assert_contains "upstream auth: api-key" "$(cat "$LOG")" "the log says so"
  refute_contains "WARNING: subscription mode" "$(cat "$LOG")" "no subscription warning"
  ask
  assert_contains "api_key=$FAKE_KEY" "$(cat "$WORK/engine.env" 2>/dev/null)" "the engine gets the key"
  assert_contains "auth_token=<unset>" "$(cat "$WORK/engine.env" 2>/dev/null)" "no bearer token outranks it"
  assert_contains "oauth_token=<unset>" "$(cat "$WORK/engine.env" 2>/dev/null)" "no subscription token reaches it"
}

# ── (c) the opt-in prints the terms on every start ────────────────────────
case_opt_in_prints_the_terms() {
  test_start "subscription_opt_in_prints_the_terms"
  start DOT_AI_GATEWAY_SUBSCRIPTION=1 DOT_AI_GATEWAY_SUBSCRIPTION_ACK=1 ANTHROPIC_API_KEY="$FAKE_KEY"
  assert_contains '"auth": "subscription"' "$(curl -fsS "http://127.0.0.1:$PORT/health")" "/health reports subscription"
  assert_contains "WARNING: subscription mode" "$(cat "$LOG")" "a prominent warning"
  assert_contains "https://code.claude.com/docs/en/legal-and-compliance" "$(cat "$LOG")" "citing the legal page"
  assert_contains "https://www.anthropic.com/legal/consumer-terms" "$(cat "$LOG")" "and the Consumer Terms"
  ask
  assert_contains "api_key=<unset>" "$(cat "$WORK/engine.env" 2>/dev/null)" "the opted-in engine is not billed to a stray key"
}

case_opt_in_on_a_terminal() {
  test_start "subscription_opt_in_on_a_terminal_needs_no_ack"
  # on_tty.py CMD...: run CMD on a new pseudo-terminal, print what it wrote and
  # exit with its status (pty.spawn hangs at EOF on macOS's Python 3.9).
  cat >"$WORK/on_tty.py" <<'PY'
import os, pty, sys
pid, fd = pty.fork()
if pid == 0:
    os.execvp(sys.argv[1], sys.argv[1:])
out = b""
while True:
    try:
        data = os.read(fd, 4096)
    except OSError:
        break
    if not data:
        break
    out += data
sys.stdout.write(out.decode("utf-8", "replace"))
_, status = os.waitpid(pid, 0)
sys.exit(os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1)
PY
  RC=0
  OUT="$(env -i PATH="$SYS_PATH" HOME="$WORK/home" XDG_STATE_HOME="$WORK/state" DOT_AI_GATEWAY_SUBSCRIPTION=1 \
    perl -e 'alarm 10; exec @ARGV' python3 "$WORK/on_tty.py" python3 "$SERVE" --check 2>&1 </dev/null)" || RC=$?
  assert_equals "0" "$RC" "accepted on a terminal"
  assert_contains "WARNING: subscription mode" "$OUT" "after the warning"
}

# ── (d) the opt-in without a terminal needs the acknowledgement ───────────
case_opt_in_without_a_terminal() {
  test_start "subscription_opt_in_without_a_terminal_refuses"
  serve DOT_AI_GATEWAY_SUBSCRIPTION=1
  assert_equals "2" "$RC" "exit 2, not serving"
  assert_contains "WARNING: subscription mode" "$OUT" "the warning still prints"
  assert_contains "REFUSING subscription mode without a terminal" "$OUT" "says why"
  assert_contains "DOT_AI_GATEWAY_SUBSCRIPTION_ACK=1" "$OUT" "and how to acknowledge"
}

# ── the launcher: dot-ai-proxy start decides in the foreground ────────────
setup_proxy_stubs() {
  mkdir -p "$WORK/stubs" "$WORK/pxstate"
  PX_TTY=()
  for t in nohup seq kill cat mkdir rm sleep; do ln -sf "$(command -v "$t")" "$WORK/stubs/$t"; done
  # A stub server that records each run's auth env, and fails --check when
  # no key reached it (as the real one does).
  cat >"$WORK/stubs/dot-ai-serve" <<EOF
#!/bin/sh
printf '%s key=%s ack=%s\n' "\${1:-serve}" "\${ANTHROPIC_API_KEY:-<unset>}" "\${DOT_AI_GATEWAY_SUBSCRIPTION_ACK:-<unset>}" >>"$WORK/px.log"
if [ "\${1:-}" = --check ] && [ -z "\${ANTHROPIC_API_KEY:-}" ] && [ -z "\${DOT_AI_GATEWAY_SUBSCRIPTION:-}" ]; then
  echo "[dot-ai-serve] no upstream API key" >&2
  exit 2
fi
exit 0
EOF
  chmod +x "$WORK/stubs/dot-ai-serve"
  printf '#!/bin/sh\nexit 0\n' >"$WORK/stubs/curl" # /health answers at once
  chmod +x "$WORK/stubs/curl"
}

# px ENV=val... — `dot-ai-proxy start` with only the stubs on PATH; waits for
# the background server's record. Sets RC and OUT.
px() {
  RC=0
  rm -f "$WORK/px.log" "$WORK/pxstate/dot/ai/serve/serve.pid"
  OUT="$(env -i PATH="$WORK/stubs" HOME="$WORK/home" XDG_STATE_HOME="$WORK/pxstate" NO_COLOR=1 \
    DOT_AI_PORT="$(free_port)" "$@" ${PX_TTY[@]+"${PX_TTY[@]}"} /bin/bash "$PROXY" start 2>&1 </dev/null)" || RC=$?
  [[ "$RC" -eq 0 ]] || return 0
  # The server logs on its own schedule; a slow runner (macos-15) took over
  # the 3 s this used to allow. Wait up to 10 s.
  for _ in $(seq 1 100); do
    grep -q '^serve ' "$WORK/px.log" 2>/dev/null && return 0
    sleep 0.1
  done
}

case_proxy_without_a_key() {
  test_start "proxy_start_without_a_key_stops_before_launching"
  px
  assert_equals "1" "$RC" "exit 1"
  assert_contains "no upstream API key" "$OUT" "the server's reason reaches the user"
  assert_equals "--check key=<unset> ack=<unset>" "$(cat "$WORK/px.log" 2>/dev/null)" "only the check ran"
}

case_proxy_reads_dot_secret() {
  test_start "proxy_start_reads_the_key_from_dot_secret_only_on_a_terminal"
  cat >"$WORK/stubs/dot" <<EOF
#!/bin/sh
[ "\$*" = "secret show ANTHROPIC_API_KEY --raw" ] && printf '%s\n' "$FAKE_KEY"
EOF
  chmod +x "$WORK/stubs/dot"
  px
  assert_equals "1" "$RC" "without a terminal the secret store is not asked"
  PX_TTY=("$(command -v perl)" -e 'alarm 20; exec @ARGV' "$(command -v python3)" "$WORK/on_tty.py")
  px
  PX_TTY=()
  assert_equals "0" "$RC" "on a terminal the stored key is used"
  assert_contains "--check key=$FAKE_KEY" "$(cat "$WORK/px.log" 2>/dev/null)" "the check gets the stored key"
  assert_contains "serve key=$FAKE_KEY" "$(cat "$WORK/px.log" 2>/dev/null)" "and so does the server"
  refute_contains "$FAKE_KEY" "$OUT" "the key is never printed"
}

# `setup` runs under set -e outside any `||`, so a failing key lookup would
# end it before the upstream verdict: the stored key must be reported.
case_proxy_setup_reads_dot_secret() {
  test_start "proxy_setup_reports_the_key_from_dot_secret_on_a_terminal"
  ln -sf "$WORK/claude" "$WORK/stubs/claude"
  RC=0
  OUT="$(env -i PATH="$WORK/stubs" HOME="$WORK/home" XDG_STATE_HOME="$WORK/pxstate" NO_COLOR=1 \
    "$(command -v perl)" -e 'alarm 20; exec @ARGV' "$(command -v python3)" "$WORK/on_tty.py" \
    /bin/bash "$PROXY" setup 2>&1 </dev/null)" || RC=$?
  rm -f "$WORK/stubs/claude"
  assert_equals "0" "$RC" "setup succeeds with the stored key"
  assert_contains "upstream: an Anthropic API key is set" "$OUT" "the stored key counts as upstream auth"
  refute_contains "$FAKE_KEY" "$OUT" "the key is never printed"
}

case_proxy_passes_the_opt_in() {
  test_start "proxy_start_passes_an_accepted_opt_in_to_the_server"
  rm -f "$WORK/stubs/dot"
  px DOT_AI_GATEWAY_SUBSCRIPTION=1
  assert_contains "--check key=<unset> ack=<unset>" "$(cat "$WORK/px.log" 2>/dev/null)" "the check decides on its own"
  assert_contains "serve key=<unset> ack=1" "$(cat "$WORK/px.log" 2>/dev/null)" "the background server inherits the acceptance"
}

case_default_without_a_key
case_default_with_a_key
case_opt_in_prints_the_terms
case_opt_in_on_a_terminal
case_opt_in_without_a_terminal
setup_proxy_stubs
case_proxy_without_a_key
case_proxy_reads_dot_secret
case_proxy_setup_reads_dot_secret
case_proxy_passes_the_opt_in

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
