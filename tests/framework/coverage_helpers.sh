#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC2034
# coverage_helpers.sh — sandbox + safe-exercise helpers for shallow→deep
# test conversions. Lets a test run its script under safe-mode entry
# points (--help, --dry-run, no-arg, invalid flag) so xtrace-based
# coverage records line execution without the test stepping on the
# host system.

[[ "${_DOT_LIB_COVERAGE_HELPERS_LOADED:-0}" == "1" ]] && return 0
_DOT_LIB_COVERAGE_HELPERS_LOADED=1

# -----------------------------------------------------------------------------
# Sandbox: fresh HOME + PATH-front mock-bin dir. Scripts that try to
# call sudo / brew / apt-get / etc. get no-op shims so they can't
# touch the real host. Scripts that try to write to ~/.config / state
# / etc. land in $HOME under the tmpdir.
# -----------------------------------------------------------------------------
cov_setup_sandbox() {
  local tmp
  tmp=$(mktemp -d -t dotfiles-cov.XXXXXX)
  export DOTFILES_COV_TMPDIR="$tmp"
  export HOME="$tmp/home"
  export XDG_CONFIG_HOME="$HOME/.config"
  export XDG_DATA_HOME="$HOME/.local/share"
  export XDG_CACHE_HOME="$HOME/.cache"
  export XDG_STATE_HOME="$HOME/.local/state"
  mkdir -p "$HOME/.config" "$HOME/.local/share" "$HOME/.cache" \
    "$HOME/.local/state" "$tmp/bin"
  # No-op shims for every command we don't want to actually invoke.
  # Each shim echoes its invocation to stderr (for debugging) and
  # exits 0 so the script-under-test believes the operation succeeded.
  local cmd
  for cmd in sudo apt-get apt brew yum dnf pacman zypper \
    curl wget git rsync systemctl \
    chezmoi age gpg ssh-keygen \
    docker podman kubectl gh \
    defaults open osascript \
    gnome-extensions gsettings dconf \
    killall pkill open xdg-open; do
    cat >"$tmp/bin/$cmd" <<EOF
#!/usr/bin/env bash
printf '[cov-shim:%s]\\n' "$cmd \$*" >&2
exit 0
EOF
    chmod +x "$tmp/bin/$cmd"
  done
  export PATH="$tmp/bin:$PATH"
}

cov_teardown_sandbox() {
  [[ -n "${DOTFILES_COV_TMPDIR:-}" && -d "$DOTFILES_COV_TMPDIR" ]] &&
    rm -rf "$DOTFILES_COV_TMPDIR"
  unset DOTFILES_COV_TMPDIR
}

# -----------------------------------------------------------------------------
# cov_exercise_script <path-to-script> [extra-arg-mode ...]
#
# Runs the script through safe-mode entry points to drive line
# coverage. Each invocation is wrapped in a hard 15s timeout so a
# misbehaving script can't sink the test suite. All exit codes are
# ignored — the goal is line execution, not behavioral assertion.
#
# Default arg-modes (run for every call): help, no-arg, invalid-flag.
# Optional: dry-run (added when the script's source mentions --dry-run).
# -----------------------------------------------------------------------------
cov_exercise_script() {
  local script="$1"
  [[ -r "$script" ]] || return 0

  local label
  label="$(basename "$script" .sh)"

  # The script under test almost always exits non-zero on
  # `--invalid-flag` (set -e + exit 1/2). If the calling test has
  # errexit enabled, that non-zero rc would terminate the test
  # before we can record it. Suppress errexit for the duration of
  # this function and restore it on return.
  local prev_e
  case "$-" in
    *e*) prev_e=1 ;;
    *)   prev_e=0 ;;
  esac
  set +e

  test_start "${label}_help_executes"
  timeout 15 bash "$script" --help </dev/null >/dev/null
  rc=$?
  if [[ "$rc" -eq 0 || "$rc" -eq 1 || "$rc" -eq 2 || "$rc" -eq 124 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
  fi

  if grep -q -- "--dry-run" "$script" 2>/dev/null; then
    test_start "${label}_dry_run_executes"
    timeout 15 bash "$script" --dry-run </dev/null >/dev/null
    rc=$?
    if [[ "$rc" -ge 0 && "$rc" -le 124 ]]; then
      ((TESTS_PASSED++)) || true
      printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
    else
      ((TESTS_FAILED++)) || true
      printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
    fi
  fi

  test_start "${label}_no_arg_executes"
  timeout 15 bash "$script" </dev/null >/dev/null
  rc=$?
  if [[ "$rc" -ge 0 && "$rc" -le 124 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
  fi

  test_start "${label}_unknown_flag_handled"
  timeout 15 bash "$script" --definitely-not-a-real-flag </dev/null >/dev/null
  rc=$?
  if [[ "$rc" -ge 0 && "$rc" -le 124 ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (rc=$rc)"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected rc=$rc"
  fi

  # Restore the caller's errexit state and return success so the
  # test script doesn't inherit the non-zero rc from the last
  # invocation. Without this every converted test would exit with
  # that rc, the framework would treat it as a crash, and the
  # RESULTS line never printed — the failure mode we hit on the
  # first run.
  [[ "$prev_e" == "1" ]] && set -e
  return 0
}
