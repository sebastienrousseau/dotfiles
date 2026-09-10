#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Lifecycle and reporting paths of dot_local/bin/executable_dot-ai-proxy.
#
# The proxy's interesting branches are all "what did the world look like":
# whether dot-ai-serve is deployed, whether /health ever answers, whether the
# server dies on SIGTERM, whether jq is installed, whether routing is on. None
# of those can be varied from the checkout, so each case here stages the world
# it needs — a private state directory, a PATH with only the stubs that case
# wants found, and a port nothing is listening on.
#
# Nothing escapes the sandbox: the only real process any case starts is a
# short-lived `sleep` this suite owns and reaps.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

PROXY="$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai-proxy"

WORK="$(mktemp -d -t aiproxy.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

mkdir -p "$WORK/home" "$WORK/stubs" "$WORK/state" "$WORK/config"
dot_fixture_basebin "$WORK/base" nohup seq kill

STATE="$WORK/home/.local/state/dotfiles/ai-serve"
CONFIG="$WORK/home/.config/dotfiles"
mkdir -p "$STATE" "$CONFIG"

PX_OUT=""
PX_RC=0
# px_run [args...] — run the proxy against the sandbox state directory, on a
# port nothing is listening on.
px_run() {
  PX_RC=0
  PX_OUT="$(
    HOME="$WORK/home" \
      XDG_STATE_HOME="$WORK/home/.local/state" \
      XDG_CONFIG_HOME="$WORK/home/.config" \
      PATH="$WORK/stubs:$WORK/base" \
      NO_COLOR=1 DOT_AI_PORT=59999 \
      "${BASH:-bash}" "$PROXY" "$@" 2>&1 </dev/null
  )" || PX_RC=$?
}

# ── 1. start refuses without the server binary ─────────────────────────────
test_start "ai_proxy_start_requires_the_server_binary"
px_run start
assert_equals "1" "$PX_RC" "start without dot-ai-serve should fail"
assert_contains "dot-ai-serve not found" "$PX_OUT" "the failure should name it"
assert_contains "chezmoi apply" "$PX_OUT" "and say how to deploy it"

# ── 2. start reports a server that never becomes healthy ───────────────────
#
# The stub exits immediately and no curl is on the PATH, so /health can never
# answer and the readiness loop runs to exhaustion — which is the branch that
# tells the user where to look.
test_start "ai_proxy_start_reports_an_unready_server"
printf '#!/bin/sh\nexit 0\n' >"$WORK/stubs/dot-ai-serve"
chmod +x "$WORK/stubs/dot-ai-serve"
px_run start
assert_contains "is not ready yet" "$PX_OUT" \
  "an unready server should be reported, not silently accepted"
assert_contains "dot ai proxy logs" "$PX_OUT" "and the log command suggested"

# ── 3. stop escalates when the server ignores SIGTERM ──────────────────────
test_start "ai_proxy_stop_escalates_past_sigterm"
"${BASH:-bash}" -c 'trap "" TERM; sleep 30' &
STUBBORN=$!
printf '%s\n' "$STUBBORN" >"$STATE/serve.pid"
px_run stop
assert_equals "0" "$PX_RC" "stop should succeed even against a stubborn server"
assert_contains "Stopped proxy (pid $STUBBORN)" "$PX_OUT" \
  "the stopped pid should be reported"
assert_false "kill -0 $STUBBORN 2>/dev/null" \
  "the stubborn process must actually be gone"
wait "$STUBBORN" 2>/dev/null || true

# ── 4. status reports what it can reach ────────────────────────────────────
test_start "ai_proxy_status_reports_an_unreachable_health_endpoint"
printf '#!/bin/sh\nexit 7\n' >"$WORK/stubs/curl"
chmod +x "$WORK/stubs/curl"
px_run status
assert_contains "health: unreachable" "$PX_OUT" \
  "a health endpoint that does not answer should be reported as such"
assert_contains "local routing: OFF" "$PX_OUT" \
  "routing should read as off with no env file written"

test_start "ai_proxy_status_prints_raw_health_without_jq"
printf '#!/bin/sh\nprintf %%s "{\\"status\\":\\"ok\\"}"\n' >"$WORK/stubs/curl"
chmod +x "$WORK/stubs/curl"
px_run status
assert_contains 'health: {"status":"ok"}' "$PX_OUT" \
  "with no jq on PATH the raw health body should be printed"

test_start "ai_proxy_status_reports_routing_on"
px_run local on
assert_equals "0" "$PX_RC" "local on should exit 0"
assert_file_exists "$CONFIG/ai-local.env" "the posix routing file should be written"
px_run status
assert_contains "local routing: ON" "$PX_OUT" \
  "routing should read as on once the env file exists"
px_run local off

# ── 5. logs ────────────────────────────────────────────────────────────────
test_start "ai_proxy_logs_prints_the_tail"
printf 'log line one\nlog line two\n' >"$STATE/serve.log"
px_run logs
assert_equals "0" "$PX_RC" "logs should exit 0"
assert_contains "log line two" "$PX_OUT" "the log tail should be printed"

test_start "ai_proxy_logs_follows_with_a_flag"
# A tail stub, so the follow path can be observed without blocking forever.
printf '#!/bin/sh\necho "tail-follow $*"\nexit 0\n' >"$WORK/stubs/tail"
chmod +x "$WORK/stubs/tail"
px_run logs -f
assert_contains "tail-follow" "$PX_OUT" "logs -f should hand over to tail"
assert_contains "60 -f" "$PX_OUT" "and pass the follow flag through"
rm -f "$WORK/stubs/tail"

# ── 6. setup needs the claude CLI ──────────────────────────────────────────
test_start "ai_proxy_setup_requires_claude"
px_run setup
assert_equals "1" "$PX_RC" "setup without claude should exit 1"
assert_contains "claude CLI not on PATH" "$PX_OUT" "the failure should name it"

print_summary
