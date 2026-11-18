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
# shellcheck source=../../lib/dot/utils.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/utils.sh"
# The plugins' on-apply hooks run from the command table (lib/dot/hooks.sh).
_DOT_SRC="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../lib/dot/names.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/names.sh"
# shellcheck source=../../lib/dot/hooks.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/hooks.sh"
export DOT_COMMAND="apply"

# Temp file cleanup. `set +u` guards the array expansion: on bash 3.2
# (macOS) expanding an empty array under `set -u` is an "unbound
# variable" error, which would fire on every clean `dot sync`.
_TMPFILES=()
_LOCK_DIR=""
_APPLY_T0=""
cleanup() {
  set +u
  rm -f "${_TMPFILES[@]}" 2>/dev/null
  [[ -n "$_LOCK_DIR" ]] && rmdir "$_LOCK_DIR" 2>/dev/null
  set -u
}

# _apply_finish: the EXIT trap. Once apply_start is logged, every exit, a
# failed step included, logs apply_end with its status and duration in ms
# (O2, O3), so `dot fleet` sees failed applies too.
_apply_finish() {
  local rc=$? ms level=info
  if [[ -n "$_APPLY_T0" ]]; then
    ms=$(($(dot_now_ms) - _APPLY_T0))
    ((rc == 0)) || level=error
    dot_log "$level" apply_end "status=$rc" "duration_ms=$ms"
    dot_metric chezmoi_apply_duration "$ms" ms
  fi
  cleanup
  return "$rc"
}
trap _apply_finish EXIT

