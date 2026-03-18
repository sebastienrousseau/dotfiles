#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Dotfiles CLI - Meta Commands
# upgrade, prewarm, docs, learn, keys, sandbox, mcp

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

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
    *)
      echo "Usage: dot mcp [doctor]" >&2
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
  *)
    echo "Unknown meta command: ${1:-}" >&2
    exit 1
    ;;
esac
