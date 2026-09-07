#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for three small maintenance entry points, all driven
# inside the coverage sandbox against a throwaway $HOME:
#
#   scripts/tools/log-rotate.sh   — size threshold, rotation, gzip chain
#   scripts/ops/chezmoi-update.sh — flag assembly, --force default, --async
#   scripts/uninstall.sh          — confirmation gate and artefact removal
#
# `chezmoi` is a sandbox stub, so nothing on the host is applied or purged.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

ROTATE="$REPO_ROOT/scripts/tools/log-rotate.sh"
UPDATE="$REPO_ROOT/scripts/ops/chezmoi-update.sh"
UNINSTALL="$REPO_ROOT/scripts/uninstall.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

OUTF="$DOTFILES_COV_TMPDIR/out.txt"
BIN="$DOTFILES_COV_TMPDIR/bin"
run() {
  bash "$@" >"$OUTF" </dev/null
  RC=$?
  return 0
}
out_has() { assert_file_contains "$OUTF" "$1" "${2:-output contains $1}"; }

# ── log-rotate ──────────────────────────────────────────────────────────
LOG="$HOME/.local/share/dotfiles.log"
mkdir -p "$(dirname "$LOG")"

test_start "log_rotate_is_a_no_op_without_a_log"
rm -f "$LOG"
run "$ROTATE"
assert_equals 0 "$RC" "rc"
assert_file_not_exists "$LOG" "nothing created"

test_start "log_rotate_leaves_a_small_log_alone"
printf 'small\n' >"$LOG"
run "$ROTATE"
assert_equals 0 "$RC" "rc"
assert_file_contains "$LOG" "small" "log untouched"
assert_file_not_exists "$LOG.1.gz" "no rotation"

test_start "log_rotate_gzips_an_oversized_log_and_truncates_it"
# 1 MiB + a marker line is over the threshold.
dd if=/dev/zero bs=1024 count=1024 2>/dev/null | tr '\0' 'x' >"$LOG"
printf 'marker\n' >>"$LOG"
run "$ROTATE"
assert_equals 0 "$RC" "rc"
assert_file_exists "$LOG.1.gz" "rotated + gzipped"
assert_equals "0" "$(wc -c <"$LOG" | tr -d ' ')" "live log truncated"

test_start "log_rotate_shifts_existing_generations"
dd if=/dev/zero bs=1024 count=1025 2>/dev/null | tr '\0' 'x' >"$LOG"
printf 'plain-generation\n' >"$LOG.2"
run "$ROTATE"
assert_equals 0 "$RC" "rc"
assert_file_exists "$LOG.2.gz" "gz generation shifted"
assert_file_exists "$LOG.3.gz" "plain generation gzipped on the way"
assert_file_not_exists "$LOG.2" "plain generation consumed"

# ── chezmoi-update ──────────────────────────────────────────────────────
# Record the argv chezmoi is called with so flag assembly can be asserted.
cat >"$BIN/chezmoi" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$CHEZMOI_CALLS"
exit 0
STUB
chmod +x "$BIN/chezmoi"
export CHEZMOI_CALLS="$DOTFILES_COV_TMPDIR/chezmoi-calls.txt"
STATE_DIR="$XDG_STATE_HOME/dotfiles/update"

test_start "update_forces_apply_by_default"
: >"$CHEZMOI_CALLS"
run "$UPDATE"
assert_equals 0 "$RC" "rc"
out_has "Updating dotfiles" "progress line"
assert_file_contains "$CHEZMOI_CALLS" "update --force" "unattended by default"
assert_file_contains "$STATE_DIR/last.status" "0" "status recorded"

test_start "interactive_apply_drops_the_force_flag"
: >"$CHEZMOI_CALLS"
DOTFILES_INTERACTIVE_APPLY=1 run "$UPDATE"
assert_equals 0 "$RC" "rc"
assert_equals "update" "$(cat "$CHEZMOI_CALLS")" "no extra flags"

