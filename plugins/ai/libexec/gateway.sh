#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# dot ai gateway show [--json] — the running gateway's statistics (plan
# P1.2): requests, tokens, images, tool calls and estimated cost, in all
# and per model, from its /v1/usage. The key is the gateway's own:
# DOT_AI_API_KEY, else the token file dot-ai-serve keeps. --json prints the
# report as it is (schema ai/gateway-usage.v1).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/sdk.sh
source "${DOT_SDK:-$SCRIPT_DIR/../../../lib/dot}/sdk.sh"

# The report as lines of "label value", labels in a column of 12.
read -r -d '' GW_FORMAT <<'EOF' || true
def money: (. * 10000 | round) as $n
  | "$\($n / 10000 | floor).\("000\($n % 10000)" | .[-4:])";
def dur: if . < 60 then "\(.)s" elif . < 3600 then "\(. / 60 | floor)m"
  else "\(. / 3600 | floor)h \((. % 3600) / 60 | floor | tostring | if length < 2 then "0" + . else . end)m" end;
def count($one; $many): "\(.) \(if . == 1 then $one else $many end)";
def row($label; $value): (if ($label | length) < 12 then ($label + "            ")[:12] else $label end) + " " + $value;
row("gateway"; "\($url), up \(.uptime_seconds | dur)"),
row("requests"; "\(.requests), \(.errors | count("error"; "errors")), \(.streamed) streamed"),
row("tokens"; "\(.input_tokens) in, \(.output_tokens) out"),
row("images"; "\(.images)"),
row("tool calls"; "\(.tool_calls)"),
row("cost"; "\(.cost_usd | money) estimated; today \(.budget.spent_today_usd | money)"
  + (if .budget.daily_usd > 0 then " of \(.budget.daily_usd | money)" else ", no daily cap" end)),
(.by_model | to_entries[] | row(.key; "\(.value.requests | count("request"; "requests")), \(.value.cost | money)"))
EOF

gw_usage() {
  echo "Usage: dot ai gateway show [--json]"
  exit 1
}

# gw_key: the gateway's key, or nothing.
gw_key() {
  local key="${DOT_AI_API_KEY:-}"
  local file="${XDG_STATE_HOME:-$HOME/.local/state}/dot/ai/serve/gateway.token"
  [[ -n "$key" || ! -r "$file" ]] || IFS= read -r key <"$file" || true
  printf '%s' "$key"
}

# gw_url: where the gateway answers. A wildcard bind is reached on loopback.
gw_url() {
  local host="${DOT_AI_HOST:-127.0.0.1}"
  [[ "$host" != 0.0.0.0 && "$host" != "::" ]] || host=127.0.0.1
  [[ "$host" != *:* ]] || host="[$host]"
  printf 'http://%s:%s' "$host" "${DOT_AI_PORT:-3456}"
}

gw_show() {
  local json="${1:-}" key url code
  url="$(gw_url)"
  key="$(gw_key)"
  [[ -n "$key" ]] || {
    ui_err "dot ai gateway" "no gateway token: set DOT_AI_API_KEY, or start the gateway with dot ai gateway serve" >&2
    exit 1
  }
  # Global: the EXIT trap runs after this function has returned.
  GW_OUT="$(mktemp)"
  trap 'rm -f "$GW_OUT"' EXIT
  # The key goes to curl as a config line on stdin, never on its argv.
  code="$(printf 'header = "x-api-key: %s"\n' "$key" | curl -sS -K - -o "$GW_OUT" -w '%{http_code}' --max-time 5 "$url/v1/usage" 2>/dev/null)" || code=000
  case "$code" in
    200) ;;
    000) ui_err "dot ai gateway" "no gateway answers on $url: start it with dot ai gateway serve" >&2 ;;
    401) ui_err "dot ai gateway" "the gateway refused the key (DOT_AI_API_KEY, or its token file)" >&2 ;;
    *) ui_err "dot ai gateway" "$url/v1/usage answered HTTP $code" >&2 ;;
  esac
  [[ "$code" == 200 ]] || exit 1
  if [[ "$json" == --json ]]; then
    cat "$GW_OUT"
  else
    jq -r --arg url "$url" "$GW_FORMAT" "$GW_OUT"
  fi
}

case "${1:-}:${2:-}" in
  show: | show:--json) gw_show "${2:-}" ;;
  *) gw_usage ;;
esac
