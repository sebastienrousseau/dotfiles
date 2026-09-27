#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
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
# shellcheck source=../../lib/dot/utils.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/utils.sh" # check_cmd
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

_apply_help() {
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
}

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

# _apply_build_args <args...>: the arguments for `chezmoi apply` (global args).
_apply_build_args() {
  args=("$@")
  if [[ -n "${DOTFILES_CHEZMOI_APPLY_FLAGS:-}" ]]; then
    # Safely parse space-separated flags into array
    read -ra flag_array <<<"$DOTFILES_CHEZMOI_APPLY_FLAGS"
    args+=("${flag_array[@]}")
  fi
  [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" ]] && args+=("--verbose")
  [[ "${DOTFILES_CHEZMOI_KEEP_GOING:-0}" = "1" ]] && args+=("--keep-going")
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
}

# Whether interactive menus (the optional AI-provider installer below) may
# prompt. Suppressed without a TTY, under CI, or when non-interactive is
# requested — so unattended runs never hang waiting on input.
_apply_interactive() {
  INTERACTIVE=1
  if [[ "${DOTFILES_NONINTERACTIVE:-0}" == "1" ]] || [[ -n "${CI:-}" ]] || [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
    INTERACTIVE=0
  fi
}

# Prevent concurrent execution. flock(1) is Linux-only — it does not exist
# on macOS, where `! flock` previously took the "already running" branch and
# made `dot apply` a silent no-op. Use flock where present, otherwise fall
# back to an atomic mkdir lock (portable to macOS/BSD).
_apply_lock() {
  local lock_base="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/dotfiles-chezmoi-apply"
  if command -v flock >/dev/null 2>&1; then
    exec 9>"${lock_base}.lock"
    if ! flock -n 9; then
      ui_warn "Already running" "Another instance is active"
      exit 0
    fi
  elif ! mkdir "${lock_base}.lock.d" 2>/dev/null; then
    ui_warn "Already running" "Another instance is active"
    exit 0
  else
    _LOCK_DIR="${lock_base}.lock.d" # removed by cleanup() on exit
  fi
}

# run_step <title> <cmd...>: run cmd under a gum spinner (or a plain
# "title..." line), its output captured; show it with --verbose, or on
# failure, which ends the apply.
run_step() {
  local title="$1" out rc=0
  shift
  out="$(umask 077 && mktemp)"
  _TMPFILES+=("$out")
  if [[ "$UI_ENABLED" = "1" ]]; then
    gum spin --spinner dot --title "$title" -- "$@" >"$out" 2>&1 || rc=$?
  else
    echo "$title..."
    "$@" >"$out" 2>&1 || rc=$?
  fi
  if [[ $rc -ne 0 ]]; then
    [[ "$UI_ENABLED" = "1" ]] && ui_err "$title"
    cat "$out"
    rm -f "$out"
    exit 1
  fi
  [[ "$UI_ENABLED" = "1" ]] && ui_ok "$title"
  if [[ "${DOTFILES_CHEZMOI_VERBOSE:-0}" = "1" && -s "$out" ]]; then
    cat "$out"
  fi
  rm -f "$out"
}

_apply_governance() {
  local governance_script="$SCRIPT_DIR/../diagnostics/alias-governance.sh"
  [[ "${DOTFILES_ALIAS_STRICT_MODE:-0}" == "1" && -f "$governance_script" ]] || return 0
  run_step "Alias governance (strict)" env DOTFILES_ALIAS_POLICY=strict bash "$governance_script"
}

# A baseline snapshot on the first apply (never overwritten).
_apply_snapshot() {
  local snapshot_script="$SCRIPT_DIR/../diagnostics/snapshot.sh"
  local snapshot_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/snapshots"
  [[ "${DOTFILES_SNAPSHOT_ON_APPLY:-1}" = "1" ]] || return 0
  if [[ -f "$snapshot_script" && ! -f "$snapshot_dir/baseline.json" ]]; then
    mkdir -p "$snapshot_dir"
    bash "$snapshot_script" --baseline >/dev/null 2>&1 || true
  fi
}

# check_cmd() is provided by lib/dot/utils.sh — sourced above.

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
  "aider|pipx:aider-chat[uvx_args=--python 3.12]|Aider"
  "kiro-cli|kiro-cli|Kiro CLI"
  "autohand|npm:autohand-cli|Autohand Code"
  "vibe|pipx:mistral-vibe|Mistral Vibe"
  "qwen|npm:@qwen-code/qwen-code|Qwen Code"
  "zai|npm:@guizmo-ai/zai-cli|ZAI"
)

# _apply_ai_scan: one row per provider; missing entries go to _ai_missing.
_apply_ai_scan() {
  local entry bin pkg label
  _ai_missing=()
  for entry in "${_AI_PROVIDERS[@]}"; do
    IFS='|' read -r bin pkg label <<<"$entry"
    if check_cmd "$bin"; then
      ui_ok "$label"
    else
      ui_info "$label" "not installed"
      _ai_missing+=("$entry")
    fi
  done
}

# _apply_ai_pick: the missing entries whose labels the user ticked.
_apply_ai_pick() {
  local entry bin pkg label picked selected
  local -a choices=()
  for entry in "${_ai_missing[@]}"; do
    IFS='|' read -r bin pkg label <<<"$entry"
    choices+=("$label")
  done
  picked=$(printf '%s\n' "${choices[@]}" |
    gum choose --no-limit --header "Select providers to install (Space to toggle, Enter to confirm)") || picked=""
  [[ -n "$picked" ]] || return 0
  while IFS= read -r selected; do
    [[ -z "$selected" ]] && continue
    for entry in "${_ai_missing[@]}"; do
      IFS='|' read -r bin pkg label <<<"$entry"
      if [[ "$label" == "$selected" ]]; then
        _ai_to_install+=("$entry")
      fi
    done
  done <<<"$picked"
}

# _apply_ai_choose: fill _ai_to_install through gum (all, a choice, or
# none); without gum, print how to install them instead.
_apply_ai_choose() {
  local action=""
  _ai_to_install=()
  if ! command -v gum &>/dev/null; then
    ui_info "Tip" "Install all missing AI providers with: mise install"
    ui_info "Tip" "Or individually: mise use -g <package>@latest"
    return 0
  fi
  action=$(printf '%s\n' "Install all" "Choose which to install" "Skip" |
    gum choose --header "Missing AI providers — install via mise?") || action=""
  case "$action" in
    "Install all") _ai_to_install=("${_ai_missing[@]}") ;;
    "Choose which to install") _apply_ai_pick ;;
  esac
}

