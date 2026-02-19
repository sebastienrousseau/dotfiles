#!/usr/bin/env bash
# Dotfiles post-merge verification checks
# Runs doctor + status + diff checks and exits non-zero on issues.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init
ui_logo_dot "Dotfiles Verify"
echo ""

failures=0
dot_bin=""

resolve_dot_bin() {
  if command -v dot >/dev/null 2>&1; then
    command -v dot
    return
  fi
  if [[ -x "$HOME/.local/bin/dot" ]]; then
    printf "%s\n" "$HOME/.local/bin/dot"
    return
  fi
  local src_dir=""
  if [[ -n "${CHEZMOI_SOURCE_DIR:-}" && -d "${CHEZMOI_SOURCE_DIR}" ]]; then
    src_dir="${CHEZMOI_SOURCE_DIR}"
  elif [[ -d "$HOME/.dotfiles" ]]; then
    src_dir="$HOME/.dotfiles"
  elif [[ -d "$HOME/.local/share/chezmoi" ]]; then
    src_dir="$HOME/.local/share/chezmoi"
  fi
  if [[ -n "$src_dir" && -x "$src_dir/dot_local/bin/executable_dot" ]]; then
    printf "%s\n" "$src_dir/dot_local/bin/executable_dot"
    return
  fi
  return 1
}

run_step() {
  local label="$1"
  shift

  ui_info "Running" "$label"
  set +e
  "$@"
  local ec=$?
  set -e

  if [[ $ec -eq 0 ]]; then
    ui_ok "$label" "ok"
  else
    ui_err "$label" "failed (exit $ec)"
    failures=$((failures + 1))
  fi
}

if dot_bin="$(resolve_dot_bin)"; then
  run_step "dot doctor" "$dot_bin" doctor
  run_step "dot status" "$dot_bin" status
else
  ui_err "dot binary" "not found in PATH, ~/.local/bin, or source tree"
  failures=$((failures + 1))
fi

ui_info "Running" "chezmoi diff"
set +e
diff_output="$(chezmoi diff 2>&1)"
diff_ec=$?
set -e
if [[ $diff_ec -eq 0 ]]; then
  ui_ok "chezmoi diff" "clean"
else
  ui_warn "chezmoi diff" "drift detected"
  if [[ -n "$diff_output" ]]; then
    printf "%s\n" "$diff_output"
  fi
  failures=$((failures + 1))
fi

echo ""
if [[ $failures -eq 0 ]]; then
  ui_ok "Verification" "all checks passed"
  exit 0
fi

ui_err "Verification" "$failures check(s) failed"
ui_info "Hint" "Run 'dot heal' then re-run 'dot verify'"
exit 1
