#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for scripts/ops/heal-system.sh — the symlink,
# critical-file and XDG-directory repair functions that heal.sh
# sources. A tiny driver sources the module with the variables and
# helpers heal.sh normally provides (DRY_RUN, FORCE, ISSUES_FOUND,
# FIXES_APPLIED, CHEZMOI_APPLIED, log_dry, persist_log, _pkg_install)
# and runs one function per case against a throwaway HOME.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Route child xtrace to the runner's trace stream even when a probe
# captures 2>&1 (fd 19: fd 9 is taken by lock handling elsewhere).
exec 21>&2
export BASH_XTRACEFD=21

HEAL_SYSTEM_FILE="$REPO_ROOT/scripts/ops/heal-system.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

_driver="$DOTFILES_COV_TMPDIR/driver.sh"
cat >"$_driver" <<'DRIVER'
#!/usr/bin/env bash
# Minimal stand-in for heal.sh's scope: same strict mode, same globals.
set -euo pipefail
source "${HEAL_SYSTEM_FILE:?}"
log_dry() { printf 'DRY: %s\n' "$*"; }
persist_log() { printf '%s\n' "$*" >>"${HEAL_LOG:?}"; }
_pkg_install() {
  shift 3
  "$@" >/dev/null 2>&1
}
DRY_RUN="${DRY_RUN:-0}"
FORCE="${FORCE:-0}"
CHEZMOI_APPLIED="${CHEZMOI_APPLIED:-0}"
ISSUES_FOUND=0
FIXES_APPLIED=0
rc=0
"$1" || rc=$?
printf 'ISSUES=%s FIXES=%s CHEZMOI_APPLIED=%s rc=%s\n' \
  "$ISSUES_FOUND" "$FIXES_APPLIED" "$CHEZMOI_APPLIED" "$rc"
DRIVER
export HEAL_SYSTEM_FILE
export HEAL_LOG="$DOTFILES_COV_TMPDIR/heal.log"

_fresh_home() { # <name> → sets HOME to an empty per-case directory
  HOME="$DOTFILES_COV_TMPDIR/homes/$1"
  export HOME
  mkdir -p "$HOME"
}

_run() { # <function> [ENV=val ...]  (stdin passes through)
  local fn="$1"
  shift
  env "$@" "$BASH_BIN" "$_driver" "$fn" 2>&1
}

# ── heal_broken_symlinks ──────────────────────────────────────────────

test_start "symlinks_clean_home_reports_ok"
_fresh_home clean
ln -s "$HOME" "$HOME/self-link"
_out="$(_run heal_broken_symlinks)"
assert_contains "✓" "$_out" "check mark printed"
assert_contains "symlinks" "$_out" "symlinks line printed"
assert_contains "ISSUES=0 FIXES=0" "$_out" "no issues counted"

test_start "symlinks_dry_run_lists_broken_links_and_skips_known_lock_files"
_fresh_home dry
ln -s /nonexistent/target-a "$HOME/dead-a"
mkdir -p "$HOME/google-chrome-backup"
ln -s /nonexistent/lock "$HOME/google-chrome-backup/SingletonLock"
ln -s /nonexistent/cookie "$HOME/SingletonCookie"
_out="$(_run heal_broken_symlinks DRY_RUN=1)"
assert_contains "DRY: remove broken symlink: $HOME/dead-a -> /nonexistent/target-a" "$_out" "broken link previewed"
assert_output_not_contains "SingletonCookie" printf '%s' "$_out"
assert_contains "ISSUES=1 FIXES=0" "$_out" "only the real broken link counted"
# `-e`/`-f` are false for a dangling symlink, so assert on `-L`.
assert_true "[[ -L '$HOME/dead-a' ]]" "dry-run leaves the broken link in place"

test_start "symlinks_prompt_honours_no_then_yes"
_fresh_home prompt
: >"$HEAL_LOG"
ln -s /nonexistent/one "$HOME/dead-1"
ln -s /nonexistent/two "$HOME/dead-2"
_out="$(printf 'n\ny\n' | _run heal_broken_symlinks)"
# No prompt text is asserted here: bash prints a `read -p` prompt only
# when stdin is a terminal, and this probe pipes the answers in. The
# answers themselves are the observable behaviour — one link stays.
assert_contains "ISSUES=2 FIXES=1" "$_out" "one of two removed"
assert_contains "removed broken symlink" "$(cat "$HEAL_LOG")" "removal persisted to heal log"
_left="$(find "$HOME" -maxdepth 1 -type l -name 'dead-*' | wc -l | tr -d ' ')"
assert_equals 1 "$_left" "exactly one broken link remains"

test_start "symlinks_lock_pattern_removed_without_prompt"
_fresh_home lockpat
ln -s /nonexistent/x "$HOME/app.SingletonLock.stale"
_out="$(_run heal_broken_symlinks </dev/null)"
assert_output_not_contains "Remove broken symlink" printf '%s' "$_out"
assert_contains "removed $HOME/app.SingletonLock.stale" "$_out" "lock-pattern link removed"
assert_contains "ISSUES=1 FIXES=1" "$_out" "fix counted"