test_start "extra_flags_and_verbose_are_appended"
: >"$CHEZMOI_CALLS"
DOTFILES_CHEZMOI_UPDATE_FLAGS="--dry-run --force" DOTFILES_CHEZMOI_VERBOSE=1 run "$UPDATE"
assert_equals 0 "$RC" "rc"
assert_file_contains "$CHEZMOI_CALLS" "update --dry-run --force --verbose" "flags assembled once"

test_start "async_mode_returns_immediately_and_leaves_a_notice"
: >"$CHEZMOI_CALLS"
rm -f "$STATE_DIR/notice"
run "$UPDATE" --async
assert_equals 0 "$RC" "rc"
out_has "Update running in background" "message"
assert_file_exists "$STATE_DIR/notice" "notice stamped"
assert_file_exists "$STATE_DIR/last.log" "log file created"

test_start "async_mode_can_be_requested_by_environment"
rm -f "$STATE_DIR/notice"
DOTFILES_ASYNC_UPDATE=1 run "$UPDATE"
assert_equals 0 "$RC" "rc"
out_has "Update running in background" "message"
assert_file_exists "$STATE_DIR/notice" "notice stamped"

# ── uninstall ───────────────────────────────────────────────────────────
seed_artifacts() {
  mkdir -p "$HOME/.local/bin" "$XDG_CACHE_HOME/dotfiles" \
    "$XDG_STATE_HOME/dotfiles" "$XDG_CONFIG_HOME/chezmoi" \
    "$XDG_DATA_HOME/zsh/completions" "$XDG_DATA_HOME/bash-completion/completions"
  : >"$HOME/.local/bin/dot"
  : >"$HOME/.local/bin/dot-ai"
  : >"$XDG_DATA_HOME/zsh/completions/_dot"
  : >"$XDG_DATA_HOME/bash-completion/completions/dot"
  : >"$XDG_DATA_HOME/dotfiles.log"
  : >"$XDG_CACHE_HOME/dotfiles/marker"
  : >"$XDG_STATE_HOME/dotfiles/marker"
}

test_start "uninstall_aborts_without_confirmation"
seed_artifacts
printf 'n\n' | bash "$UNINSTALL" >"$OUTF"
RC=$?
assert_equals 0 "$RC" "rc"
out_has "Aborted." "abort message"
assert_file_exists "$HOME/.local/bin/dot" "artefacts left alone"
assert_dir_exists "$XDG_CONFIG_HOME/chezmoi" "chezmoi config left alone"

test_start "uninstall_proceeds_when_confirmed_at_the_prompt"
seed_artifacts
printf 'y\n' | bash "$UNINSTALL" >"$OUTF"
RC=$?
assert_equals 0 "$RC" "rc"
out_has "Uninstall complete." "completion"
assert_file_not_exists "$HOME/.local/bin/dot" "launcher removed"
assert_dir_not_exists "$XDG_CACHE_HOME/dotfiles" "caches removed"

test_start "force_skips_the_prompt_and_removes_every_artefact"
seed_artifacts
run "$UNINSTALL" --force
assert_equals 0 "$RC" "rc"
out_has "Reverting chezmoi-managed files" "chezmoi step ran"
out_has "Removing shell completions" "completions step ran"
assert_file_not_exists "$XDG_DATA_HOME/zsh/completions/_dot" "zsh completion removed"
assert_file_not_exists "$XDG_DATA_HOME/bash-completion/completions/dot" "bash completion removed"
assert_file_not_exists "$XDG_DATA_HOME/dotfiles.log" "log removed"
assert_dir_not_exists "$XDG_STATE_HOME/dotfiles" "state removed"
assert_file_contains "$CHEZMOI_CALLS" "purge --force" "chezmoi purge invoked"

test_start "uninstall_skips_chezmoi_when_it_is_not_installed"
seed_artifacts
NOCM="$DOTFILES_COV_TMPDIR/nocm"
mkdir -p "$NOCM"
ln -sf "$(command -v bash)" "$NOCM/bash"
for c in rm printf echo cat sed grep; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$NOCM/$c"
done
PATH="$NOCM" run "$UNINSTALL" --force
assert_equals 0 "$RC" "rc"
assert_true "! grep -q 'Reverting chezmoi-managed' '$OUTF'" "chezmoi step skipped"
out_has "Uninstall complete." "still completes"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
