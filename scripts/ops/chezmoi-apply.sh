#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"
# shellcheck source=../../lib/dot/log.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/log.sh"
# shellcheck source=../../lib/dot/ai-install.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ai-install.sh"
export DOT_COMMAND="apply"

# Temp file cleanup. `set +u` guards the array expansion: on bash 3.2
# (macOS) expanding an empty array under `set -u` is an "unbound
# variable" error, which would fire on every clean `dot sync`.
_TMPFILES=()
_LOCK_DIR=""
cleanup() {
  set +u
  rm -f "${_TMPFILES[@]}" 2>/dev/null
  [[ -n "$_LOCK_DIR" ]] && rmdir "$_LOCK_DIR" 2>/dev/null
  set -u
}
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
  DOTFILES_NONINTERACTIVE=1       Skip interactive menus (AI provider installer)
  DOTFILES_INTERACTIVE_APPLY=1    Re-enable chezmoi overwrite prompts
                                  (apply is unattended/--force by default)
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
  # Guard the expansion: on bash 3.2 (macOS) iterating an empty array
  # under `set -u` is an unbound-variable error.
  [[ ${#args[@]} -eq 0 ]] && return 1
  for arg in "${args[@]}"; do
    [[ "$arg" == "$needle" ]] && return 0
  done
  return 1
}

# Apply unattended by default, like an OS package manager. chezmoi is
# always run below under `gum spin` or with its output captured, so it
# never has a controlling TTY; its "<file> has changed since chezmoi last
# wrote it" confirmation prompt therefore cannot be answered and aborts
# the run with "could not open a new TTY". Passing --force applies the
# canonical source without prompting, so local drift to *managed* files
# yields to the source — exactly how `apt`/system updates behave. Keep
# machine-specific tweaks in the unmanaged ~/.zshrc.local or
# ~/.config/zsh/rc.d.local/*.zsh, which chezmoi never overwrites.
# Opt back into chezmoi's prompts with DOTFILES_INTERACTIVE_APPLY=1.
if [[ "${DOTFILES_INTERACTIVE_APPLY:-0}" != "1" ]] && ! has_flag "--force"; then
  args+=("--force")
fi

# Whether interactive menus (the optional AI-provider installer below) may
# prompt. Suppressed without a TTY, under CI, or when non-interactive is
# requested — so unattended runs never hang waiting on input.
INTERACTIVE=1
if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]] || [[ -n "${CI:-}" ]] || [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
  INTERACTIVE=0
fi

ui_init

# Prevent concurrent execution. flock(1) is Linux-only — it does not exist
# on macOS, where `! flock` previously took the "already running" branch and
# made `dot apply` a silent no-op. Use flock where present, otherwise fall
# back to an atomic mkdir lock (portable to macOS/BSD).
_lock_base="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/dotfiles-chezmoi-apply"
if command -v flock >/dev/null 2>&1; then
  exec 9>"${_lock_base}.lock"
  if ! flock -n 9; then
    ui_warn "Already running" "Another instance is active"
    exit 0
  fi
elif ! mkdir "${_lock_base}.lock.d" 2>/dev/null; then
  ui_warn "Already running" "Another instance is active"
  exit 0
else
  _LOCK_DIR="${_lock_base}.lock.d" # removed by cleanup() on exit
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

# binary|mise_package|label  (claude uses the native installer, not mise)
_AI_PROVIDERS=(
  "claude|native|Claude Code"
  "codex|npm:@openai/codex|Codex CLI"
  "copilot|npm:@github/copilot|Copilot CLI"
  "goose|native|Goose"
  "agy|native|Antigravity CLI"
  "kimi|native|Kimi CLI"
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

if [[ ${#_ai_missing[@]} -gt 0 ]] && [[ "$INTERACTIVE" == "1" ]]; then
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
        if [[ "$_bin" == "claude" ]]; then
          install_claude_native "$_label"
          continue
        fi
        if [[ "$_bin" == "goose" ]]; then
          install_goose_native "$_label"
          continue
        fi
        if [[ "$_bin" == "agy" ]]; then
          install_agy_native "$_label"
          continue
        fi
        if [[ "$_bin" == "kimi" ]]; then
          install_kimi_native "$_label"
          continue
        fi
        if command -v gum &>/dev/null; then
          if gum spin --spinner dot --title "Installing $_label ($_pkg)" -- \
            mise use -g "$_pkg@latest" 2>&1; then
            ui_ok "$_label" "installed"
          else
            ui_warn "$_label" "install failed (continuing)"
          fi
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

if [[ "${DOTFILES_PREWARM_ON_APPLY:-1}" = "1" ]]; then
  prewarm_script="$SCRIPT_DIR/prewarm.sh"
  if [[ -f "$prewarm_script" ]]; then
    printf "\n"
    run_step "Pre-warming shell caches" bash "$prewarm_script"
  fi
fi

printf "\n"
_apply_end=$(date +%s)
dot_log info "apply_end" "duration_s=$((_apply_end - _apply_start))"
dot_metric "chezmoi_apply_duration" "$((_apply_end - _apply_start))" "s"
ui_info "Shell reload" "Run 'exec zsh' or restart your terminal to reload aliases/functions."
