#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
## dot system: status, the scheduled maintenance job, the update path
## (upgrade, moved from meta.sh), OS settings (tune, from appearance.sh) and
## log rotation (log-rotate, from tools.sh). plugins/system/dot-system maps
## the ADR-020 spellings onto these.
## Usage: system.sh [status] | schedule [list|set weekly|daily|off|run]
##        | upgrade [args] | tune [args] | log-rotate [args]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../../lib/dot/utils.sh
source "$SCRIPT_DIR/../../../lib/dot/utils.sh"
# shellcheck source=../../../lib/dot/system.sh
source "$SCRIPT_DIR/../../../lib/dot/system.sh"
# shellcheck source=../../../lib/dot/log.sh
source "$SCRIPT_DIR/../../../lib/dot/log.sh"

# _system_unknown: the words are left out, since one may be a secret.
_system_unknown() {
  printf "dot: unknown 'dot system' command; see 'dot help system'\n" >&2
  exit 1
}

_system_schedule() {
  case "${1:-list}" in
    list) dot_system_schedule_list ;;
    set)
      shift
      dot_system_schedule_set "$@"
      ;;
    run) dot_system_schedule_run ;;
    *) _system_unknown schedule "$@" ;;
  esac
}

# Last meaningful line of a captured log, used as a step's `ok` detail.
# Collapses carriage-return progress (git/nvim spam \r), strips ANSI,
# takes the last non-empty line, and clips it so the rendered step stays
# on one line.
_upgrade_last_line() {
  tr '\r' '\n' <"$1" 2>/dev/null |
    sed -E 's/\x1b\[[0-9;?]*[a-zA-Z]//g' |
    awk 'NF{last=$0} END{print last}' |
    cut -c1-56
}

