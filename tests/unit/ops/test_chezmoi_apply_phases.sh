#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# chezmoi-apply.sh phase by phase: lock, run_step, snapshot, the AI
# provider offer, post-apply repair. Every run is sandboxed (HOME, XDG
# dirs, runtime dir) with stub chezmoi/mise/gum/curl/flock recording their
# calls; curl always fails, so no installer is ever downloaded.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

APPLY="$REPO_ROOT/scripts/ops/chezmoi-apply.sh"
REAL_BASH="$(command -v bash)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
N=0

# stub <name> <body>: a command that logs "name args" to calls, then runs body.
stub() {
  {
    printf '#!%s\n' "$REAL_BASH"
    printf 'printf "%%s\\n" "%s $*" >>"%s/calls"\n' "$1" "$D"
    printf '%s\n' "$2"
  } >"$D/stubs/$1"
  chmod +x "$D/stubs/$1"
}

# new_case: a fresh sandbox with chezmoi, dot, mise, curl and a free flock.
new_case() {
  N=$((N + 1))
  D="$WORK/c$N"
  mkdir -p "$D/home/.config" "$D/home/.local/state" "$D/home/.cache" "$D/run" "$D/stubs"
  : >"$D/calls"
  stub chezmoi 'case "$1" in apply) [ -n "${STUB_OUT:-}" ] && echo "$STUB_OUT"; exit "${STUB_RC:-0}" ;; esac; exit 0'
  stub dot 'exit 0'
  stub curl 'exit 1'
  stub mise 'exit 0'
  stub flock 'exit 0'
}

# with_gum: gum spin runs its command; choose answers GUM_CHOICE (or, with
# --no-limit, the comma-separated GUM_PICK).
with_gum() {
  stub gum '
case "$1" in
  spin) while [ "$#" -gt 0 ] && [ "$1" != "--" ]; do shift; done; shift; "$@"; exit $? ;;
  choose)
    case "$*" in
      *--no-limit*) printf "%s\n" "${GUM_PICK:-}" | tr "," "\n" ;;
      *) printf "%s\n" "${GUM_CHOICE:-Skip}" ;;
    esac ;;
esac
exit 0'
}

_env() {
  env -i HOME="$D/home" XDG_CONFIG_HOME="$D/home/.config" XDG_STATE_HOME="$D/home/.local/state" \
    XDG_CACHE_HOME="$D/home/.cache" XDG_RUNTIME_DIR="$D/run" TMPDIR="$D/run" \
    PATH="$D/stubs:/usr/bin:/bin" TERM=dumb NO_COLOR=1 LANG=C.UTF-8 "$@"
}

# apply [VAR=value...]: run without a terminal; sets OUT and RC.
apply() {
  RC=0
  OUT="$(cd "$D" && _env "$@" "$REAL_BASH" "$APPLY" </dev/null 2>&1)" || RC=$?
}

# apply_tty [VAR=value...]: run on a pseudo-terminal (stdin and stdout are
# TTYs). stdin is held open until the run ends: util-linux script(1)
# hangs up the child once its stdin reaches EOF.
apply_tty() {
  local inner="$D/inner.sh" i=0
  {
    printf '#!%s\n' "$REAL_BASH"
    printf 'cd %q\n' "$D"
    printf 'env -i HOME=%q XDG_CONFIG_HOME=%q XDG_STATE_HOME=%q XDG_CACHE_HOME=%q XDG_RUNTIME_DIR=%q TMPDIR=%q PATH=%q TERM=dumb NO_COLOR=1 LANG=C.UTF-8' \
      "$D/home" "$D/home/.config" "$D/home/.local/state" "$D/home/.cache" "$D/run" "$D/run" "$D/stubs:/usr/bin:/bin"
    printf ' %q' "$@" "$REAL_BASH" "$APPLY"
    printf '\necho $? >%q\n' "$D/tty.rc"
  } >"$inner"
  chmod +x "$inner"
  {
    while [[ ! -f "$D/tty.rc" && $i -lt 600 ]]; do
      sleep 0.1
      i=$((i + 1))
    done
  } | if [[ "$(uname -s)" == Darwin ]]; then
    script -q "$D/tty.out" "$inner" >/dev/null 2>&1
  else
    script -qec "$inner" "$D/tty.out" >/dev/null 2>&1
  fi
  RC="$(cat "$D/tty.rc" 2>/dev/null || echo none)"
  OUT="$(tr -d '\r' <"$D/tty.out" 2>/dev/null)"
}

called() { grep -qF -- "$1" "$D/calls"; }
yes_no() { if "$@"; then echo yes; else echo no; fi; }
has() { [[ "$OUT" == *"$1"* ]]; }

# ── lock ──────────────────────────────────────────────────────────────
test_start "apply_lock_held_by_another_run_is_a_clean_no_op"
new_case
stub flock 'exit 1'
apply
assert_equals "0:yes:no" "$RC:$(yes_no has 'Already running'):$(yes_no called 'chezmoi apply')" \
  "a busy lock warns, exits 0 and never applies"

test_start "apply_lock_free_applies"
new_case
apply
assert_equals "0:yes" "$RC:$(yes_no called 'chezmoi apply --force')" "a free lock applies with --force"

