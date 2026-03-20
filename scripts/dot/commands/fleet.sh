#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Dotfiles CLI - Fleet Commands
# fleet status|nodes|drift|events|namespace

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"
# shellcheck source=../lib/log.sh
source "$SCRIPT_DIR/../lib/log.sh"

dot_ui_command_banner "Fleet" "${1:-}"

_FLEET_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/fleet"
_FLEET_EVENTS_FILE="$_FLEET_STATE_DIR/events.jsonl"

_fleet_enabled() {
  local data_file
  data_file="$(resolve_source_dir)/.chezmoidata.toml"
  if [[ -f "$data_file" ]] && grep -q '^enabled = true' "$data_file" 2>/dev/null; then
    return 0
  fi
  return 1
}

_fleet_node_id() {
  local data_file node_id=""
  data_file="$(resolve_source_dir)/.chezmoidata.toml"
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
  data_file="$(resolve_source_dir)/.chezmoidata.toml"
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
  data_file="$(resolve_source_dir)/.chezmoidata.toml"
  if [[ -f "$data_file" ]]; then
    endpoint="$(sed -n 's/^endpoint = "\(.*\)"/\1/p' "$data_file" | head -1)"
  fi
  if [[ -n "$endpoint" ]] && [[ "$endpoint" == https://* ]]; then
    curl -fsSL -X POST -H "Content-Type: application/json" \
      -d "$payload" "$endpoint" >/dev/null 2>&1 || true
  fi
}

cmd_fleet_status() {
  local json_mode=0
  [[ "${1:-}" == "--json" || "${1:-}" == "-j" ]] && json_mode=1

  local node_id namespace version os_type kernel shell_type
  node_id="$(_fleet_node_id)"
  namespace="$(_fleet_namespace)"
  version="$(dotfiles_version)"
  os_type="$(uname -s)"
  kernel="$(uname -r)"
  shell_type="${SHELL##*/}"

  local drift_status="clean"
  if has_command chezmoi; then
    local drift_output
    drift_output="$(chezmoi status 2>/dev/null || true)"
    if [[ -n "$drift_output" ]]; then
      drift_status="drifted"
    fi
  fi

  local last_apply=""
  local state_log="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/dot.log"
  if [[ -f "$state_log" ]]; then
    last_apply="$(grep 'apply' "$state_log" 2>/dev/null | tail -1 | sed -n 's/^\[\([^]]*\)\].*/\1/p')"
  fi

  if [[ "$json_mode" -eq 1 ]]; then
    printf '{"node_id":"%s","namespace":"%s","version":"%s","os":"%s","kernel":"%s","shell":"%s","drift":"%s","last_apply":"%s"}\n' \
      "$node_id" "$namespace" "$version" "$os_type" "$kernel" "$shell_type" "$drift_status" "$last_apply"
    return 0
  fi

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

  _fleet_emit_event "status" "ok" "version=$version" "drift=$drift_status"
}

cmd_fleet_drift() {
  ui_header "Fleet Drift Report"
  echo ""

  if ! has_command chezmoi; then
    ui_err "chezmoi" "not installed"
    return 1
  fi

  local drift_output
  drift_output="$(chezmoi status 2>/dev/null || true)"
  if [[ -z "$drift_output" ]]; then
    ui_ok "Status" "No drift detected"
    _fleet_emit_event "drift_check" "clean"
    return 0
  fi

  ui_warn "Status" "Configuration drift detected"
  echo ""
  printf '%s\n' "$drift_output" | while IFS= read -r line; do
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
  done

  _fleet_emit_event "drift_check" "drifted" "count=$(echo "$drift_output" | wc -l | tr -d ' ')"
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

cmd_fleet_namespace() {
  local subcommand="${1:-show}"
  shift || true

  case "$subcommand" in
    show)
      local ns
      ns="$(_fleet_namespace)"
      ui_header "Fleet Namespace"
      ui_ok "Active" "$ns"

      local data_file
      data_file="$(resolve_source_dir)/.chezmoidata.toml"
      if [[ -f "$data_file" ]]; then
        echo ""
        ui_section "Available Namespaces"
        grep '^\[namespaces\.' "$data_file" | sed 's/\[namespaces\.\(.*\)\]/\1/' | while IFS= read -r name; do
          if [[ "$name" == "$ns" ]]; then
            ui_ok "$name" "[active]"
          else
            ui_info "$name" ""
          fi
        done
      fi
      ;;
    set)
      local new_ns="${1:-}"
      [[ -n "$new_ns" ]] || die "Usage: dot fleet namespace set <name>"
      validate_name "$new_ns" "namespace"
      local data_file
      data_file="$(resolve_source_dir)/.chezmoidata.toml"
      if grep -q "^namespace = " "$data_file" 2>/dev/null; then
        if sed --version >/dev/null 2>&1; then
          sed -i "s/^namespace = \".*\"/namespace = \"$new_ns\"/" "$data_file"
        else
          sed -i '' "s/^namespace = \".*\"/namespace = \"$new_ns\"/" "$data_file"
        fi
      fi
      ui_ok "Namespace" "Set to '$new_ns'. Run 'dot sync' to apply."
      _fleet_emit_event "namespace_set" "ok" "namespace=$new_ns"
      ;;
    *)
      die "Usage: dot fleet namespace [show|set <name>]"
      ;;
  esac
}

cmd_fleet() {
  local subcommand="${1:-status}"
  if [[ "${1:-}" == --* ]] || [[ -z "${1:-}" ]]; then
    subcommand="status"
  else
    shift || true
  fi

  case "$subcommand" in
    status)
      cmd_fleet_status "$@"
      ;;
    drift)
      cmd_fleet_drift "$@"
      ;;
    events)
      cmd_fleet_events "$@"
      ;;
    namespace | ns)
      cmd_fleet_namespace "$@"
      ;;
    *)
      ui_header "Fleet Commands"
      echo ""
      ui_info "Usage" "dot fleet [command]"
      echo ""
      ui_ok "status" "Show this node's fleet status (--json for machine output)"
      ui_ok "drift" "Check for configuration drift"
      ui_ok "events" "Show recent fleet events"
      ui_ok "namespace" "Show or set the active namespace"
      ;;
  esac
}

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
