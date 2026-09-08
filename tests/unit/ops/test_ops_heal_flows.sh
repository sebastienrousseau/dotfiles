#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# End-to-end flows for scripts/ops/heal.sh: flag parsing, the
# concurrency lock (flock present / absent, lock held), the
# interactive confirmation, dry-run vs apply, and every summary line.
# Every dependency heal checks for is a PATH shim, `mise` is a shim
# (so nothing is downloaded), the lock lives in a sandbox
# XDG_RUNTIME_DIR, and HOME is the cov sandbox — nothing on the host
# is repaired.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Route child xtrace to the runner's trace stream even when a probe
# captures 2>&1. heal.sh itself does `exec 9>lockfile`, so fd 9 is
# NOT usable here — fd 19 keeps the trace intact past the lock.
exec 21>&2
export BASH_XTRACEFD=21

HEAL_FILE="$REPO_ROOT/scripts/ops/heal.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# Substring refutation on an already-captured string. The framework's
# assert_output_not_contains re-runs its arguments through `eval`, so
# feeding captured output back in breaks on any shell metacharacter the
# program happened to print.
_refute_contains() { # <needle> <haystack> <msg>
  if [[ "$2" != *"$1"* ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $3"
    return 0
  fi
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $3"
  printf '%b\n' "    Should not contain: '$1'"
  return 1
}

# Shim every tool heal_missing_dependencies probes so the dependency
# pass is deterministic (zero missing) regardless of the host.
_deps="$DOTFILES_COV_TMPDIR/deps"
mkdir -p "$_deps"
for _t in zsh chezmoi starship rg bat fzf zoxide atuin yazi zellij nu pueue pueued wasmtime sops age hyperfine mise direnv; do
  printf '#!/usr/bin/env bash\nexit 0\n' >"$_deps/$_t"
  chmod +x "$_deps/$_t"
done
export PATH="$_deps:$PATH"

# Lock directory under the sandbox so parallel test files never share
# /tmp/dotfiles-heal.lock.
export XDG_RUNTIME_DIR="$DOTFILES_COV_TMPDIR/run"
mkdir -p "$XDG_RUNTIME_DIR"
_lock_dir="$XDG_RUNTIME_DIR/dotfiles-heal.lock.d"

_heal() { # [args]  (stdin passes through)
  "$BASH_BIN" "$HEAL_FILE" "$@" 2>&1
}

_healthy_home() { # make HOME pass every heal check
  touch "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"
  mkdir -p "$HOME/.config/shell" "$HOME/.config/nvim" "$HOME/.config/git"
}

_unhealthy_home() { # remove the critical files heal looks for
  rm -f "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"
  rm -rf "$HOME/.config/shell" "$HOME/.config/nvim" "$HOME/.config/git"
}

test_start "help_prints_usage_and_exits_0"
_out="$(_heal --help)"
_rc=$?
assert_equals 0 "$_rc" "--help exits 0"
assert_contains "Dotfiles Heal - Auto-repair common issues" "$_out" "usage banner printed"

test_start "unknown_option_prints_usage_and_exits_1"
_out="$(_heal --bogus)"
_rc=$?
assert_equals 1 "$_rc" "unknown option exits 1"
assert_contains "Unknown option: --bogus" "$_out" "option named"
assert_contains "Usage:" "$_out" "usage printed after error"

test_start "dry_run_counts_issues_without_fixing"
_unhealthy_home
_out="$(_heal --dry-run)"
_rc=$?
assert_equals 0 "$_rc" "dry-run exits 0"
assert_contains "Dry-run mode (no changes will be made)" "$_out" "dry-run announced"
assert_contains "issue(s). Run without --dry-run to apply fixes." "$_out" "issue count summarised"
assert_file_not_exists "$HOME/.config/nvim" "dry-run created nothing"

test_start "dry_run_healthy_home_reports_healthy"
_healthy_home
_out="$(_heal -n)"
_rc=$?
assert_equals 0 "$_rc" "dry-run exits 0"
assert_contains "Healthy." "$_out" "healthy summary printed"

test_start "force_apply_fixes_issues_and_logs_completion"
_unhealthy_home
rm -f "$XDG_STATE_HOME/dotfiles/heal.log"
_out="$(_heal --force)"
_rc=$?
assert_equals 0 "$_rc" "forced heal exits 0"
assert_contains "Done!" "$_out" "done summary printed"
assert_contains "fix(es) for" "$_out" "fix count summarised"
assert_dir_exists "$HOME/.config/nvim" "missing xdg dir was created"
assert_contains "HEAL_COMPLETE:" "$(cat "$XDG_STATE_HOME/dotfiles/heal.log")" "completion persisted"

test_start "interactive_decline_aborts"
_healthy_home
_out="$(printf 'n\n' | _heal)"
_rc=$?
assert_equals 0 "$_rc" "declined heal exits 0"
assert_contains "This will auto-repair" "$_out" "confirmation shown"
assert_contains "Aborted." "$_out" "abort acknowledged"

test_start "interactive_accept_on_healthy_home_reports_healthy"
_healthy_home
_out="$(printf 'y\n' | _heal)"
_rc=$?
assert_equals 0 "$_rc" "accepted heal exits 0"
assert_contains "Healthy." "$_out" "healthy summary printed after apply pass"

test_start "issues_without_possible_fix_points_at_doctor"
_healthy_home
mkdir -p "$HOME/ro"
ln -s /nonexistent/target "$HOME/ro/dead"
chmod 555 "$HOME/ro"
_out="$(DOTFILES_NONINTERACTIVE=1 _heal)"
_rc=$?
chmod 755 "$HOME/ro"
rm -rf "$HOME/ro"
assert_equals 0 "$_rc" "unfixable issue still exits 0"
assert_contains "but no fixes could be applied" "$_out" "no-fix summary printed"
assert_contains "dot doctor" "$_out" "doctor hint printed"

test_start "flock_available_takes_the_lock_and_runs"
_flock="$DOTFILES_COV_TMPDIR/flock-ok"
mkdir -p "$_flock"
printf '#!/usr/bin/env bash\nexit 0\n' >"$_flock/flock"
chmod +x "$_flock/flock"
_healthy_home
_out="$(PATH="$_flock:$PATH" _heal -n)"
_rc=$?
assert_equals 0 "$_rc" "flock path exits 0"
assert_contains "Healthy." "$_out" "run proceeds after flock"
assert_file_exists "$XDG_RUNTIME_DIR/dotfiles-heal.lock" "lock file opened in XDG_RUNTIME_DIR"

test_start "flock_contended_and_lock_dir_held_reports_already_running"
_flockno="$DOTFILES_COV_TMPDIR/flock-no"
mkdir -p "$_flockno"
printf '#!/usr/bin/env bash\nexit 1\n' >"$_flockno/flock"
chmod +x "$_flockno/flock"
mkdir -p "$_lock_dir"
_out="$(PATH="$_flockno:$PATH" _heal -n)"
_rc=$?
assert_equals 0 "$_rc" "contended lock exits 0"
assert_contains "Already running" "$_out" "already-running warning printed"
_refute_contains "Dotfiles Heal" "$_out" "the banner is suppressed"
rmdir "$_lock_dir"

test_start "without_flock_held_lock_dir_reports_already_running"
_noflock="$DOTFILES_COV_TMPDIR/noflock"
mkdir -p "$_noflock"
for _t in bash env dirname basename find readlink date mkdir rmdir rm cat sed awk grep head tail tr wc sort uname tput touch cp mv chmod stat printf; do
  _p="$(command -v "$_t" 2>/dev/null || true)"
  [[ -n "$_p" ]] && ln -sf "$_p" "$_noflock/$_t"
done
mkdir -p "$_lock_dir"
_out="$(PATH="$_deps:$_noflock" _heal -n)"
_rc=$?
assert_equals 0 "$_rc" "held lock dir exits 0"
assert_contains "Already running" "$_out" "already-running warning printed"
rmdir "$_lock_dir"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
