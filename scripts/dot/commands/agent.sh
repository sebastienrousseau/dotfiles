#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Dotfiles CLI - Agent Mode Commands (extracted from meta.sh)
# mode list|current|show|set|run|doctor|card|log|checkpoint|conformance

set -euo pipefail

# Guard: only define functions, do not execute on source.
# These functions are sourced by meta.sh for dispatch.

_agent_repo_root() {
  require_source_dir
}

_agent_profiles_file() {
  local repo_root
  repo_root="$(_agent_repo_root)"
  echo "${AGENT_PROFILE_CONFIG:-$repo_root/dot_config/dotfiles/agent-profiles.json}"
}

_agent_state_file() {
  echo "${AGENT_STATE_FILE:-$HOME/.config/dotfiles/agent-mode.env}"
}

_agent_default_profile() {
  local file
  file="$(_agent_profiles_file)"
  jq -r '.defaultProfile' "$file"
}

_agent_current_profile() {
  local state_file current
  state_file="$(_agent_state_file)"
  if [[ -f "$state_file" ]]; then
    current="$(sed -n 's/^DOT_AGENT_PROFILE=//p' "$state_file" | tail -n 1)"
    if [[ -n "$current" ]]; then
      echo "$current"
      return 0
    fi
  fi
  _agent_default_profile
}

_agent_profile_exists() {
  local name="$1"
  jq -e --arg name "$name" '.profiles[$name]' "$(_agent_profiles_file)" >/dev/null 2>&1
}

_agent_profile_field() {
  local name="$1" field="$2"
  jq -r --arg name "$name" --arg field "$field" '.profiles[$name][$field]' "$(_agent_profiles_file)"
}

_agent_assert_dependencies() {
  local file
  file="$(_agent_profiles_file)"
  if [[ ! -f "$file" ]]; then
    die "Agent profile config not found: $file"
  fi
  if ! command -v jq >/dev/null 2>&1; then
    die "jq is required for dot mode"
  fi
}

_agent_card_file() {
  local repo_root
  repo_root="$(_agent_repo_root)"
  echo "${AGENT_CARD_CONFIG:-$repo_root/dot_config/dotfiles/agent-card.json}"
}

_agent_checkpoint_file() {
  local checkpoint_id="$1"
  echo "$(dot_agent_checkpoint_dir)/${checkpoint_id}.json"
}

_agent_apply_profile_env() {
  local name="$1"
  export DOT_AGENT_PROFILE="$name"
  export DOT_AGENT_APPROVAL="$(_agent_profile_field "$name" "approval")"
  export DOT_AGENT_FILESYSTEM="$(_agent_profile_field "$name" "filesystem")"
  export DOT_AGENT_NETWORK="$(_agent_profile_field "$name" "network")"
  export DOT_AGENT_MCP_PROFILE="$(_agent_profile_field "$name" "mcpProfile")"
  export DOT_AGENT_MAX_STEPS="$(_agent_profile_field "$name" "maxSteps")"
}

_agent_rbac_enforcement() {
  local file
  file="$(_agent_profiles_file)"
  jq -r '.rbac.enforcement // "advisory"' "$file"
}

_agent_current_role() {
  local state_file role
  state_file="$(_agent_state_file)"
  if [[ -f "$state_file" ]]; then
    role="$(sed -n 's/^DOT_AGENT_ROLE=//p' "$state_file" | tail -n 1)"
    if [[ -n "$role" ]]; then
      echo "$role"
      return 0
    fi
  fi
  jq -r '.rbac.defaultRole // "developer"' "$(_agent_profiles_file)"
}

_agent_role_allows_profile() {
  local role="$1" profile="$2"
  local file
  file="$(_agent_profiles_file)"
  jq -e --arg role "$role" --arg profile "$profile" '
    .rbac.roles[$role].allowedProfiles // [] | index($profile)
  ' "$file" >/dev/null 2>&1
}

_agent_enforce_rbac() {
  local target_profile="$1"
  local enforcement role
  enforcement="$(_agent_rbac_enforcement)"
  role="$(_agent_current_role)"
  if _agent_role_allows_profile "$role" "$target_profile"; then
    return 0
  fi
  if [[ "$enforcement" == "strict" ]]; then
    die "RBAC: role '$role' is not allowed to use profile '$target_profile' (enforcement: strict)"
  else
    ui_warn "RBAC" "role '$role' is not recommended for profile '$target_profile' (enforcement: advisory)"
  fi
}

