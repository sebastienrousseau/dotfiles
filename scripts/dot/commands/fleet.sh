#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Fleet Commands
# fleet status|nodes|drift|events|namespace

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"
# shellcheck source=../../../lib/dot/log.sh
source "$SCRIPT_DIR/../../../lib/dot/log.sh"

dot_ui_command_banner "Fleet" "${1:-}"

_FLEET_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/fleet"
_FLEET_EVENTS_FILE="$_FLEET_STATE_DIR/events.jsonl"

_fleet_enabled() {
  local data_file
  data_file="$(resolve_chezmoi_source_dir)/.chezmoidata.toml"
  if [[ -f "$data_file" ]] && grep -q '^enabled = true' "$data_file" 2>/dev/null; then
    return 0
  fi
  return 1
}

_fleet_node_id() {
  local data_file node_id=""
  data_file="$(resolve_chezmoi_source_dir)/.chezmoidata.toml"
  if [[ -f "$data_file" ]]; then
    node_id="$(sed -n 's/^node_id = "\(.*\)"/\1/p' "$data_file" | head -1)"
  fi
  if [[ -z "$node_id" ]]; then
    node_id="$(hostname -s 2>/dev/null || echo "unknown")"
  fi
  printf '%s\n' "$node_id"
}

_fleet_namespace() {
  local data_file ns=""
  data_file="$(resolve_chezmoi_source_dir)/.chezmoidata.toml"
  if [[ -f "$data_file" ]]; then
    ns="$(sed -n 's/^namespace = "\(.*\)"/\1/p' "$data_file" | head -1)"
  fi
  printf '%s\n' "${ns:-default}"
}