# _apply_ai_install <entry>: native installer for "native" packages, else
# mise under a gum spinner (gum is present: only gum fills the list).
_apply_ai_install() {
  local bin pkg label
  IFS='|' read -r bin pkg label <<<"$1"
  if [[ "$pkg" == "native" ]]; then
    "install_${bin}_native" "$label"
    return 0
  fi
  if _ai_in_scratch_dir gum spin --spinner dot --title "Installing $label ($pkg)" -- \
    mise use -g "$pkg@latest" 2>&1; then
    ui_ok "$label" "installed"
  else
    ui_warn "$label" "install failed (continuing)"
  fi
}

# _apply_ai_offer: offer to install missing providers (interactive runs only).
_apply_ai_offer() {
  local entry
  [[ ${#_ai_missing[@]} -gt 0 && "$INTERACTIVE" == "1" ]] || return 0
  if ! command -v mise &>/dev/null; then
    ui_warn "mise" "not found — install mise first to manage AI providers"
    return 0
  fi
  echo ""
  _apply_ai_choose
  [[ ${#_ai_to_install[@]} -gt 0 ]] || return 0
  echo ""
  for entry in "${_ai_to_install[@]}"; do
    _apply_ai_install "$entry"
  done
}

_apply_status() {
  local status_out
  [[ "${DOTFILES_CHEZMOI_STATUS:-1}" = "1" ]] || return 0
  printf "\n"
  ui_header "Status"
  status_out="$(chezmoi status || true)"
  if [[ -z "$status_out" ]]; then
    ui_ok "Clean"
  else
    printf "%s\n" "$status_out"
  fi
}

_apply_repair() {
  local post_apply_script="$SCRIPT_DIR/post-apply-repair.sh"
  [[ "${DOTFILES_POST_APPLY_REPAIR:-1}" = "1" && -f "$post_apply_script" ]] || return 0
  printf "\n"
  bash "$post_apply_script" || true
}

_apply_prewarm() {
  local prewarm_script="$SCRIPT_DIR/prewarm.sh"
  [[ "${DOTFILES_PREWARM_ON_APPLY:-1}" = "1" && -f "$prewarm_script" ]] || return 0
  printf "\n"
  run_step "Pre-warming shell caches" bash "$prewarm_script"
}

# --- main ---
case "${1:-}" in
  -h | --help)
    _apply_help
    exit 0
    ;;
esac

_apply_build_args "$@"
_apply_interactive
ui_init
_apply_lock

dot_log info "apply_start"
_apply_start=$(date +%s)
ui_header "Applying dotfiles"
_apply_governance
run_step "Chezmoi apply" chezmoi apply "${args[@]}"
_apply_snapshot

echo ""
ui_header "AI provider CLI checks (optional)"
_apply_ai_scan
_apply_ai_offer

_apply_status
_apply_repair
_apply_prewarm

printf "\n"
_apply_end=$(date +%s)
dot_log info "apply_end" "duration_s=$((_apply_end - _apply_start))"
dot_metric "chezmoi_apply_duration" "$((_apply_end - _apply_start))" "s"
ui_info "Shell reload" "Run 'exec zsh' or restart your terminal to reload aliases/functions."