cmd_mode() {
  _agent_assert_dependencies

  local subcommand="${1:-current}"
  if [[ -z "${1:-}" ]] || [[ "${1:-}" == --* ]]; then
    subcommand="current"
  else
    shift || true
  fi

  case "$subcommand" in
    list)
      local current
      current="$(_agent_current_profile)"
      dot_agent_session_log "list" "$current" "ok"
      ui_header "Agent Modes"
      jq -r '.profiles | to_entries[] | "\(.key)\t\(.value.description)"' "$(_agent_profiles_file)" |
        while IFS=$'\t' read -r name description; do
          if [[ "$name" == "$current" ]]; then
            ui_ok "$name" "$description [current]"
          else
            ui_info "$name" "$description"
          fi
        done
      ;;
    current)
      local current
      current="$(_agent_current_profile)"
      dot_agent_session_log "current" "$current" "ok"
      ui_header "Agent Mode"
      ui_ok "Profile" "$current"
      ui_ok "Approval" "$(_agent_profile_field "$current" "approval")"
      ui_ok "Filesystem" "$(_agent_profile_field "$current" "filesystem")"
      ui_ok "Network" "$(_agent_profile_field "$current" "network")"
      ui_ok "MCP" "$(_agent_profile_field "$current" "mcpProfile")"
      ;;
    show)
      local name="${1:-}"
      [[ -n "$name" ]] || die "Usage: dot mode show <profile>"
      _agent_profile_exists "$name" || die "Unknown agent profile: $name"
      dot_agent_session_log "show" "$name" "ok"
      ui_header "Agent Mode"
      ui_ok "Profile" "$name"
      ui_ok "Description" "$(_agent_profile_field "$name" "description")"
      ui_ok "Approval" "$(_agent_profile_field "$name" "approval")"
      ui_ok "Filesystem" "$(_agent_profile_field "$name" "filesystem")"
      ui_ok "Network" "$(_agent_profile_field "$name" "network")"
      ui_ok "Max steps" "$(_agent_profile_field "$name" "maxSteps")"
      ui_ok "MCP" "$(_agent_profile_field "$name" "mcpProfile")"
      ;;
    set)
      local name="${1:-}" state_file
      [[ -n "$name" ]] || die "Usage: dot mode set <profile>"
      _agent_profile_exists "$name" || die "Unknown agent profile: $name"
      _agent_enforce_rbac "$name"
      state_file="$(_agent_state_file)"
      mkdir -p "$(dirname "$state_file")"
      cat >"$state_file" <<EOF
