#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by fleet.sh; inherits set -euo pipefail
# `dot fleet drift`: check (with a history record), history and predict.

_DRIFT_HISTORY_FILE="$_FLEET_STATE_DIR/drift-history.jsonl"

_fleet_drift_append_history() {
  local drift_output="$1"
  local ts
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  mkdir -p "$_FLEET_STATE_DIR" 2>/dev/null || return 0
  if [[ -z "$drift_output" ]]; then
    printf '{"time":"%s","status":"clean","files":[]}\n' "$ts" >>"$_DRIFT_HISTORY_FILE" 2>/dev/null || true
  else
    local files_json
    files_json="$(printf '%s\n' "$drift_output" | awk '{print $NF}' | jq -R . | jq -s . 2>/dev/null || echo '[]')"
    printf '{"time":"%s","status":"drifted","files":%s}\n' "$ts" "$files_json" >>"$_DRIFT_HISTORY_FILE" 2>/dev/null || true
  fi
}

# One `chezmoi status` line: modifications warn, anything else informs.
_fleet_drift_line() {
  local line="$1"
  local change_type="${line:0:2}"
  local file_path="${line:3}"
  case "$change_type" in
    "MM" | "A " | " M")
      ui_warn "$change_type" "$file_path"
      ;;
    *)
      ui_info "$change_type" "$file_path"
      ;;
  esac
}

_fleet_drift_check() {
  local drift_output line
  ui_header "Fleet Drift Report"
  echo ""

  if ! has_command chezmoi; then
    ui_err "chezmoi" "not installed"
    return 1
  fi

  drift_output="$(chezmoi status --exclude=always 2>/dev/null || true)"

  _fleet_drift_append_history "$drift_output"

  if [[ -z "$drift_output" ]]; then
    ui_ok "Status" "No drift detected"
    _fleet_emit_event "drift_check" "clean"
    return 0
  fi

  ui_warn "Status" "Configuration drift detected"
  echo ""
  printf '%s\n' "$drift_output" | while IFS= read -r line; do
    _fleet_drift_line "$line"
  done

  _fleet_emit_event "drift_check" "drifted" "count=$(echo "$drift_output" | wc -l | tr -d ' ')"
}

# One history record as a clean/drifted row; unparsable lines show `?`.
_fleet_drift_history_line() {
  local line="$1" time status file_count
  # One jq per line (was three: .time, .status, .files|length).
  # `|| true`: on an unparsable line jq prints nothing, `read`
  # hits EOF and returns 1, and `set -e` would otherwise abort the
  # whole listing instead of rendering the `?` placeholders below.
  IFS=$'\t' read -r time status file_count < <(
    printf '%s' "$line" | jq -r '[.time, .status, (.files | length)] | @tsv' 2>/dev/null
  ) || true
  [[ -n "$time" ]] || time="?"
  [[ -n "$status" ]] || status="?"
  [[ -n "$file_count" ]] || file_count=0
  if [[ "$status" == "clean" ]]; then
    ui_ok "$time" "clean"
  else
    ui_warn "$time" "drifted ($file_count files)"
  fi
}

_fleet_drift_history() {
  local count="${1:-20}" line
  ui_header "Drift History"
  echo ""
  if [[ ! -f "$_DRIFT_HISTORY_FILE" ]]; then
    ui_info "No drift history recorded yet."
    return 0
  fi
  tail -n "$count" "$_DRIFT_HISTORY_FILE" | while IFS= read -r line; do
    _fleet_drift_history_line "$line"
  done
}

_fleet_drift_predict() {
  local count file total_checks
  ui_header "Drift Prediction"
  echo ""
  if [[ ! -f "$_DRIFT_HISTORY_FILE" ]]; then
    ui_info "Not enough history for prediction."
    return 0
  fi
  # Simple heuristic: files that drifted in >50% of the last 10 checks
  local threshold=5
  # -R + fromjson?: an unparsable line (a torn write) is skipped. Plain
  # `jq '.files[]?'` stopped at it, and under pipefail the whole prediction
  # exited with jq's status before printing its summary.
  jq -rR 'fromjson? | .files[]?' "$_DRIFT_HISTORY_FILE" | tail -n 1000 | sort | uniq -c | sort -rn | while read -r count file; do
    if [[ "$count" -ge "$threshold" ]]; then
      ui_warn "Likely to drift" "$file (drifted $count times recently)"
    fi
  done
  total_checks="$(wc -l <"$_DRIFT_HISTORY_FILE" | tr -d ' ')"
  ui_info "History" "$total_checks checks recorded"
}