# ── run_step ──────────────────────────────────────────────────────────
test_start "apply_failure_shows_the_captured_output_and_exits_1"
new_case
apply STUB_RC=2 STUB_OUT=boom
assert_equals "1:yes:no" "$RC:$(yes_no has boom):$(yes_no has Status)" \
  "a failed apply prints its output and stops before the status phase"

test_start "apply_output_is_hidden_unless_verbose"
new_case
apply STUB_OUT=applied-output
assert_equals "no" "$(yes_no has applied-output)" "quiet by default"

test_start "apply_output_is_shown_with_verbose"
new_case
apply STUB_OUT=applied-output DOTFILES_CHEZMOI_VERBOSE=1
assert_equals "yes" "$(yes_no has applied-output)" "DOTFILES_CHEZMOI_VERBOSE=1 shows it"

test_start "apply_verbose_with_no_output_prints_nothing_extra"
new_case
apply DOTFILES_CHEZMOI_VERBOSE=1
assert_equals "0" "$RC" "an empty capture is fine"

# ── snapshot and repair ───────────────────────────────────────────────
test_start "apply_takes_a_baseline_snapshot_on_first_run"
new_case
apply
assert_file_exists "$D/home/.local/state/dotfiles/snapshots/baseline.json" "baseline written"

test_start "apply_snapshot_can_be_turned_off"
new_case
apply DOTFILES_SNAPSHOT_ON_APPLY=0
assert_file_not_exists "$D/home/.local/state/dotfiles/snapshots/baseline.json" "no baseline"

test_start "apply_runs_post_apply_repair_by_default"
new_case
apply
assert_equals "yes" "$(yes_no has 'Post-apply checks')" "repair runs"

test_start "apply_post_apply_repair_can_be_turned_off"
new_case
apply DOTFILES_POST_APPLY_REPAIR=0
assert_equals "no" "$(yes_no has 'Post-apply checks')" "repair skipped"

# ── AI provider offer ─────────────────────────────────────────────────
test_start "apply_without_a_terminal_never_offers_installs"
new_case
with_gum
apply GUM_CHOICE="Install all"
assert_equals "0:no" "$RC:$(yes_no called 'gum choose')" "no TTY, no menu"

if command -v script >/dev/null 2>&1; then
  test_start "apply_tty_failure_under_gum_exits_1"
  new_case
  with_gum
  apply_tty STUB_RC=2 STUB_OUT=boom
  assert_equals "1:yes:yes" "$RC:$(yes_no has boom):$(yes_no has '✗')" \
    "the spinner path reports the failed step and stops"

  test_start "apply_tty_install_all_installs_every_missing_provider"
  new_case
  with_gum
  apply_tty GUM_CHOICE="Install all"
  assert_equals "0:yes:yes:yes" \
    "$RC:$(yes_no called 'gum choose --header'):$(yes_no called 'mise use -g npm:@openai/codex@0.159.3'):$(yes_no called 'mise use -g npm:@guizmo-ai/zai-cli@0.3.5')" \
    "mise installs each one, and the run completes"

  test_start "apply_tty_install_all_tries_native_installers"
  assert_equals "yes:yes" "$(yes_no called 'curl'):$(yes_no has 'Shell reload')" \
    "claude's native installer is tried (curl), then the run carries on"

  test_start "apply_tty_choose_installs_only_the_picked_providers"
  new_case
  with_gum
  apply_tty GUM_CHOICE="Choose which to install" GUM_PICK="Codex CLI,,Qwen Code"
  assert_equals "0:yes:yes:no" \
    "$RC:$(yes_no called 'mise use -g npm:@openai/codex@0.159.3'):$(yes_no called 'mise use -g npm:@qwen-code/qwen-code@0.24.7'):$(yes_no called 'npm:@github/copilot')" \
    "codex and qwen, not copilot; blank picks are ignored"

  test_start "apply_tty_skip_installs_nothing"
  new_case
  with_gum
  apply_tty GUM_CHOICE=Skip
  assert_equals "0:yes:no" "$RC:$(yes_no called 'gum choose --header'):$(yes_no called 'mise use')" "skip means skip"

  test_start "apply_tty_noninteractive_never_offers_installs"
  new_case
  with_gum
  apply_tty DOTFILES_NONINTERACTIVE=1 GUM_CHOICE="Install all"
  assert_equals "0:no" "$RC:$(yes_no called 'gum choose')" "DOTFILES_NONINTERACTIVE=1 suppresses the menu"

  test_start "apply_tty_ci_never_offers_installs"
  new_case
  with_gum
  apply_tty CI=1 GUM_CHOICE="Install all"
  assert_equals "0:no" "$RC:$(yes_no called 'gum choose')" "CI suppresses the menu"

  test_start "apply_tty_without_mise_explains_and_carries_on"
  new_case
  with_gum
  rm -f "$D/stubs/mise"
  apply_tty GUM_CHOICE="Install all"
  assert_equals "0:yes:no:yes" \
    "$RC:$(yes_no has 'install mise first'):$(yes_no called 'gum choose'):$(yes_no has 'Shell reload')" \
    "no mise: a hint, no menu, and the run completes"
else
  echo "  script(1) missing — pty cases skipped"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
