#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles CLI - Shell Commands (moved from core.sh, diagnostics.sh, meta.sh
# and tools.sh, P2.1). plugins/shell/dot-shell maps the ADR-020 spellings
# onto these; aliases.sh sits beside it.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/sdk.sh
source "${DOT_SDK:-$SCRIPT_DIR/../../../lib/dot}/sdk.sh"
# shellcheck source=aliases.sh
source "$SCRIPT_DIR/aliases.sh"

cmd_clean_cache() {
  ui_info "Cache" "Clearing shell initialization caches"
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
  rm -rf "$cache_dir/zsh"/*-init.zsh "$cache_dir/zsh"/*.zwc 2>/dev/null || true
  rm -rf "$cache_dir/bash"/*-init.bash 2>/dev/null || true
  rm -rf "$cache_dir/fish"/*-init.fish 2>/dev/null || true
  rm -rf "$cache_dir/nushell"/*.nu 2>/dev/null || true
  ui_info "Cache" "Cleared. Restart shell to regenerate"
}

cmd_history() {
  run_script "scripts/diagnostics/history-analysis.sh" "History analysis script" "$@"
}

cmd_prewarm() {
  local src_dir
  # Clear caches first
  ui_info "Cache" "Clearing shell initialization caches"
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}"
  # `find ... -delete` instead of `rm -rf $glob` so an unmatched literal
  # pattern can't accidentally remove a real same-named directory, and
  # so we don't pass `-r` on what should always be files.
  [[ -d "$cache_dir/zsh" ]] && find "$cache_dir/zsh" -maxdepth 1 -type f \( -name '*-init.zsh' -o -name '*.zwc' \) -delete 2>/dev/null
  [[ -d "$cache_dir/bash" ]] && find "$cache_dir/bash" -maxdepth 1 -type f -name '*-init.bash' -delete 2>/dev/null
  [[ -d "$cache_dir/fish" ]] && find "$cache_dir/fish" -maxdepth 1 -type f -name '*-init.fish' -delete 2>/dev/null
  [[ -d "$cache_dir/nushell" ]] && find "$cache_dir/nushell" -maxdepth 1 -type f -name '*.nu' -delete 2>/dev/null
  ui_info "Cache" "Cleared. Regenerating..."
  src_dir="$(resolve_source_dir)"
  if [ -n "$src_dir" ] && [ -f "$src_dir/scripts/ops/prewarm.sh" ]; then
    bash "$src_dir/scripts/ops/prewarm.sh"
  fi
}

# The subcommands, each run by cmd_<name> (cache-refresh is prewarm's old
# name), and the banner section each showed in the module it came from.
_SHELL_COMMANDS="clean-cache history prewarm aliases alias-check"

# shell_banner SUBCOMMAND ARGS...
shell_banner() {
  case "${1:-}" in
    clean-cache) dot_ui_command_banner "Core" "$1" ;;
    history) dot_ui_command_banner "Diagnostics" "$@" ;;
    prewarm) dot_ui_command_banner "Meta" "$@" ;;
    *) dot_ui_command_banner "Tools" "${1:-}" ;;
  esac
}

# shell_main SUBCOMMAND ARGS... — run one subcommand, or refuse it.
shell_main() {
  local sub="${1:-}"
  [[ "$sub" != cache-refresh ]] || sub=prewarm
  if [[ "$sub" =~ ^[a-z-]+$ && " $_SHELL_COMMANDS " == *" $sub "* ]]; then
    shell_banner "$sub" "${@:2}"
    "cmd_${sub//-/_}" "${@:2}"
  else
    echo "Unknown shell command: ${1:-}" >&2
    exit 1
  fi
}

# Sourced (by tests), only the functions are defined.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  shell_main "$@"
fi
