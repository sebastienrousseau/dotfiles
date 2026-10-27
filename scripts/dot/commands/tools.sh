#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Tools Commands
# log-rotate, aliases, alias-check, profile, setup, lint (tools, new, packages
# and env are plugins/tool)

set -euo pipefail

_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$_TOOLS_DIR/../../../lib/dot/utils.sh"
# shellcheck source=aliases.sh
source "$_TOOLS_DIR/aliases.sh"

# sed_in_place() is provided by lib/dot/utils.sh (sourced above).

dot_ui_command_banner "Tools" "${1:-}"

cmd_setup() {
  run_script "scripts/ops/setup.sh" "Setup script" "$@"
}

cmd_log_rotate() {
  run_script "scripts/tools/log-rotate.sh" "Log rotation script" "$@"
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

# Dispatch — aliases and alias-check are defined in aliases.sh (sourced above)
case "${1:-}" in
  --help | -h | help)
    cat <<'EOF'
Usage: tools.sh <command> [args...]

Commands:
  alias-check, log-rotate, setup, aliases, profile, lint
EOF
    ;;
  "")
    cat <<'EOF'
Usage: tools.sh <command> [args...]

Commands:
  alias-check, log-rotate, setup, aliases, profile, lint
EOF
    exit 1
    ;;
  alias-check)
    shift
    cmd_alias_check "$@"
    ;;
  log-rotate)
    shift
    cmd_log_rotate "$@"
    ;;
  setup)
    shift
    cmd_setup "$@"
    ;;
  aliases)
    shift
    cmd_aliases "$@"
    ;;
  profile)
    shift
    cmd_profile "$@"
    ;;
  lint)
    shift
    exec bash "$(require_source_dir)/scripts/dot/commands/lint.sh" lint "$@"
    ;;
  *)
    echo "Unknown tools command: ${1:-}" >&2
    exit 1
    ;;
esac