cmd_upgrade() {
  local src_dir
  src_dir="$(require_source_dir)"

  # Per-step logs. Each phase's stdout+stderr is captured here rather
  # than streamed to the terminal: the git/nvim/chezmoi output is noisy
  # (carriage-return progress bars, remote counters) and, in rich mode,
  # writing it to the terminal corrupts the dot-ui renderer that owns
  # the screen. Failing steps get their tail dumped after the run.
  local log_dir
  log_dir="$(mktemp -d "${TMPDIR:-/tmp}/dot-upgrade.XXXXXX")"
  local fail_labels=() fail_logs=()
  # sysexits EX_TEMPFAIL: a phase returns it to say "not now, and here is
  # why" (last line of its log). It is rendered as a skip, not a failure.
  local EX_TEMPFAIL=75

  _upgrade_dotfiles() {
    local update_source branch
    update_source="$(chezmoi source-path 2>/dev/null)" || update_source=""
    if [[ -d "$update_source" ]] && git -C "$update_source" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      branch="$(git -C "$update_source" symbolic-ref --quiet --short HEAD)" || {
        printf 'Dotfiles checkout is detached; switch to a tracked branch before upgrading.\n' >&2
        return 1
      }
      if ! git -C "$update_source" rev-parse --verify '@{upstream}' >/dev/null 2>&1; then
        printf 'Dotfiles branch %s has no upstream. Push it with -u or explicitly select a tracked branch; no files were changed.\n' "$branch" >&2
        return 1
      fi
      # A dirty checkout is a working state, not a fault: editing the
      # dotfiles is what a dotfiles repo is for. Decline the pull (a
      # rebase over local edits is not something to do unasked) and let
      # the other phases run, with the reason on the step line.
      if [[ -n "$(git -C "$update_source" status --porcelain)" ]]; then
        printf 'uncommitted changes; commit or stash them, then rerun\n' >&2
        return "$EX_TEMPFAIL"
      fi
    fi
    chezmoi update --no-tty
  }

  # _upgrade_step <id> <label> <running-detail> -- cmd [args...]
  # Renders one tracked step: spinner while it runs, then ok (with the
  # log's last line) or fail. Never aborts the run — a failed phase is
  # recorded and surfaced at the end. The overall command fails if any
  # phase failed, even though independent phases can still finish.
  _upgrade_step() {
    local id="$1" label="$2" running="$3"
    shift 3
    [[ "${1:-}" == "--" ]] && shift
    local log="$log_dir/$id.log" rc=0
    ui_step "$id" "$label" run "$running"
    # stdin is closed on purpose. Output is captured to a log, so a phase
    # that prompts (chezmoi's "X has changed since chezmoi last wrote it?",
    # a git credential helper, nvim waiting on a keypress) would otherwise
    # block on the terminal with its question invisible — the 2026-09-12
    # "chezmoi update seems very slow" report. With no stdin the prompt
    # fails fast, the step is marked failed, and the tail below says why.
    "$@" >"$log" 2>&1 </dev/null || rc=$?
    if [[ "$rc" -eq 0 ]]; then
      ui_step "$id" "" ok "$(_upgrade_last_line "$log")"
    elif [[ "$rc" -eq "$EX_TEMPFAIL" ]]; then
      # The phase declined to run and said why on its last line. Not a
      # fault: it neither fails the run nor gets its log tail dumped.
      ui_step "$id" "" skip "$(_upgrade_last_line "$log")"
    else
      ui_step "$id" "" fail "exited $rc"
      fail_labels+=("$label")
      fail_logs+=("$log")
    fi
    return 0
  }

  # Every question is asked here, before the phases take the terminal.
  dot_upgrade_prepare "$@"
  ui_steps_begin "Upgrade" ""
  dot_upgrade_nix_steps "$src_dir"
  # --no-tty: chezmoi otherwise opens /dev/tty directly for its
  # overwrite prompt, bypassing the closed stdin above and hanging.
  _upgrade_step dotfiles "Dotfiles" "chezmoi update…" -- _upgrade_dotfiles
  dot_upgrade_toolchain_steps

  if has_command nvim; then
    # scripts/nvim/headless-upgrade.lua runs Lazy sync AND waits for
    # Mason's async install queue to drain, so ensure_installed installs
    # (codelldb, debugpy, delve, etc.) aren't aborted by an early quitall.
    #
    # `nvim -l` does NOT load the user's init.lua, so without an explicit
    # -u the script found no lazy.nvim and logged "skipping plugin update"
    # on every run — the upgrade step was a silent no-op. Point -u at the
    # config nvim would load itself (honouring XDG_CONFIG_HOME and
    # NVIM_APPNAME) and skip visibly when there is none to load.
    local nvim_init="${XDG_CONFIG_HOME:-$HOME/.config}/${NVIM_APPNAME:-nvim}/init.lua"
    if [ -f "$nvim_init" ]; then
      DOTFILES_NVIM_UPGRADE=1 _upgrade_step nvim "Neovim plugins" "Lazy, parsers + Mason…" -- \
        nvim --headless -u "$nvim_init" -l "$src_dir/scripts/nvim/headless-upgrade.lua"
    else
      ui_step nvim "Neovim plugins" skip "no init.lua at $nvim_init"
    fi
  fi

  if [ "${DOTFILES_FONTS:-}" = "1" ] &&
    [ -f "$src_dir/scripts/fonts/install-nerd-fonts.sh" ]; then
    _upgrade_step fonts "Nerd Fonts" "installing…" -- \
      sh "$src_dir/scripts/fonts/install-nerd-fonts.sh"
  fi

  local n=${#fail_labels[@]}
  if [[ "$n" -eq 0 ]]; then
    ui_steps_end "requested upgrade phases completed"
    rm -rf "$log_dir"
  else
    ui_steps_end "$n step(s) failed"
    # Surfaced after ui_steps_end so the rich renderer has torn down —
    # printing mid-render would garble the display.
    local i=0
    while ((i < n)); do
      ui_err "${fail_labels[$i]}" "log tail:"
      tail -n 15 "${fail_logs[$i]}" | sed 's/^/    /'
      if grep -q 'has changed since chezmoi last wrote it' "${fail_logs[$i]}"; then
        ui_info "Hint" "a managed file was edited locally — run 'chezmoi apply' to choose per file, or 'chezmoi update --force' to overwrite"
      fi
      ((i++)) || true
    done
    ui_info "Logs" "$log_dir"
    return 1
  fi
}

cmd_tune() {
  local src_dir
  local platform
  src_dir="$(require_source_dir)"
  platform="$(dot_platform_id)"

  case "$platform" in
    macos)
      exec bash "$src_dir/scripts/tuning/macos.sh" "$@"
      ;;
    linux | wsl)
      exec bash "$src_dir/scripts/tuning/linux.sh" "$@"
      ;;
    *)
      echo "OS tuning not supported on this platform."
      exit 1
      ;;
  esac
}

cmd_log_rotate() {
  run_script "scripts/tools/log-rotate.sh" "Log rotation script" "$@"
}

case "${1:-status}" in
  status) dot_system_status ;;
  schedule)
    shift
    _system_schedule "$@"
    ;;
  upgrade)
    dot_ui_command_banner "Meta" upgrade "$@"
    shift
    cmd_upgrade "$@"
    ;;
  tune)
    dot_ui_command_banner "Appearance" tune
    shift
    cmd_tune "$@"
    ;;
  log-rotate)
    dot_ui_command_banner "Tools" log-rotate
    shift
    cmd_log_rotate "$@"
    ;;
  *) _system_unknown "$@" ;;
esac