DOT_AGENT_PROFILE=$name
DOT_AGENT_APPROVAL=$(_agent_profile_field "$name" "approval")
DOT_AGENT_FILESYSTEM=$(_agent_profile_field "$name" "filesystem")
DOT_AGENT_NETWORK=$(_agent_profile_field "$name" "network")
DOT_AGENT_MCP_PROFILE=$(_agent_profile_field "$name" "mcpProfile")
DOT_AGENT_MAX_STEPS=$(_agent_profile_field "$name" "maxSteps")
EOF
      dot_agent_session_log "set" "$name" "ok" "state_file=$state_file"
      ui_ok "Agent mode" "$name"
      ui_info "State file" "$state_file"
      ;;
    run)
      local name="${1:-}" current
      if [[ -n "$name" ]] && _agent_profile_exists "$name"; then
        shift || true
      else
        name="$(_agent_current_profile)"
      fi
      [[ $# -gt 0 ]] || die "Usage: dot mode run [profile] <command> [args...]"
      _agent_apply_profile_env "$name"
      local checkpoint_file checkpoint_id
      checkpoint_file="$(dot_agent_checkpoint_create "$name" "ready" "$@")"
      checkpoint_id="$(basename "$checkpoint_file" .json)"
      ui_info "Agent mode" "$name"
      dot_agent_session_log "run_start" "$name" "running" "argv=$*" "checkpoint_id=$checkpoint_id"
      set +e
      "$@"
      local exit_code=$?
      set -e
      if [[ "$exit_code" -eq 0 ]]; then
        dot_agent_session_log "run_finish" "$name" "ok" "exit_code=$exit_code" "checkpoint_id=$checkpoint_id"
      else
        dot_agent_session_log "run_finish" "$name" "failed" "exit_code=$exit_code" "checkpoint_id=$checkpoint_id"
      fi
      return "$exit_code"
      ;;
    doctor)
      local file
      file="$(_agent_profiles_file)"
      dot_agent_session_log "doctor" "$(_agent_current_profile)" "ok"
      ui_header "Agent Mode Doctor"
      if jq empty "$file" >/dev/null 2>&1; then
        ui_ok "Profile config" "$file"
      else
        die "Invalid JSON: $file"
      fi
      jq -e '.profiles[.defaultProfile]' "$file" >/dev/null 2>&1 || die "Default profile missing"
      ui_ok "Default profile" "$(_agent_default_profile)"
      ;;
    card)
      local card_file json_mode=0
      card_file="$(_agent_card_file)"
      [[ -f "$card_file" ]] || die "Agent card not found: $card_file"
      if [[ "${1:-}" == "--json" ]]; then
        json_mode=1
      fi
      dot_agent_session_log "card" "$(_agent_current_profile)" "ok"
      if [[ "$json_mode" -eq 1 ]] || ! command -v jq >/dev/null 2>&1; then
        exec cat "$card_file"
      fi
      ui_header "Agent Card"
      jq -r '
        "Name\t\(.name)",
        "Version\t\(.version)",
        "Protocols\t\(.protocols | join(", "))",
        "Default mode\t\(.defaultProfile)",
        "Support\t\(.platforms | join(", "))"
      ' "$card_file" | while IFS=$'\t' read -r key value; do
        ui_ok "$key" "$value"
      done
      ;;
    log)
      dot_agent_session_log "log" "$(_agent_current_profile)" "ok"
      dot_agent_session_tail "${1:-20}"
      ;;
    checkpoint)
      local action="${1:-list}"
      shift || true
      case "$action" in
        save)
          local name="${1:-}" checkpoint_file checkpoint_id
          if [[ -n "$name" ]] && _agent_profile_exists "$name"; then
            shift || true
          else
            name="$(_agent_current_profile)"
          fi
          [[ $# -gt 0 ]] || die "Usage: dot agent checkpoint save [profile] <command> [args...]"
          _agent_apply_profile_env "$name"
          checkpoint_file="$(dot_agent_checkpoint_create "$name" "saved" "$@")"
          checkpoint_id="$(basename "$checkpoint_file" .json)"
          dot_agent_session_log "checkpoint_save" "$name" "ok" "checkpoint_id=$checkpoint_id"
          ui_header "Agent Checkpoint"
          ui_ok "ID" "$checkpoint_id"
          ui_ok "Profile" "$name"
          ui_ok "Command" "$*"
          ui_ok "File" "$checkpoint_file"
          ;;
        list)
          local count="${1:-20}"
          dot_agent_session_log "checkpoint_list" "$(_agent_current_profile)" "ok"
          if ! command -v jq >/dev/null 2>&1; then
            dot_agent_checkpoint_tail "$count"
            return 0
          fi
          ui_header "Agent Checkpoints"
          dot_agent_checkpoint_tail "$count" | jq -r '"\(.id)\t\(.profile)\t\(.status)\t\(.created_at)\t\(.argv | join(" "))"' | while IFS=$'\t' read -r id profile status created_at argv; do
            ui_ok "$id" "$profile / $status / $created_at / $argv"
          done
          ;;
        show)
          local checkpoint_id="${1:-}" checkpoint_file json_mode=0
          [[ -n "$checkpoint_id" ]] || die "Usage: dot agent checkpoint show <id> [--json]"
          shift || true
          [[ "${1:-}" == "--json" || "${1:-}" == "-j" ]] && json_mode=1
          checkpoint_file="$(_agent_checkpoint_file "$checkpoint_id")"
          [[ -f "$checkpoint_file" ]] || die "Checkpoint not found: $checkpoint_id"
          dot_agent_session_log "checkpoint_show" "$(_agent_current_profile)" "ok" "checkpoint_id=$checkpoint_id"
          if [[ "$json_mode" -eq 1 ]] || ! command -v jq >/dev/null 2>&1; then
            exec cat "$checkpoint_file"
          fi
          ui_header "Agent Checkpoint"
          jq -r '"ID\t\(.id)",
            "Profile\t\(.profile)",
            "Status\t\(.status)",
            "Created\t\(.created_at)",
            "Command\t\(.argv | join(" "))"' "$checkpoint_file" | while IFS=$'\t' read -r key value; do
            ui_ok "$key" "$value"
          done
          ;;
        replay)
          local checkpoint_id="${1:-}" checkpoint_file replay_profile
          local -a replay_argv=()
          [[ -n "$checkpoint_id" ]] || die "Usage: dot agent checkpoint replay <id>"
          checkpoint_file="$(_agent_checkpoint_file "$checkpoint_id")"
          [[ -f "$checkpoint_file" ]] || die "Checkpoint not found: $checkpoint_id"
          replay_profile="$(jq -r '.profile' "$checkpoint_file")"
          while IFS= read -r item; do
            replay_argv+=("$item")
          done < <(jq -r '.argv[]' "$checkpoint_file")
          [[ "${#replay_argv[@]}" -gt 0 ]] || die "Checkpoint has no replayable command: $checkpoint_id"
          _agent_apply_profile_env "$replay_profile"
          dot_agent_session_log "checkpoint_replay" "$replay_profile" "running" "checkpoint_id=$checkpoint_id"
          set +e
          "${replay_argv[@]}"
          local exit_code=$?
          set -e
          if [[ "$exit_code" -eq 0 ]]; then
            dot_agent_session_log "checkpoint_replay_finish" "$replay_profile" "ok" "checkpoint_id=$checkpoint_id" "exit_code=$exit_code"
          else
            dot_agent_session_log "checkpoint_replay_finish" "$replay_profile" "failed" "checkpoint_id=$checkpoint_id" "exit_code=$exit_code"
          fi
          return "$exit_code"
          ;;
        *)
          echo "Usage: dot agent checkpoint [save|list|show|replay]" >&2
          exit 1
          ;;
      esac
      ;;
    delegate)
      local delegate_name="${1:-}"
      [[ -n "$delegate_name" ]] || die "Usage: dot agent delegate <name> <command> [args...]"
      shift || true
      [[ $# -gt 0 ]] || die "Usage: dot agent delegate <name> <command> [args...]"
      local profiles_file current_profile
      profiles_file="$(_agent_profiles_file)"
      current_profile="$(_agent_current_profile)"
      # Check delegation is enabled
      local delegation_enabled
      delegation_enabled="$(jq -r '.delegation.enabled // false' "$profiles_file")"
      [[ "$delegation_enabled" == "true" ]] || die "Delegation is not enabled in agent-profiles.json"
      # Check current profile can delegate
      local can_delegate
      can_delegate="$(jq -r --arg p "$current_profile" '.profiles[$p].canDelegate // false' "$profiles_file")"
      [[ "$can_delegate" == "true" ]] || die "Profile '$current_profile' cannot delegate"
      # Check delegate name exists
      jq -e --arg d "$delegate_name" '.delegation.allowedDelegates[$d]' "$profiles_file" >/dev/null 2>&1 || die "Unknown delegate: $delegate_name"
      # Read delegate config
      local delegate_profile delegate_timeout delegate_max_steps
      delegate_profile="$(jq -r --arg d "$delegate_name" '.delegation.allowedDelegates[$d].profile' "$profiles_file")"
      delegate_timeout="$(jq -r --arg d "$delegate_name" '.delegation.allowedDelegates[$d].timeout // 300' "$profiles_file")"
      delegate_max_steps="$(jq -r --arg d "$delegate_name" '.delegation.allowedDelegates[$d].maxSteps // 4' "$profiles_file")"
      # Apply delegate profile env
      _agent_apply_profile_env "$delegate_profile"
      export DOT_AGENT_MAX_STEPS="$delegate_max_steps"
      export DOT_AGENT_DELEGATE="$delegate_name"
      export DOT_AGENT_PARENT_PROFILE="$current_profile"
      dot_agent_session_log "delegate_start" "$delegate_profile" "running" "delegate=$delegate_name" "parent=$current_profile" "timeout=$delegate_timeout"
      ui_info "Delegating" "$delegate_name (profile: $delegate_profile, timeout: ${delegate_timeout}s)"
      set +e
      timeout "$delegate_timeout" "$@"
      local exit_code=$?
      set -e
      if [[ "$exit_code" -eq 0 ]]; then
        dot_agent_session_log "delegate_finish" "$delegate_profile" "ok" "delegate=$delegate_name" "exit_code=$exit_code"
        ui_ok "Delegate" "$delegate_name completed"
      else
        dot_agent_session_log "delegate_finish" "$delegate_profile" "failed" "delegate=$delegate_name" "exit_code=$exit_code"
        ui_err "Delegate" "$delegate_name failed (exit $exit_code)"
      fi
      return "$exit_code"
      ;;
    a2a-card)
      local a2a_card_file json_mode=0 validate_mode=0 strict_mode=0
      local repo_root
      repo_root="$(_agent_repo_root)"
      a2a_card_file="$repo_root/.well-known/agent-card.json"
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --json | -j)
            json_mode=1
            shift
            ;;
          --validate | --strict | -s)
            validate_mode=1
            strict_mode=1
            shift
            ;;
          *) shift ;;
        esac
      done
      [[ -f "$a2a_card_file" ]] || die "A2A v0.3 card not found: $a2a_card_file"
      dot_agent_session_log "a2a-card" "$(_agent_current_profile)" "ok"
      if [[ "$json_mode" -eq 1 ]]; then
        exec cat "$a2a_card_file"
      fi
      if [[ "$validate_mode" -eq 1 ]]; then
        local v_issues=0
        jq empty "$a2a_card_file" >/dev/null 2>&1 || {
          ui_err "JSON" "invalid"
          exit 1
        }
        ui_header "A2A v0.3 Card Validation"
        local sv
        sv="$(jq -r '.specVersion // empty' "$a2a_card_file")"
        if [[ "$sv" == "0.3" ]]; then ui_ok "specVersion" "$sv"; else
          ui_err "specVersion" "expected 0.3, got $sv"
          v_issues=$((v_issues + 1))
        fi
        if jq -e '.skills | type == "array" and length > 0' "$a2a_card_file" >/dev/null 2>&1; then
          ui_ok "skills" "$(jq '.skills | length' "$a2a_card_file") skills"
        else
          ui_err "skills" "missing or empty"
          v_issues=$((v_issues + 1))
        fi
        if jq -e '.authentication' "$a2a_card_file" >/dev/null 2>&1; then ui_ok "authentication" "present"; else
          ui_err "authentication" "missing"
          v_issues=$((v_issues + 1))
        fi
        if jq -e '.signing.method' "$a2a_card_file" >/dev/null 2>&1; then ui_ok "signing" "$(jq -r '.signing.method' "$a2a_card_file")"; else
          ui_err "signing" "missing method"
          v_issues=$((v_issues + 1))
        fi
        if [[ "$v_issues" -gt 0 && "$strict_mode" -eq 1 ]]; then exit 1; fi
        return 0
      fi
      ui_header "A2A v0.3 Agent Card"
      jq -r '
        "Name\t\(.name)",
        "Version\t\(.version)",
        "Spec\t\(.specVersion)",
        "Protocols\t\(.protocols | join(", "))",
        "Skills\t\(.skills | length) defined",
        "Auth\t\(.authentication.schemes | join(", "))",
        "Signing\t\(.signing.method)"
      ' "$a2a_card_file" | while IFS=$'\t' read -r key value; do
        ui_ok "$key" "$value"
      done
      ;;
    conformance)
      dot_agent_session_log "conformance" "$(_agent_current_profile)" "ok"
      run_script "scripts/diagnostics/a2a-conformance.sh" "A2A conformance script" "$@"
      ;;
    *)
      echo "Usage: dot mode [list|current|show|set|run|doctor|card|log|checkpoint|conformance|a2a-card]" >&2
      exit 1
      ;;
  esac
}
