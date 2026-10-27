#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Config Commands (moved from core.sh, tools.sh, diagnostics.sh
# and meta.sh, P2.1). plugins/config/dot-config maps the ADR-020 spellings
# onto these; init.sh and lint.sh sit beside it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"

cmd_apply() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/ops/chezmoi-apply.sh" ]; then
    exec bash "$src_dir/scripts/ops/chezmoi-apply.sh" "$@"
  fi
  exec chezmoi apply "$@"
}

## cmd_sync [--pull] [--check] [args...] — apply; --pull fetches and applies
## (chezmoi-update.sh), --check previews without applying (chezmoi-diff.sh).
## The flags are consumed here: chezmoi apply knows neither of them.
cmd_sync() {
  local pull=0 check=0 arg rest=()
  for arg in "$@"; do
    case "$arg" in
      --pull) pull=1 ;;
      --check) check=1 ;;
      *) rest+=("$arg") ;;
    esac
  done
  if [[ "$pull" -eq 1 ]]; then
    cmd_update ${rest[@]+"${rest[@]}"}
  elif [[ "$check" -eq 1 ]]; then
    cmd_diff ${rest[@]+"${rest[@]}"}
  else
    cmd_apply ${rest[@]+"${rest[@]}"}
  fi
}

cmd_update() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/ops/chezmoi-update.sh" ]; then
    exec bash "$src_dir/scripts/ops/chezmoi-update.sh" "$@"
  fi
  echo "Updating Dotfiles..."
  exec chezmoi update "$@"
}

cmd_add() {
  if [ -z "${1:-}" ]; then
    echo "Usage: dot config add <file>"
    echo ""
    echo "Add a file to the chezmoi source directory."
    echo "The file will be managed by chezmoi from now on."
    exit 1
  fi
  exec chezmoi add "$@"
}

cmd_diff() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/ops/chezmoi-diff.sh" ]; then
    exec bash "$src_dir/scripts/ops/chezmoi-diff.sh" "$@"
  fi
  exec chezmoi diff "$@"
}

cmd_status() {
  local out rc=0
  # Capture chezmoi's stderr too so an actual tool failure surfaces
  # to the user instead of being indistinguishable from a clean tree.
  out="$(chezmoi status "$@" 2>&1)" || rc=$?
  ui_header "Dotfiles Status"
  if [[ "$rc" -ne 0 ]]; then
    ui_err "chezmoi" "exited $rc"
    [[ -n "$out" ]] && printf "%s\n" "$out"
    return "$rc"
  fi
  if [[ -z "$out" ]]; then
    ui_ok "Clean" "no local drift detected"
  else
    printf "%s\n" "$out"
  fi
}

cmd_remove() {
  run_script "scripts/ops/chezmoi-remove.sh" "Remove helper" "$@"
}

cmd_cd() {
  local src_dir
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ]; then
    echo "$src_dir"
  else
    echo "Dotfiles source not found." >&2
    exit 1
  fi
}

cmd_edit() {
  local src_dir
  src_dir="$(require_source_dir)"
  if [ -n "${EDITOR:-}" ]; then
    exec "$EDITOR" "$src_dir"
  elif has_command nvim; then
    exec nvim "$src_dir"
  elif has_command vim; then
    exec vim "$src_dir"
  else
    echo "No editor found. Set \$EDITOR to open $src_dir."
    exit 1
  fi
}

cmd_commit() {
  run_script "dot_local/bin/executable_git-ai-commit" "Git AI commit script" "$@"
}

cmd_uninstall() {
  run_script "scripts/uninstall.sh" "Uninstall script" "$@"
}

cmd_setup() {
  run_script "scripts/ops/setup.sh" "Setup script" "$@"
}

cmd_profile() {
  local data_file
  data_file="$(resolve_chezmoi_source_dir)/.chezmoidata.toml"
  if [[ ! -f "$data_file" ]]; then
    die ".chezmoidata.toml not found"
  fi
  case "${1:-show}" in
    show)
      ui_header "Dotfiles Profile"
      local profile_val
      profile_val="$(grep '^profile' "$data_file" | head -1 | sed 's/.*=[[:space:]]*"\(.*\)"/\1/')"
      ui_info "Profile" "${profile_val:-default}"
      echo ""
      ui_section "Feature Flags"
      grep -A 100 '^\[features\]' "$data_file" | tail -n +2 | while IFS= read -r line; do
        [[ "$line" =~ ^\[ ]] && break
        [[ -z "$line" || "$line" =~ ^# ]] && continue
        local key val
        key="${line%%=*}"
        key="${key// /}"
        val="${line#*=}"
        val="${val// /}"
        val="${val//\"/}"
        ui_info "$key" "$val"
      done
      ;;
    set)
      shift
      local new_profile="${1:-}"
      if [[ -z "$new_profile" ]]; then
        die "Usage: dot config profile set <name>"
      fi
      if grep -q '^profile' "$data_file"; then
        sed_in_place "s/^profile = \".*\"/profile = \"$new_profile\"/" "$data_file"
      else
        sed_in_place "1a profile = \"$new_profile\"" "$data_file"
      fi
      ui_info "Profile" "Set to '$new_profile'. Run 'dot sync' to apply."
      ;;
    *)
      die "Unknown profile subcommand: ${1:-}. Use 'show' or 'set'."
      ;;
  esac
}

cmd_bundle() {
  run_script "scripts/ops/bundle.sh" "Offline bundle script" "$@"
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

# The subcommands, each run by cmd_<name>, and the banner section each showed
# in the module it came from (cd has none: its output is a path to capture).
_CONFIG_COMMANDS="apply sync update add diff status remove cd edit commit uninstall setup profile bundle sandbox"

# config_banner SUBCOMMAND ARGS...
config_banner() {
  case "${1:-}" in
    cd) ;;
    setup | profile) dot_ui_command_banner "Tools" "$1" ;;
    bundle) dot_ui_command_banner "Diagnostics" "$@" ;;
    sandbox) dot_ui_command_banner "Meta" "$@" ;;
    *) dot_ui_command_banner "Core" "${1:-}" ;;
  esac
}

# config_main SUBCOMMAND ARGS... — run one subcommand, or refuse it.
config_main() {
  case "${1:-}" in
    init) exec bash "$SCRIPT_DIR/init.sh" "$@" ;;
    lint) exec bash "$SCRIPT_DIR/lint.sh" "$@" ;;
  esac
  if [[ "${1:-}" =~ ^[a-z-]+$ && " $_CONFIG_COMMANDS " == *" $1 "* ]]; then
    config_banner "$@"
    "cmd_${1//-/_}" "${@:2}"
  else
    echo "Unknown config command: ${1:-}" >&2
    exit 1
  fi
}

# Sourced (by tests), only the functions are defined.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  config_main "$@"
fi