_fleet_emit_event() {
  local event="$1" status="${2:-ok}"
  shift 2 || true
  local ts node_id namespace
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  node_id="$(_fleet_node_id)"
  namespace="$(_fleet_namespace)"
  mkdir -p "$_FLEET_STATE_DIR" 2>/dev/null || return 0
  local payload
  payload=$(printf '{"time":"%s","event":"%s","status":"%s","node_id":"%s","namespace":"%s","trace_id":"%s"' \
    "$ts" "$event" "$status" "$node_id" "$namespace" "$DOT_TRACE_ID")
  while [[ $# -gt 0 ]]; do
    payload+=$(printf ',"%s":"%s"' "${1%%=*}" "${1#*=}")
    shift
  done
  payload+='}'
  printf '%s\n' "$payload" >>"$_FLEET_EVENTS_FILE" 2>/dev/null || true

  # Forward to endpoint if configured
  local endpoint=""
  local data_file
  data_file="$(resolve_chezmoi_source_dir)/.chezmoidata.toml"
  if [[ -f "$data_file" ]]; then
    endpoint="$(sed -n 's/^endpoint = "\(.*\)"/\1/p' "$data_file" | head -1)"
  fi
  if [[ -n "$endpoint" ]] && [[ "$endpoint" == https://* ]]; then
    curl --proto '=https' --tlsv1.2 -fsSL -X POST -H "Content-Type: application/json" \
      -d "$payload" "$endpoint" >/dev/null 2>&1 || true
  fi
}

# "clean" or "drifted", from `chezmoi status` when chezmoi is installed.
_fleet_drift_state() {
  local drift_output
  if has_command chezmoi; then
    # --exclude=always: always-run scripts are pending by design, not drift.
    drift_output="$(chezmoi status --exclude=always 2>/dev/null || true)"
    if [[ -n "$drift_output" ]]; then
      echo drifted
      return 0
    fi
  fi
  echo clean
}

# The timestamp of the last apply recorded in dot.log (empty if none).
_fleet_last_apply() {
  local state_log="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/dot.log"
  [[ -f "$state_log" ]] || return 0
  # `set -euo pipefail` at the top of this script kills the whole
  # command when grep matches nothing (rc=1). Wrap the pipeline so
  # `last_apply` cleanly becomes empty and the UI still renders.
  grep 'apply' "$state_log" 2>/dev/null | tail -1 | sed -n 's/^\[\([^]]*\)\].*/\1/p' || true
}

_fleet_status_print() {
  ui_header "Fleet Node Status"
  echo ""
  ui_ok "Node ID" "$node_id"
  ui_ok "Namespace" "$namespace"
  ui_ok "Version" "v$version"
  ui_ok "OS" "$os_type $kernel"
  ui_ok "Shell" "$shell_type"
  if [[ "$drift_status" == "clean" ]]; then
    ui_ok "Drift" "$drift_status"
  else
    ui_warn "Drift" "$drift_status"
  fi
  if [[ -n "$last_apply" ]]; then
    ui_info "Last Apply" "$last_apply"
  fi
}

cmd_fleet_status() {
  local json_mode=0
  [[ "${1:-}" == "--json" || "${1:-}" == "-j" ]] && json_mode=1

  local node_id namespace version os_type kernel shell_type drift_status last_apply
  node_id="$(_fleet_node_id)"
  namespace="$(_fleet_namespace)"
  version="$(dotfiles_version)"
  os_type="$(uname -s)"
  kernel="$(uname -r)"
  shell_type="${SHELL##*/}"
  drift_status="$(_fleet_drift_state)"
  last_apply="$(_fleet_last_apply)"

  if [[ "$json_mode" -eq 1 ]]; then
    printf '{"node_id":"%s","namespace":"%s","version":"%s","os":"%s","kernel":"%s","shell":"%s","drift":"%s","last_apply":"%s"}\n' \
      "$node_id" "$namespace" "$version" "$os_type" "$kernel" "$shell_type" "$drift_status" "$last_apply"
    return 0
  fi

  _fleet_status_print
  _fleet_emit_event "status" "ok" "version=$version" "drift=$drift_status"
}

cmd_fleet_events() {
  local count="${1:-20}"
  if [[ ! -f "$_FLEET_EVENTS_FILE" ]]; then
    ui_info "No fleet events recorded yet."
    ui_info "Events file" "$_FLEET_EVENTS_FILE"
    return 0
  fi

  ui_header "Fleet Events (last $count)"
  echo ""

  if has_command jq; then
    tail -n "$count" "$_FLEET_EVENTS_FILE" | jq -r '"\(.time)\t\(.event)\t\(.status)\t\(.node_id)"' | while IFS=$'\t' read -r time event status node; do
      if [[ "$status" == "ok" || "$status" == "clean" ]]; then
        ui_ok "$event" "$time ($node)"
      else
        ui_warn "$event" "$time ($node)"
      fi
    done
  else
    tail -n "$count" "$_FLEET_EVENTS_FILE"
  fi
}

_fleet_namespace_show() {
  local ns data_file name
  ns="$(_fleet_namespace)"
  ui_header "Fleet Namespace"
  ui_ok "Active" "$ns"

  data_file="$(resolve_chezmoi_source_dir)/.chezmoidata.toml"
  [[ -f "$data_file" ]] || return 0
  echo ""
  ui_section "Available Namespaces"
  # No [namespaces.*] table is the shipped default: grep's 1 must not
  # become the command's exit status under pipefail.
  { grep '^\[namespaces\.' "$data_file" || true; } | sed 's/\[namespaces\.\(.*\)\]/\1/' | while IFS= read -r name; do
    if [[ "$name" == "$ns" ]]; then
      ui_ok "$name" "[active]"
    else
      ui_info "$name" ""
    fi
  done
}

# _fleet_namespace_render <data-file> <out> <name>: write the data file with
# `namespace = "<name>"` set; returns the renderer's status.
_fleet_namespace_render() {
  local data_file="$1" out="$2" new_ns="$3"
  if grep -q "^namespace = " "$data_file"; then
    sed "s/^namespace = \".*\"/namespace = \"$new_ns\"/" "$data_file" >"$out"
    return
  fi
  # No key yet — the shipped .chezmoidata.toml has none, and rewriting
  # only when one already existed made `set` a silent no-op on a fresh
  # checkout while still reporting success. Insert it after the first
  # line: appending at the end would land the key inside whatever
  # [table] the file happens to end with, which TOML reads as a
  # different key entirely. `dot profile set` does the same for
  # `profile`.
  awk -v ns="$new_ns" '
    NR == 1 { print; printf "namespace = \"%s\"\n", ns; inserted = 1; next }
    { print }
    END { if (!inserted) printf "namespace = \"%s\"\n", ns }
  ' "$data_file" >"$out"
}

_fleet_namespace_set() {
  local new_ns="${1:-}" data_file _tmp
  [[ -n "$new_ns" ]] || die "Usage: dot fleet namespace set <name>"
  validate_name "$new_ns" "namespace"
  data_file="$(resolve_chezmoi_source_dir)/.chezmoidata.toml"
  [[ -f "$data_file" ]] || die ".chezmoidata.toml not found: $data_file"
  # Atomic write: render into a tempfile + mv so concurrent
  # `dot fleet namespace set` callers can't corrupt the TOML.
  # Avoids `sed -i` portability dance (GNU `-i` vs BSD `-i ''`).
  _tmp="$(mktemp "${data_file}.XXXXXX")" || die "Cannot create tempfile"
  if ! _fleet_namespace_render "$data_file" "$_tmp" "$new_ns"; then
    rm -f "$_tmp"
    die "Failed to render namespace update"
  fi
  if ! mv "$_tmp" "$data_file"; then
    rm -f "$_tmp"
    die "Failed to commit namespace update"
  fi
  ui_ok "Namespace" "Set to '$new_ns'. Run 'dot sync' to apply."
  _fleet_emit_event "namespace_set" "ok" "namespace=$new_ns"
}

cmd_fleet_namespace() {
  local subcommand="${1:-show}"
  shift || true

  case "$subcommand" in
    show) _fleet_namespace_show ;;
    set) _fleet_namespace_set "$@" ;;
    *) die "Usage: dot fleet namespace [show|set <name>]" ;;
  esac
}

cmd_fleet_enforce() {
  local subcommand="${1:-status}"
  shift || true

  local repo_root
  repo_root="$(resolve_chezmoi_source_dir)"
  [[ -z "$repo_root" ]] && repo_root="$(resolve_source_dir)"
  # Same file `dot mode` enforces against (agent.sh _agent_profiles_file).
  local profiles_file="${AGENT_PROFILE_CONFIG:-$repo_root/dot_config/dotfiles/agent-profiles.json}"

  case "$subcommand" in
    status)
      if [[ ! -f "$profiles_file" ]]; then
        ui_err "Profiles" "agent-profiles.json not found"
        return 1
      fi
      local enforcement
      enforcement="$(jq -r '.rbac.enforcement // "advisory"' "$profiles_file")"
      ui_header "RBAC Enforcement"
      ui_ok "Mode" "$enforcement"
      ui_ok "Default role" "$(jq -r '.rbac.defaultRole // "developer"' "$profiles_file")"
      jq -r '.rbac.roles | to_entries[] | "\(.key)\t\(.value.allowedProfiles | join(", "))"' "$profiles_file" | while IFS=$'\t' read -r role profiles; do
        ui_info "$role" "$profiles"
      done
      ;;
    set)
      local mode="${1:-}"
      [[ -n "$mode" ]] || die "Usage: dot fleet enforce set <advisory|strict>"
      case "$mode" in
        advisory | strict) ;;
        *) die "Invalid enforcement mode: $mode (use advisory or strict)" ;;
      esac
      [[ -f "$profiles_file" ]] || die "agent-profiles.json not found"
      local tmp
      tmp="$(jq --arg mode "$mode" '.rbac.enforcement = $mode' "$profiles_file")"
      printf '%s\n' "$tmp" >"$profiles_file"
      ui_ok "Enforcement" "set to '$mode'"
      _fleet_emit_event "enforcement_set" "ok" "mode=$mode"
      ;;
    *)
      die "Usage: dot fleet enforce [status|set <advisory|strict>]"
      ;;
  esac
}

