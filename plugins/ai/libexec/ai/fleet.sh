#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by ai.sh; inherits set -euo pipefail.
# dot ai across the fleet (plan P1.4), over the hosts in fleet.toml and the
# SSH they are reached by (lib/dot/fleet-hosts.sh):
#
#   dot ai check --on <host>        dot ai check, run on that host
#   dot ai status --fleet [--json]  this machine's and every host's live
#                                   agent sessions, with what each cost
#
# Every host is asked at once and waited for at most
# $DOT_FLEET_CONNECT_TIMEOUT (5 s) to connect; one that does not answer is
# named with why, and the command exits 1.

# What a host runs for status --fleet: its live sessions (agent-event.v1
# records), a record separator, then each session's cost (dot ai cost show
# --by session, as agent/session<TAB>usd lines) when the cockpit is there.
_AI_FLEET_STATUS_CMD='dot ai status --json 2>/dev/null; printf "\036\n"; t="$HOME/.local/bin/dot-ai-tui"; if [ -x "$t" ]; then "$t" cost --by session --tsv 2>/dev/null; fi; true'

# _ai_fleet_target NAME: sets _ai_fleet_ssh to host NAME's SSH target; 1
# (having said why) when NAME is not in the fleet or its target is not plain.
_ai_fleet_target() {
  local name ssh why
  while IFS=$'\t' read -r name ssh _; do
    [[ "$name" == "$1" ]] || continue
    why="$(fleet_host_check "$name" "$ssh")" || {
      ui_err "dot ai" "$name: $why" >&2
      return 1
    }
    _ai_fleet_ssh="$ssh"
    return 0
  done < <(fleet_hosts)
  ui_err "dot ai" "no host $1 in $(fleet_hosts_file)" >&2
  return 1
}

# ai_check_on HOST: dot ai check on HOST, as it prints it, with its status.
ai_check_on() {
  local _ai_fleet_ssh=""
  _ai_fleet_target "${1:-}" || return 1
  fleet_ssh "$_ai_fleet_ssh" "dot ai check" </dev/null
}

# _ai_fleet_local OUT: this machine's answer to status --fleet, as a host's.
_ai_fleet_local() {
  {
    bash "${BASH_SOURCE[0]%/*}/../../../cli/libexec/hook.sh" --status --live --json
    printf '\036\n'
    if has_command dot-ai-tui; then dot-ai-tui cost --by session --tsv 2>/dev/null || :; fi
  } >"$1" 2>/dev/null
  printf '0\n' >"$1.rc"
}

# _ai_fleet_ask DIR: every host's answer in DIR/<n>.out (.out.err, .out.rc), at
# once; DIR/hosts lists "<n>\t<label>" in order, this machine first.
_ai_fleet_ask() {
  local dir="$1" n=0 name ssh why
  _ai_fleet_local "$dir/0.out"
  printf '0\t%s\n' "$(hostname -s 2>/dev/null || hostname)" >"$dir/hosts"
  while IFS=$'\t' read -r name ssh _; do
    n=$((n + 1))
    printf '%s\t%s\n' "$n" "$name" >>"$dir/hosts"
    if ! why="$(fleet_host_check "$name" "$ssh")"; then
      printf '%s\n' "$why" >"$dir/$n.out.err"
      printf '1\n' >"$dir/$n.out.rc"
      continue
    fi
    (
      rc=0
      DOT_FLEET_CONNECT_TIMEOUT="${DOT_FLEET_CONNECT_TIMEOUT:-5}" fleet_ssh "$ssh" "$_AI_FLEET_STATUS_CMD" \
        </dev/null >"$dir/$n.out" 2>"$dir/$n.out.err" || rc=$?
      printf '%s\n' "$rc" >"$dir/$n.out.rc"
    ) &
  done < <(fleet_hosts)
  wait
}

# _ai_fleet_json OUT HOST: one ai/fleet-status.v1 line for HOST's answer.
_ai_fleet_json() {
  local rc err
  rc="$(cat "$1.rc" 2>/dev/null || echo 1)"
  err="$(head -1 "$1.err" 2>/dev/null || :)"
  if [[ "$rc" != 0 ]]; then
    jq -nc --arg h "$2" --arg e "${err:-exit $rc}" '{schema: "ai/fleet-status.v1", host: $h, reachable: false, error: $e, sessions: []}'
    return 0
  fi
  awk -v r="$1.records" -v c="$1.costs" '$0 == "\036" { f = 1; next } { print > (f ? c : r) }
    END { printf "" > r; printf "" > c }' "$1"
  jq -nc --arg h "$2" --rawfile r "$1.records" --rawfile c "$1.costs" '
    ($c | split("\n") | map(select(length > 0) | split("\t") | {(.[0]): (.[1] | tonumber? // null)}) | add // {}) as $cost
    | {schema: "ai/fleet-status.v1", host: $h, reachable: true, error: "",
       sessions: [$r | split("\n")[] | select(length > 0) | fromjson? | select(.schema == "cli/agent-event.v1")
                  | {event: ., cost_usd: $cost[.agent + "/" + .session]}]}'
}

# _ai_fleet_table: the JSON lines on stdin as a table, newest first per
# host, then the hosts that did not answer and a summary.
_ai_fleet_table() {
  jq -rs '
    def money: if . == null then "-" else (. * 100 | round) as $c | "$\($c / 100 | floor).\("0\($c % 100)" | .[-2:])" end;
    def pad($n): (. + (" " * $n))[:$n];
    "HOST       AGENT      STATE    TIME                 COST     SESSION",
      (.[] | select(.reachable) | .host as $host | .sessions | sort_by(.event.time) | reverse[]
        | [($host | pad(10)), (.event.agent | pad(10)), (.event.state | pad(8)), (.event.time | pad(20)), (.cost_usd | money | pad(8)), .event.session] | join(" ")),
      (.[] | select(.reachable | not) | "\(.host): no answer (\(.error))"),
      "",
      ([.[] | select(.reachable) | .sessions[]] as $s
        | "\($s | length) sessions on \([.[] | select(.reachable)] | length) of \(length) hosts, \([$s[] | select(.event.state == "blocked")] | length) blocked")'
}

# ai_status_fleet [--json]: status --fleet; 1 when a host did not answer.
ai_status_fleet() {
  local dir n label json="" rc=0
  [[ " $* " != *" --json "* ]] || json=1
  has_command jq || {
    ui_err "dot ai status --fleet" "needs jq" >&2
    return 1
  }
  dir="$(mktemp -d "${TMPDIR:-/tmp}/dot-ai-fleet.XXXXXX")" || return 1
  _ai_fleet_ask "$dir"
  while IFS=$'\t' read -r n label; do
    _ai_fleet_json "$dir/$n.out" "$label"
    [[ "$(cat "$dir/$n.out.rc" 2>/dev/null || echo 1)" == 0 ]] || rc=1
  done <"$dir/hosts" >"$dir/all.jsonl"
  if [[ -n "$json" ]]; then cat "$dir/all.jsonl"; else _ai_fleet_table <"$dir/all.jsonl"; fi
  rm -rf "$dir"
  return "$rc"
}
