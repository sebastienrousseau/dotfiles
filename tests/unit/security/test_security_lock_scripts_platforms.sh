#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Platform tests for the two security lock scripts.
#
# lock-configs.sh sets immutability flags (chflags on macOS, sudo chattr
# on Linux) and lock-screen.sh writes screensaver settings through
# gsettings or `defaults`. Both would change real machine state, so every
# case runs with PATH pointing at recording shims and OSTYPE / uname
# chosen by the test. The shims append their argv to a log the tests
# then assert on; nothing reaches the host.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# The assertions below capture each child's stdout and stderr, which
# would also swallow the xtrace records the repo's coverage runner reads
# from stderr. Hand every child a copy of this test's real stderr on
# fd 21 and point BASH_XTRACEFD at it, so its line records still reach
# the runner while the captured text stays clean.
exec 21>&2

CONFIGS_FILE="$REPO_ROOT/scripts/security/lock-configs.sh"
SCREEN_FILE="$REPO_ROOT/scripts/security/lock-screen.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"
CALLS="$TMP/lock-calls.log"
LHOME="$TMP/lock-home"
mkdir -p "$LHOME"
printf '# zshrc\n' >"$LHOME/.zshrc"
printf '# bashrc\n' >"$LHOME/.bashrc"
printf '# profile\n' >"$LHOME/.profile"

L_BIN=""
_l_scenario() {
  L_BIN="$TMP/lock-$1"
  shift
  mkdir -p "$L_BIN"
  local tool p
  for tool in cat env printf sed grep tr dirname basename uname locale tput "$@"; do
    p="$(command -v "$tool" 2>/dev/null || true)"
    [[ -n "$p" ]] && ln -sf "$p" "$L_BIN/$tool"
  done
  ln -sf "$BASH" "$L_BIN/bash"
}

_l_record() {
  rm -f "$L_BIN/$1"
  cat >"$L_BIN/$1" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "$1" "\$*" >>"$CALLS"
exit 0
EOF
  chmod +x "$L_BIN/$1"
}

_l_shim() {
  rm -f "$L_BIN/$1"
  cat >"$L_BIN/$1"
  chmod +x "$L_BIN/$1"
}

L_OUT=""
L_RC=0
# _run_lock <script> [env-assignments...] -- [args...]
_run_lock() {
  local script="$1"
  shift
  local env_args=()
  while [[ "$#" -gt 0 && "$1" != "--" ]]; do
    env_args+=("$1")
    shift
  done
  shift || true
  L_RC=0
  : >"$CALLS"
  L_OUT="$(
    env BASH_XTRACEFD=21 PATH="$L_BIN" HOME="$LHOME" DOTFILES_ACCESSIBILITY=1 \
      "${env_args[@]}" "$BASH" "$script" "$@" </dev/null 2>&1
  )" || L_RC=$?
}