_apply_help() {
  cat <<HELP
chezmoi-apply.sh - Apply dotfiles with enhanced diagnostics

Usage:
  dot apply [OPTIONS] [-- CHEZMOI_ARGS]

Environment Variables:
  DOTFILES_CHEZMOI_APPLY_FLAGS    Extra flags for chezmoi apply
  DOTFILES_CHEZMOI_VERBOSE=1      Enable verbose output
  DOTFILES_CHEZMOI_KEEP_GOING=1   Continue on errors
  DOTFILES_NONINTERACTIVE=1       Skip interactive menus (plugin hooks, e.g. AI installs)
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
# failure, which ends the apply. Each step logs an apply_step event with
# its status and duration in ms (O3).
run_step() {
  local title="$1" out rc=0 t0
  shift
  out="$(umask 077 && mktemp)"
  _TMPFILES+=("$out")
  t0="$(dot_now_ms)"
  if [[ "$UI_ENABLED" = "1" ]]; then
    gum spin --spinner dot --title "$title" -- "$@" >"$out" 2>&1 || rc=$?
  else
    echo "$title..."
    "$@" >"$out" 2>&1 || rc=$?
  fi
  _run_step_log "$title" "$rc" "$t0"
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

# _run_step_log TITLE RC T0: the step's apply_step event (error when RC
# is not 0), its duration counted from T0 (ms).
_run_step_log() {
  local level=info
  (($2 == 0)) || level=error
  dot_log "$level" apply_step "step=$1" "status=$2" "duration_ms=$(($(dot_now_ms) - $3))"
}

# _apply_check_flags ARG...: every flag before `--` is one `chezmoi apply`
# takes (its own --help lists them), else a usage error (exit 64) before
# the lock is taken, apply_start is logged or chezmoi runs (D4). Without
# chezmoi there is nothing to check against, and the apply fails anyway.
_apply_check_flags() {
  local a known=""
  for a in "$@"; do
    [[ "$a" != -- ]] || return 0
    [[ "$a" == -* ]] || continue
    [[ -n "$known" ]] || known=" $(chezmoi apply --help 2>/dev/null |
      grep -oE -- '(^|[ ,])--?[A-Za-z][A-Za-z-]*' | tr -d ' ,' | tr '\n' ' ')"
    [[ "$known" != " " ]] || return 0
    [[ "$known" == *" ${a%%=*} "* ]] ||
      dot_usage_error "unknown flag '$a' for 'dot config apply'" "dot config apply [chezmoi apply flags] [-- targets]"
  done
}

# _apply_backup: before chezmoi overwrites anything, copy each existing
# target that `chezmoi status` says the apply changes into
# backup_<time>_pre_apply, beside the backups of scripts/ops/rollback.sh,
# so `dot doctor rollback` returns to the state before the last apply (O4).
# Skipped for --dry-run, or with DOTFILES_BACKUP_ON_APPLY=0.
_apply_backup() {
  local status dir n
  [[ "${DOTFILES_BACKUP_ON_APPLY:-1}" == 1 ]] || return 0
  ! has_flag --dry-run && ! has_flag -n || return 0
  status="$(chezmoi status 2>/dev/null | sed -n 's/^.[^ R] //p')" || return 0
  [[ -n "$status" ]] || return 0
  dir="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/backups/backup_$(date +%Y%m%d_%H%M%S)_pre_apply"
  mkdir -p "$dir" 2>/dev/null || return 0
  n="$(_apply_backup_copy "$dir" <<<"$status")"
  printf 'timestamp=%s\nreason=pre_apply\nfiles_backed_up=%s\n' "$(date +%Y%m%d_%H%M%S)" "$n" >"$dir/.backup_meta"
  dot_log info apply_backup "files=$n" "backup=${dir##*/}"
  _apply_backup_prune "${dir%/*}"
}

# _apply_backup_copy DIR: copy each target on stdin (relative to HOME) that
# exists into DIR at the same path; print how many were copied.
_apply_backup_copy() {
  local rel n=0
  while IFS= read -r rel; do
    [[ -f "$HOME/$rel" || -L "$HOME/$rel" ]] || continue
    mkdir -p "$(dirname "$1/$rel")" && cp -pP "$HOME/$rel" "$1/$rel" && n=$((n + 1))
  done
  printf '%s\n' "$n"
}

# _apply_backup_prune DIR: keep the newest DOTFILES_MAX_BACKUPS (10, as
# rollback.sh's MAX_BACKUPS) backup_* directories in DIR.
_apply_backup_prune() {
  local max="${DOTFILES_MAX_BACKUPS:-10}" old
  [[ "$max" =~ ^[1-9][0-9]*$ ]] || max=10
  find "$1" -mindepth 1 -maxdepth 1 -type d -name 'backup_*' 2>/dev/null | sort -r | tail -n "+$((max + 1))" |
    while IFS= read -r old; do
      [[ "$old" == "$1"/backup_* ]] && rm -rf -- "$old"
    done
}

_apply_governance() {
  local governance_script="$SCRIPT_DIR/../diagnostics/alias-governance.sh"
  [[ "${DOTFILES_ALIAS_STRICT_MODE:-0}" == "1" && -f "$governance_script" ]] || return 0
  run_step "Alias governance (strict)" env DOTFILES_ALIAS_POLICY=strict bash "$governance_script"
}

# A baseline snapshot on the first apply (never overwritten).
_apply_snapshot() {
  local snapshot_script="$SCRIPT_DIR/../diagnostics/snapshot.sh"
  local snapshot_dir="${XDG_STATE_HOME:-$HOME/.local/state}/dot/config/snapshots"
  [[ "${DOTFILES_SNAPSHOT_ON_APPLY:-1}" = "1" ]] || return 0
  if [[ -f "$snapshot_script" && ! -f "$snapshot_dir/baseline.json" ]]; then
    mkdir -p "$snapshot_dir"
    bash "$snapshot_script" --baseline >/dev/null 2>&1 || true
  fi
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

_apply_check_flags "$@"
_apply_build_args "$@"
_apply_interactive
ui_init
_apply_lock

dot_log info "apply_start"
_APPLY_T0="$(dot_now_ms)"
ui_header "Applying dotfiles"
_apply_governance
_apply_backup
run_step "Chezmoi apply" chezmoi apply "${args[@]}"
_apply_snapshot

DOT_HOOK_INTERACTIVE="$INTERACTIVE" dot_hooks_run on-apply

_apply_status
_apply_repair
_apply_prewarm

printf "\n"
ui_info "Shell reload" "Run 'exec zsh' or restart your terminal to reload aliases/functions."
