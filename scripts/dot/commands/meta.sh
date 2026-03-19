#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Dotfiles CLI - Meta Commands
# upgrade, prewarm, docs, learn, keys, sandbox, mcp, mode, agent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"
# shellcheck source=../lib/log.sh
source "$SCRIPT_DIR/../lib/log.sh"

dot_ui_command_banner "Meta" "${1:-}"

cmd_upgrade() {
  local src_dir
  src_dir="$(require_source_dir)"

  if [ -f "$src_dir/nix/flake.nix" ] && has_command nix; then
    ui_info "Updating Nix flake"
    (cd "$src_dir" && nix flake update) || true
    ui_info "Running Nix garbage collection"
    nix-collect-garbage -d || true
  fi

  ui_info "Updating dotfiles"
  chezmoi update || true

  if has_command nvim; then
    ui_info "Updating Neovim plugins"
    nvim --headless "+Lazy! sync" +qa || true
  fi

  if [ "${DOTFILES_FONTS:-}" = "1" ]; then
    if [ -f "$src_dir/scripts/fonts/install-nerd-fonts.sh" ]; then
      ui_info "Installing Nerd Fonts"
      sh "$src_dir/scripts/fonts/install-nerd-fonts.sh"
    fi
  fi
}

cmd_prewarm() {
  local src_dir
  # Clear caches first
  ui_info "Cache" "Clearing shell initialization caches"
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
  rm -rf "$cache_dir/zsh"/*-init.zsh "$cache_dir/zsh"/*.zwc 2>/dev/null || true
  rm -rf "$cache_dir/bash"/*-init.bash 2>/dev/null || true
  rm -rf "$cache_dir/fish"/*-init.fish 2>/dev/null || true
  rm -rf "$cache_dir/nushell"/*.nu 2>/dev/null || true
  ui_info "Cache" "Cleared. Regenerating..."
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/ops/prewarm.sh" ]; then
    bash "$src_dir/scripts/ops/prewarm.sh"
  fi
}

cmd_docs() {
  local src_dir
  src_dir="$(resolve_source_dir)"

  if [ -n "$src_dir" ] && [ -f "$src_dir/README.md" ]; then
    if has_command glow; then
      glow "$src_dir/README.md"
    else
      exec cat "$src_dir/README.md"
    fi
  else
    die "README not found."
  fi
}

cmd_learn() {
  local dot_bin
  dot_bin="$(dirname "${BASH_SOURCE[0]}")/../../../dot_local/bin"
  if [ -f "$dot_bin/executable_tour" ]; then
    exec bash "$dot_bin/executable_tour" "$@"
  fi
  # Fallback to ops script
  run_script "scripts/ops/tour.sh" "Tour script" "$@"
}

cmd_keys() {
  local src_dir
  src_dir="$(resolve_source_dir)"

  if [[ "${1:-}" == "sign-check" ]]; then
    ui_header "Git Signing Status"
    local signing_key="" format="" key_file=""
    signing_key="$(git config --global user.signingkey 2>/dev/null || true)"
    format="$(git config --global gpg.format 2>/dev/null || true)"
    if [[ -z "$signing_key" ]]; then
      ui_warn "No signing key configured (git config --global user.signingkey)"
    else
      ui_info "Key" "$signing_key"
      ui_info "Format" "${format:-gpg}"
      if [[ "$format" == "ssh" ]]; then
        key_file="${signing_key/#\~/$HOME}"
        if [[ -f "$key_file" ]]; then
          ui_info "Status" "SSH key file exists: $key_file"
        else
          ui_warn "SSH key file not found: $key_file"
        fi
      else
        if has_command gpg && gpg --list-keys "$signing_key" >/dev/null 2>&1; then
          ui_info "Status" "GPG key found in keyring"
        else
          ui_warn "GPG key not found in keyring: $signing_key"
        fi
      fi
    fi
    return 0
  fi

  if [ -n "$src_dir" ] && [ -f "$src_dir/docs/KEYS.md" ]; then
    if [ -n "${1:-}" ]; then
      rg -i --fixed-strings --context 1 "${1:-}" "$src_dir/docs/KEYS.md" || true
    else
      exec cat "$src_dir/docs/KEYS.md"
    fi
  else
    run_script "scripts/diagnostics/keys.sh" "Keys script" "$@"
  fi
}

cmd_sandbox() {
  local src_dir
  src_dir="$(require_source_dir)"

  if has_command docker; then
    ui_info "Launching sandbox via Docker"
    docker build -f "$src_dir/tests/Dockerfile.sandbox" -t dotfiles-sandbox "$src_dir"
    exec docker run --rm -it dotfiles-sandbox
  elif has_command podman; then
    ui_info "Launching sandbox via Podman"
    podman build -f "$src_dir/tests/Dockerfile.sandbox" -t dotfiles-sandbox "$src_dir"
    exec podman run --rm -it dotfiles-sandbox
  else
    die "Docker or Podman is required for sandbox."
  fi
}

cmd_mcp() {
  local subcommand="${1:-doctor}"
  if [[ "${1:-}" == --* ]] || [[ -z "${1:-}" ]]; then
    subcommand="doctor"
  else
    shift || true
  fi
  case "$subcommand" in
    doctor)
      if [[ "${1:-}" == "doctor" ]]; then
        shift || true
      fi
      run_script "scripts/diagnostics/mcp-doctor.sh" "MCP doctor script" "$@"
      ;;
    registry)
      local repo_root registry_file json_mode=0
      repo_root="$(require_source_dir)"
      registry_file="${MCP_REGISTRY_CONFIG:-$repo_root/dot_config/dotfiles/mcp-registry.json}"
      if [[ "${1:-}" == "registry" ]]; then
        shift || true
      fi
      if [[ "${1:-}" == "--json" ]]; then
        json_mode=1
      fi
      if [[ ! -f "$registry_file" ]]; then
        die "MCP registry not found: $registry_file"
      fi
      if [[ "$json_mode" -eq 1 ]]; then
        exec cat "$registry_file"
      fi
      if command -v jq >/dev/null 2>&1; then
        ui_header "MCP Registry"
        jq -r '
          .servers
          | to_entries[]
          | "\(.key)\t\(.value.transport)\t\(.value.launcher)\t\(.value.package // .value.url // "local")"
        ' "$registry_file" | while IFS=$'\t' read -r name transport launcher target; do
          ui_ok "$name" "$transport via $launcher -> $target"
        done
      else
        exec cat "$registry_file"
      fi
      ;;
    *)
      echo "Usage: dot mcp [doctor|registry]" >&2
      exit 1
      ;;
  esac
}

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
      jq -r '.profiles | to_entries[] | "\(.key)\t\(.value.description)"' "$(_agent_profiles_file)" \
        | while IFS=$'\t' read -r name description; do
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
      export DOT_AGENT_PROFILE="$name"
      export DOT_AGENT_APPROVAL="$(_agent_profile_field "$name" "approval")"
      export DOT_AGENT_FILESYSTEM="$(_agent_profile_field "$name" "filesystem")"
      export DOT_AGENT_NETWORK="$(_agent_profile_field "$name" "network")"
      export DOT_AGENT_MCP_PROFILE="$(_agent_profile_field "$name" "mcpProfile")"
      export DOT_AGENT_MAX_STEPS="$(_agent_profile_field "$name" "maxSteps")"
      ui_info "Agent mode" "$name"
      dot_agent_session_log "run_start" "$name" "running" "argv=$*"
      "$@"
      local exit_code=$?
      if [[ "$exit_code" -eq 0 ]]; then
        dot_agent_session_log "run_finish" "$name" "ok" "exit_code=$exit_code"
      else
        dot_agent_session_log "run_finish" "$name" "failed" "exit_code=$exit_code"
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
    *)
      echo "Usage: dot mode [list|current|show|set|run|doctor|card|log]" >&2
      exit 1
      ;;
  esac
}

# Dispatch
case "${1:-}" in
  upgrade)
    shift
    cmd_upgrade "$@"
    ;;
  cache-refresh | prewarm)
    shift
    cmd_prewarm "$@"
    ;;
  docs)
    shift
    cmd_docs "$@"
    ;;
  learn)
    shift
    cmd_learn "$@"
    ;;
  keys)
    shift
    cmd_keys "$@"
    ;;
  sandbox)
    shift
    cmd_sandbox "$@"
    ;;
  mcp)
    shift
    cmd_mcp "$@"
    ;;
  mode | agent)
    shift
    cmd_mode "$@"
    ;;
  *)
    echo "Unknown meta command: ${1:-}" >&2
    exit 1
    ;;
esac
