#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/ui.sh"
# shellcheck source=../dot/lib/log.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../dot/lib/log.sh"
export DOT_COMMAND="apply"

# Temp file cleanup
_TMPFILES=()
cleanup() { rm -f "${_TMPFILES[@]}"; }
trap cleanup EXIT

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

# Prevent concurrent execution
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-chezmoi-apply.lock"
exec 9>"$LOCK_FILE"
if ! flock -n 9; then
  ui_warn "Already running" "Another instance is active"
  exit 0
fi

run_step() {
  local title="$1"
  shift
  local out
  out="$(umask 077 && mktemp)"
  _TMPFILES+=("$out")
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

dot_log info "apply_start"
_apply_start=$(date +%s)
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

# binary|mise_package|label
_AI_PROVIDERS=(
  "claude|npm:@anthropic-ai/claude-code|Claude Code"
  "copilot|npm:@github/copilot|Copilot CLI"
  "gemini|npm:@google/gemini-cli|Gemini CLI"
  "sgpt|pipx:shell-gpt|Shell-GPT"
  "ollama|aqua:ollama/ollama|Ollama"
  "opencode|npm:opencode-ai|OpenCode"
  "aider|pipx:aider-chat|Aider"
  "kiro-cli|kiro-cli|Kiro CLI"
  "autohand|npm:autohand-cli|Autohand Code"
  "vibe|pipx:mistral-vibe|Mistral Vibe"
  "qwen|npm:@qwen-code/qwen-code|Qwen Code"
  "zai|npm:@guizmo-ai/zai-cli|ZAI"
)

_ai_missing=()
for _entry in "${_AI_PROVIDERS[@]}"; do
  IFS='|' read -r _bin _pkg _label <<<"$_entry"
  if check_cmd "$_bin"; then
    ui_ok "$_label"
  else
    ui_info "$_label" "not installed"
    _ai_missing+=("$_entry")
  fi
done

if [[ ${#_ai_missing[@]} -gt 0 ]] && [[ "${DOTFILES_NONINTERACTIVE:-0}" != "1" ]]; then
  if command -v mise &>/dev/null; then
    echo ""
    _ai_install_action=""
    if command -v gum &>/dev/null; then
      _ai_install_action=$(printf '%s\n' "Install all" "Choose which to install" "Skip" |
        gum choose --header "Missing AI providers — install via mise?") || _ai_install_action=""
    else
      ui_info "Tip" "Install all missing AI providers with: mise install"
      ui_info "Tip" "Or individually: mise use -g <package>@latest"
    fi

    _ai_to_install=()
    case "$_ai_install_action" in
      "Install all")
        _ai_to_install=("${_ai_missing[@]}")
        ;;
      "Choose which to install")
        _ai_pick_choices=()
        for _entry in "${_ai_missing[@]}"; do
          IFS='|' read -r _bin _pkg _label <<<"$_entry"
          _ai_pick_choices+=("$_label")
        done
        _ai_picked=$(printf '%s\n' "${_ai_pick_choices[@]}" |
          gum choose --no-limit --header "Select providers to install (Space to toggle, Enter to confirm)") || _ai_picked=""
        if [[ -n "$_ai_picked" ]]; then
          while IFS= read -r _selected; do
            [[ -z "$_selected" ]] && continue
            for _entry in "${_ai_missing[@]}"; do
              IFS='|' read -r _bin _pkg _label <<<"$_entry"
              if [[ "$_label" == "$_selected" ]]; then
                _ai_to_install+=("$_entry")
              fi
            done
          done <<<"$_ai_picked"
        fi
        ;;
    esac

    if [[ ${#_ai_to_install[@]} -gt 0 ]]; then
      echo ""
      for _entry in "${_ai_to_install[@]}"; do
        IFS='|' read -r _bin _pkg _label <<<"$_entry"
        if command -v gum &>/dev/null; then
          gum spin --spinner dot --title "Installing $_label ($_pkg)" -- \
            mise use -g "$_pkg@latest" 2>&1 && ui_ok "$_label" "installed" ||
            ui_warn "$_label" "install failed (continuing)"
        else
          ui_info "Installing" "$_label via mise ($_pkg)"
          mise use -g "$_pkg@latest" 2>&1 || ui_warn "$_label" "install failed (continuing)"
        fi
      done
    fi
  else
    ui_warn "mise" "not found — install mise first to manage AI providers"
  fi
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
_apply_end=$(date +%s)
dot_log info "apply_end" "duration_s=$((_apply_end - _apply_start))"
dot_metric "chezmoi_apply_duration" "$((_apply_end - _apply_start))" "s"
ui_info "Shell reload" "Run 'exec zsh' or restart your terminal to reload aliases/functions."