# `dot fleet <subcommand>` → the function that takes the remaining args.
_FLEET_SUBCOMMANDS="status:cmd_fleet_status drift:cmd_fleet_drift events:cmd_fleet_events
namespace:cmd_fleet_namespace ns:cmd_fleet_namespace enforce:cmd_fleet_enforce
apply:cmd_fleet_apply push:cmd_fleet_apply help:_fleet_print_commands
--help:_fleet_print_commands -h:_fleet_print_commands"

cmd_fleet() {
  local subcommand="${1:-status}" entry
  if [[ "${1:-}" == --* ]] || [[ -z "${1:-}" ]]; then
    subcommand="status"
  else
    shift || true
  fi

  for entry in $_FLEET_SUBCOMMANDS; do
    if [[ "${entry%%:*}" == "$subcommand" ]]; then
      "${entry#*:}" "$@"
      return
    fi
  done
  ui_err "Unknown subcommand" "$subcommand" >&2
  echo "Run 'dot fleet help' for usage." >&2
  _fleet_print_commands >&2
  return 1
}

_fleet_print_commands() {
  ui_header "Fleet Commands"
  echo ""
  ui_info "Usage" "dot fleet [command]"
  echo ""
  ui_ok "status" "Show this node's fleet status (--json for machine output)"
  ui_ok "drift" "Check for configuration drift"
  ui_ok "events" "Show recent fleet events"
  ui_ok "namespace" "Show or set the active namespace"
  ui_ok "enforce" "Show or set RBAC enforcement mode (advisory|strict)"
  ui_ok "apply" "SSH out to every host in fleet.toml and run 'dot sync'"
}

# shellcheck source-path=SCRIPTDIR source=fleet/drift.sh
source "$SCRIPT_DIR/fleet/drift.sh"
# shellcheck source-path=SCRIPTDIR source=fleet/apply.sh
source "$SCRIPT_DIR/fleet/apply.sh"

# Dispatch
case "${1:-}" in
  fleet)
    shift
    cmd_fleet "$@"
    ;;
  *)
    cmd_fleet "$@"
    ;;
esac
