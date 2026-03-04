#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

# Help flag
case "${1:-}" in
  -h | --help)
    cat <<HELP
chezmoi-apply.sh - Apply dotfiles with enhanced diagnostics

Usage:
  dot apply [OPTIONS] [-- CHEZMOI_ARGS]

Environment Variables:
  DOTFILES_CHEZMOI_APPLY_FLAGS    Extra flags for chezmoi apply
  DOTFILES_CHEZMOI_VERBOSE=1      Enable verbose output
  DOTFILES_CHEZMOI_KEEP_GOING=1   Continue on errors
  DOTFILES_NONINTERACTIVE=1       Force non-interactive mode
  DOTFILES_ALIAS_STRICT_MODE=1    Run alias governance checks
  DOTFILES_SNAPSHOT_ON_APPLY=1    Create baseline snapshot (default)
  DOTFILES_POST_APPLY_REPAIR=1   Run post-apply repairs (default)
  DOTFILES_CHEZMOI_STATUS=1      Show status after apply (default)
HELP
    exit 0
    ;;
esac

args=("$@")
if [[ -n "${DOTFILES_CHEZMOI_APPLY_FLAGS:-}" ]]; then
  # Safely parse space-separated flags into array
  read -ra flag_array <<<"$DOTFILES_CHEZMOI_APPLY_FLAGS"
  args+=("${flag_array[@]}")
fi

if [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" ]]; then
  args+=("--verbose")
fi

if [[ "${DOTFILES_CHEZMOI_KEEP_GOING:-0}" = "1" ]]; then
  args+=("--keep-going")
fi

has_flag() {
  local needle="$1"
  local arg
  for arg in "${args[@]}"; do
    [[ "$arg" == "$needle" ]] && return 0
  done
  return 1
}

# In non-interactive runs, prevent TTY prompts from blocking apply.
if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]] && ! has_flag "--force"; then
  args+=("--force")
fi

ui_init

run_step() {
  local title="$1"
  shift
  local out
  out="$(umask 077 && mktemp)"
  if [[ "$UI_ENABLED" = "1" ]]; then
    if gum spin --spinner dot --title "$title" -- "$@" >"$out" 2>&1; then
      ui_ok "$title"
      if [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" ]] && [[ -s "$out" ]]; then
        cat "$out"
      fi
    else
      ui_err "$title"
      cat "$out"
      rm -f "$out"
      exit 1
    fi
  else
    echo "$title..."
    if "$@" >"$out" 2>&1; then
      if [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" ]] && [[ -s "$out" ]]; then
        cat "$out"
      fi
    else
      cat "$out"
      rm -f "$out"
      exit 1
    fi
  fi
  rm -f "$out"
}

ui_header "Applying dotfiles"
if [[ "${DOTFILES_ALIAS_STRICT_MODE:-0}" == "1" ]]; then
  governance_script="$SCRIPT_DIR/../diagnostics/alias-governance.sh"
  if [[ -f "$governance_script" ]]; then
    run_step "Alias governance (strict)" env DOTFILES_ALIAS_POLICY=strict bash "$governance_script"
  fi
fi
run_step "Chezmoi apply" chezmoi apply "${args[@]}"

if [[ "${DOTFILES_SNAPSHOT_ON_APPLY:-1}" = "1" ]]; then
  snapshot_script="$SCRIPT_DIR/../diagnostics/snapshot.sh"
  snapshot_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/snapshots"
  snapshot_file="${snapshot_dir}/baseline.json"
  if [[ -f "$snapshot_script" && ! -f "$snapshot_file" ]]; then
    mkdir -p "$snapshot_dir"
    bash "$snapshot_script" --baseline >/dev/null 2>&1 || true
  fi
fi

check_cmd() {
  local cmd="$1"
  if command -v "$cmd" &>/dev/null; then
    return 0
  fi
  if command -v mise &>/dev/null; then
    if mise ls --installed 2>/dev/null | grep -qE "($cmd|aqua:.*$cmd)"; then
      return 0
    fi
  fi
  return 1
}

echo ""
ui_header "AI provider CLI checks (optional)"
if check_cmd "claude"; then
  ui_ok "claude"
else
  ui_err "claude" "recommended — install to enable this provider"
fi
if check_cmd "gemini"; then
  ui_ok "gemini"
else
  ui_err "gemini" "optional — install to enable this provider"
fi
if check_cmd "sgpt"; then
  ui_ok "sgpt"
else
  ui_err "sgpt" "optional — install to enable this provider"
fi
if check_cmd "ollama"; then
  ui_ok "ollama"
else
  ui_err "ollama" "optional — install to enable this provider"
fi
if check_cmd "opencode"; then
  ui_ok "opencode"
else
  ui_err "opencode" "optional — install to enable this provider"
fi
if check_cmd "aider"; then
  ui_ok "aider"
else
  ui_err "aider" "optional — AI pair programming"
fi

if [[ "${DOTFILES_CHEZMOI_STATUS:-1}" = "1" ]]; then
  printf "\n"
  ui_header "Status"
  status_out="$(chezmoi status || true)"
  if [[ -z "$status_out" ]]; then
    ui_ok "Clean"
  else
    printf "%s\n" "$status_out"
  fi
fi

if [[ "${DOTFILES_POST_APPLY_REPAIR:-1}" = "1" ]]; then
  post_apply_script="$SCRIPT_DIR/post-apply-repair.sh"
  if [[ -f "$post_apply_script" ]]; then
    printf "\n"
    bash "$post_apply_script" || true
  fi
fi

printf "\n"
ui_info "Shell reload" "Run 'exec zsh' or restart your terminal to reload aliases/functions."