test_start "symlinks_force_reports_unremovable_link"
_fresh_home ro
mkdir -p "$HOME/ro"
ln -s /nonexistent/y "$HOME/ro/dead"
chmod 555 "$HOME/ro"
_out="$(_run heal_broken_symlinks FORCE=1)"
chmod 755 "$HOME/ro"
assert_contains "could not remove $HOME/ro/dead" "$_out" "unremovable link reported"
assert_contains "ISSUES=1 FIXES=0" "$_out" "no fix counted"

test_start "symlinks_noninteractive_env_skips_prompt"
_fresh_home nonint
ln -s /nonexistent/z "$HOME/dead-z"
_out="$(_run heal_broken_symlinks DOTFILES_NONINTERACTIVE=1 </dev/null)"
assert_contains "removed $HOME/dead-z" "$_out" "link removed without prompt"

# ── heal_missing_critical_files ───────────────────────────────────────

test_start "critical_files_present_reports_ok"
_fresh_home crit-ok
touch "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"
_out="$(_run heal_missing_critical_files)"
assert_contains "shell configs" "$_out" "shell configs line printed"
assert_contains "ISSUES=0" "$_out" "no issues counted"

test_start "critical_files_missing_without_chezmoi_returns_1"
_fresh_home crit-nochezmoi
_out="$(_run heal_missing_critical_files PATH=/usr/bin:/bin)"
assert_contains "ISSUES=3 FIXES=0 CHEZMOI_APPLIED=0 rc=1" "$_out" "three missing, rc 1 without chezmoi"

test_start "critical_files_missing_dry_run_previews_chezmoi"
_fresh_home crit-dry
_out="$(_run heal_missing_critical_files DRY_RUN=1)"
assert_contains "DRY: regenerate missing files via chezmoi" "$_out" "dry-run preview printed"
assert_contains "ISSUES=3 FIXES=0" "$_out" "issues counted, nothing applied"

test_start "critical_files_already_applied_skips_chezmoi"
_fresh_home crit-applied
_out="$(_run heal_missing_critical_files CHEZMOI_APPLIED=1)"
assert_contains "ISSUES=3 FIXES=0 CHEZMOI_APPLIED=1" "$_out" "no second apply"

test_start "critical_files_chezmoi_apply_restores_and_counts"
_fresh_home crit-apply
: >"$HEAL_LOG"
_chez="$DOTFILES_COV_TMPDIR/chez"
mkdir -p "$_chez"
cat >"$_chez/chezmoi" <<'SHIM'
#!/usr/bin/env bash
# Fake chezmoi: `apply` materialises one of the critical files.
[[ "${1:-}" == "apply" ]] && touch "$HOME/.zshrc"
exit 0
SHIM
chmod +x "$_chez/chezmoi"
_out="$(_run heal_missing_critical_files PATH="$_chez:$PATH")"
assert_contains "ISSUES=3 FIXES=1 CHEZMOI_APPLIED=1" "$_out" "one file restored and applied flag set"
assert_contains "regenerated 1 critical file(s)" "$(cat "$HEAL_LOG")" "restore persisted to heal log"
assert_file_exists "$HOME/.zshrc" "shim apply wrote .zshrc"

# ── heal_missing_xdg_dirs ─────────────────────────────────────────────

test_start "xdg_dirs_present_reports_ok"
_fresh_home xdg-ok
mkdir -p "$HOME/.config/shell" "$HOME/.config/nvim" "$HOME/.config/git"
_out="$(_run heal_missing_xdg_dirs)"
assert_contains "xdg directories" "$_out" "xdg line printed"
assert_contains "ISSUES=0 FIXES=0" "$_out" "no issues counted"

test_start "xdg_dirs_missing_dry_run_previews_creation"
_fresh_home xdg-dry
_out="$(_run heal_missing_xdg_dirs DRY_RUN=1)"
assert_contains "DRY: create directory: $HOME/.config/nvim" "$_out" "creation previewed"
assert_contains "ISSUES=3 FIXES=0" "$_out" "three missing, none created"
assert_dir_not_exists "$HOME/.config/nvim" "dry-run creates nothing"

test_start "xdg_dirs_missing_are_created"
_fresh_home xdg-fix
: >"$HEAL_LOG"
_out="$(_run heal_missing_xdg_dirs)"
assert_contains "ISSUES=3 FIXES=3" "$_out" "three created"
assert_dir_exists "$HOME/.config/shell" "shell dir created"
assert_dir_exists "$HOME/.config/git" "git dir created"
assert_contains "created directory $HOME/.config/nvim" "$(cat "$HEAL_LOG")" "creation persisted to heal log"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