# _fleet_drift_ask DIR: every host's `dot ai inventory show --json` in
# DIR/<n>.out (.err, .rc), at once; DIR/hosts lists "<n>\t<name>". A host
# refused before any connection has the rc "refused".
_fleet_drift_ask() {
  local dir="$1" n=0 name ssh why
  : >"$dir/hosts"
  while IFS=$'\t' read -r name ssh _; do
    n=$((n + 1))
    printf '%s\t%s\n' "$n" "$name" >>"$dir/hosts"
    if ! why="$(fleet_host_check "$name" "$ssh")"; then
      printf '%s\n' "$why" >"$dir/$n.err"
      printf 'refused\n' >"$dir/$n.rc"
      continue
    fi
    (
      rc=0
      fleet_ssh "$ssh" "dot ai inventory show --json" </dev/null >"$dir/$n.out" 2>"$dir/$n.err" || rc=$?
      printf '%s\n' "$rc" >"$dir/$n.rc"
    ) &
  done < <(fleet_hosts)
  wait
}

# _fleet_drift_host DIR N NAME SHA: one host's verdict against this
# machine's policy digest SHA (empty: no policy here, so none to match);
# 1 when it drifts or did not answer.
_fleet_drift_host() {
  local dir="$1" n="$2" name="$3" rc out lines
  rc="$(cat "$dir/$n.rc")"
  out="$(cat "$dir/$n.out" 2>/dev/null || true)"
  if [[ "$rc" == refused || "$rc" == 255 ]]; then
    ui_err "$name" "no answer ($(head -1 "$dir/$n.err"))"
    return 1
  elif [[ "$out" != *'"schema":"ai/inventory.v1"'* ]]; then
    ui_err "$name" "no inventory (dot config update there)"
    return 1
  fi
  lines="$(jq -r --arg sha "$4" '.drift[].message,
    (select($sha != "" and .policy.sha256 != $sha) | "AI policy differs from this machine'"'"'s (dot fleet apply --agents)")' <<<"$out")"
  if [[ -z "$lines" ]]; then
    ui_ok "$name" "agents at their pins, hooks wired, this machine's policy"
    return 0
  fi
  while IFS= read -r out; do
    ui_warn "$name" "$out"
  done <<<"$lines"
  return 1
}

# _fleet_drift_agents: each host's agents against their pins and hooks, and
# its AI policy against this machine's (plan P1.5); exit 1 on any drift or
# a host that did not answer.
_fleet_drift_agents() {
  local file="${DOT_AI_POLICY:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/ai-policy.toml}" sha="" dir n name ok=0 total=0
  has_command jq || {
    ui_err "dot fleet drift" "--agents needs jq" >&2
    return 1
  }
  if [[ -z "$(fleet_hosts)" ]]; then
    ui_info "Agents" "no hosts in $(fleet_hosts_file)"
    return 0
  fi
  [[ ! -f "$file" ]] || sha="$( (shasum -a 256 "$file" 2>/dev/null || sha256sum "$file" 2>/dev/null) | awk '{print $1}')" || true
  ui_header "Fleet Agent Drift"
  echo ""
  dir="$(mktemp -d "${TMPDIR:-/tmp}/dot-fleet-drift.XXXXXX")"
  _fleet_drift_ask "$dir"
  while IFS=$'\t' read -r n name; do
    total=$((total + 1))
    ! _fleet_drift_host "$dir" "$n" "$name" "$sha" || ok=$((ok + 1))
  done <"$dir/hosts"
  rm -rf "$dir"
  ui_info "Summary" "$ok of $total hosts in step"
  [[ "$ok" == "$total" ]]
}

cmd_fleet_drift() {
  local subcommand="${1:-check}"
  if [[ " $* " == *" --agents "* ]]; then
    _fleet_drift_agents
    return
  fi
  if [[ "${1:-}" == --* ]] || [[ -z "${1:-}" ]]; then
    subcommand="check"
  else
    shift || true
  fi

  case "$subcommand" in
    check) _fleet_drift_check ;;
    history) _fleet_drift_history "$@" ;;
    predict) _fleet_drift_predict ;;
    *) die "Usage: dot fleet drift [check|history|predict]" ;;
  esac
}