_l_expect() {
  local label="$1" want_rc="$2"
  shift 2
  local needle problems=""
  [[ "$L_RC" == "$want_rc" ]] || problems="${problems}\n      rc: want $want_rc, got $L_RC"
  for needle in "$@"; do
    if [[ "$needle" == "CALL:"* ]]; then
      grep -qF -- "${needle#CALL:}" "$CALLS" 2>/dev/null ||
        problems="${problems}\n      missing call: ${needle#CALL:}"
    elif [[ "$needle" == "NOT:"* ]]; then
      [[ "$L_OUT" == *"${needle#NOT:}"* ]] &&
        problems="${problems}\n      unexpected: ${needle#NOT:}"
    else
      [[ "$L_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
    fi
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$L_OUT" | sed 's/^/      /'
    sed 's/^/      call: /' "$CALLS" 2>/dev/null || true
  fi
}

# =======================================================================
# lock-configs.sh — macOS uses chflags.
# =======================================================================
_l_scenario configs_macos
_l_record chflags
_l_record ls

_run_lock "$CONFIGS_FILE" OSTYPE=darwin24 --
_l_expect "configs_macos_lock_is_the_default_action" 0 \
  "Locking critical configuration files..." "Processing:" ".zshrc" \
  "Done. Environment state:" \
  "CALL:chflags uchg" "CALL:ls -lO"

_run_lock "$CONFIGS_FILE" OSTYPE=darwin24 -- unlock
_l_expect "configs_macos_unlock" 0 \
  "Unlocking critical configuration files..." "CALL:chflags nouchg"

_run_lock "$CONFIGS_FILE" OSTYPE=darwin24 -- sideways
_l_expect "configs_unknown_action_exits_1" 1 "Usage:" "[lock|unlock]"

# A failing lock command is reported per file but does not abort.
_l_scenario configs_macos_fail
_l_record ls
_l_shim chflags <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
_run_lock "$CONFIGS_FILE" OSTYPE=darwin24 --
_l_expect "configs_reports_a_failed_flag_change" 0 "Failed to modify flags for"

# The final status-report loop ends in `[[ -f "$file" ]] && $CHECK_CMD`,
# so when the last critical file is absent the loop's status — and with
# it the script's — is 1 even though every present file was processed.
_l_scenario configs_macos_partial
_l_record chflags
_l_record ls
rm -f "$LHOME/.profile"
_run_lock "$CONFIGS_FILE" OSTYPE=darwin24 --
_l_expect "configs_still_processes_present_files_when_one_is_absent" 1 \
  "Processing:" ".zshrc" "Done. Environment state:" "CALL:chflags uchg"
printf '# profile\n' >"$LHOME/.profile"

# =======================================================================
# lock-configs.sh — Linux needs chattr plus a usable sudo.
# =======================================================================
_l_scenario configs_linux
_l_record chattr
_l_record lsattr
_l_shim sudo <<EOF
#!/usr/bin/env bash
if [[ "\${1:-}" == "-n" ]]; then exit 0; fi
printf 'sudo %s\n' "\$*" >>"$CALLS"
shift 0
exec "\$@"
EOF
_run_lock "$CONFIGS_FILE" OSTYPE=linux-gnu --
_l_expect "configs_linux_uses_sudo_chattr" 0 \
  "Locking critical configuration files..." "CALL:chattr +i" "CALL:lsattr"

_run_lock "$CONFIGS_FILE" OSTYPE=linux-gnu -- unlock
_l_expect "configs_linux_unlock_uses_chattr_minus_i" 0 "CALL:chattr -i"

_l_scenario configs_linux_nosudo
_l_record chattr
_run_lock "$CONFIGS_FILE" OSTYPE=linux-gnu --
_l_expect "configs_linux_without_sudo_exits_1" 1 \
  "'sudo' not found; chattr requires root. Aborting."

_l_scenario configs_linux_sudo_needs_password
_l_record chattr
_l_shim sudo <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
_run_lock "$CONFIGS_FILE" OSTYPE=linux-gnu --
_l_expect "configs_linux_without_a_tty_exits_1" 1 \
  "sudo requires a password but no TTY is attached. Aborting."

_l_scenario configs_linux_nochattr
_run_lock "$CONFIGS_FILE" OSTYPE=linux-gnu --
_l_expect "configs_linux_without_chattr_exits_1" 1 \
  "'chattr' not found. Cannot set immutability on Linux without it."

# =======================================================================
# lock-screen.sh — opt-in guard, dry-run, and the platform arms.
# =======================================================================
_ls_uname() {
  _l_shim uname <<EOF
#!/usr/bin/env bash
echo "$1"
EOF
}

_l_scenario screen_macos
_l_record defaults
_ls_uname Darwin
_run_lock "$SCREEN_FILE" --
_l_expect "screen_lock_is_opt_in" 1 \
  "Lock Screen" "disabled by default" "DOTFILES_LOCK=1" "NOT:Enabling"

_run_lock "$SCREEN_FILE" DOTFILES_LOCK=1 --
_l_expect "screen_macos_writes_screensaver_defaults" 0 \
  "Enabling" "lock on sleep and screensaver (macOS)" \
  "CALL:defaults write com.apple.screensaver askForPassword -int 1" \
  "CALL:defaults write com.apple.screensaver askForPasswordDelay -int 0" \
  "CALL:defaults -currentHost write com.apple.screensaver idleTime -int 300"

_run_lock "$SCREEN_FILE" -- --dry-run
_l_expect "screen_dry_run_changes_nothing" 0 \
  "dry-run (no changes will be made)" "[dry-run]" "defaults write com.apple.screensaver"

test_start "screen_dry_run_invoked_no_command"
if [[ ! -s "$CALLS" ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: dry-run must not run defaults"
  sed 's/^/      /' "$CALLS"
fi

_run_lock "$SCREEN_FILE" -- -n
_l_expect "screen_dry_run_short_flag" 0 "dry-run (no changes will be made)"

_l_scenario screen_linux
_l_record gsettings
_ls_uname Linux
_run_lock "$SCREEN_FILE" DOTFILES_LOCK=1 --
_l_expect "screen_linux_uses_gsettings" 0 \
  "Enabling" "screen lock and idle timeout" \
  "CALL:gsettings set org.gnome.desktop.screensaver lock-enabled true" \
  "CALL:gsettings set org.gnome.desktop.session idle-delay 300" \
  "CALL:gsettings set org.gnome.desktop.screensaver lock-delay 0"

_l_scenario screen_linux_bare
_ls_uname Linux
_run_lock "$SCREEN_FILE" DOTFILES_LOCK=1 --
_l_expect "screen_linux_without_gsettings_exits_1" 1 "gsettings" "not found"

_l_scenario screen_bsd
_ls_uname FreeBSD
_run_lock "$SCREEN_FILE" DOTFILES_LOCK=1 --
_l_expect "screen_unsupported_platform_exits_1" 1 \
  "Unsupported OS" "lock screen hardening"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
