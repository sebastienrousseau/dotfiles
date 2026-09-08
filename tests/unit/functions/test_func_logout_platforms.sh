#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Platform-branch tests for the logout shell function.
#
# logout() shells out to osascript / gnome-session-quit / loginctl /
# shutdown, so every case below sources the file in a subshell whose
# PATH holds only fixture shims plus a sysbin of symlinked coreutils.
# Nothing can reach a real session manager: the shims record the
# invocation and return the exit status the case under test needs.

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

LOGOUT_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/misc/logout.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

TMP="$DOTFILES_COV_TMPDIR"
SYSBIN="$TMP/lo-sysbin"
mkdir -p "$SYSBIN"
for tool in tr cat env printf uname grep sed; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$SYSBIN/$tool"
done
ln -sf "$BASH" "$SYSBIN/bash"

LO_BIN=""
_lo_scenario() {
  LO_BIN="$TMP/lo-$1"
  mkdir -p "$LO_BIN"
}

_lo_shim() {
  cat >"$LO_BIN/$1"
  chmod +x "$LO_BIN/$1"
}

# _lo_uname <name>: `uname` with no arguments is what logout() reads.
_lo_uname() {
  printf '#!/usr/bin/env bash\necho "%s"\n' "$1" >"$LO_BIN/uname"
  chmod +x "$LO_BIN/uname"
}

LO_OUT=""
LO_RC=0
# _run_logout <stdin-text> [args...]
_run_logout() {
  local stdin_text="$1"
  shift
  LO_RC=0
  LO_OUT="$(
    printf '%s' "$stdin_text" |
      env BASH_XTRACEFD=21 PATH="$LO_BIN:$SYSBIN" HOME="$TMP/lo-home" USER=fixtureuser \
        "$BASH" -c 'source "$1"; shift; logout "$@"' _ "$LOGOUT_SOURCE" "$@" 2>&1
  )" || LO_RC=$?
}

_lo_expect() {
  local label="$1" want_rc="$2"
  shift 2
  local needle problems=""
  [[ "$LO_RC" == "$want_rc" ]] || problems="${problems}\n      rc: want $want_rc, got $LO_RC"
  for needle in "$@"; do
    if [[ "$needle" == "NOT:"* ]]; then
      [[ "$LO_OUT" == *"${needle#NOT:}"* ]] &&
        problems="${problems}\n      unexpected: ${needle#NOT:}"
    else
      [[ "$LO_OUT" == *"$needle"* ]] || problems="${problems}\n      missing: $needle"
    fi
  done
  test_start "$label"
  if [[ -z "$problems" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST$problems"
    printf '%s\n' "$LO_OUT" | sed 's/^/      /'
  fi
}

mkdir -p "$TMP/lo-home"
LOGOUT_SOURCE="$LOGOUT_FILE"

# =======================================================================
# 1. --help short-circuits before any platform detection.
# =======================================================================
_lo_scenario help
_run_logout "" --help
_lo_expect "help_prints_usage_and_returns_0" 0 \
  "Cross-Platform Logout Utility (logout)" "logout [--force] [--help]" \
  "--force     Skips confirmation" "NOT:Logging out"

# =======================================================================
# 2. Confirmation prompt: anything but y/Y cancels.
# =======================================================================
_lo_scenario confirm
_lo_uname Darwin
_lo_shim osascript <<'EOF'
#!/usr/bin/env bash
echo "osascript: $*"
exit 0
EOF
_run_logout $'n\n'
_lo_expect "declining_confirmation_cancels" 0 \
  "Are you sure you want to log out?" "Logout canceled." "NOT:Logging out from macOS"

_run_logout $'y\n'
_lo_expect "accepting_confirmation_proceeds" 0 \
  "Are you sure you want to log out?" "Logging out from macOS..." "osascript:"

# =======================================================================
# 3. macOS: AppleScript success and failure.
# =======================================================================
_lo_scenario darwin_ok
_lo_uname Darwin
_lo_shim osascript <<'EOF'
#!/usr/bin/env bash
echo "osascript ran: $*"
exit 0
EOF
_run_logout "" --force
_lo_expect "macos_force_logout_succeeds" 0 \
  "Logging out from macOS..." "osascript ran:" "tell application \"System Events\" to log out"

_lo_scenario darwin_fail
_lo_uname Darwin
_lo_shim osascript <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
_run_logout "" --force
_lo_expect "macos_applescript_failure_returns_1" 1 \
  "Failed to log out using AppleScript"

# =======================================================================
# 4. Linux: gnome-session-quit, then loginctl, then neither.
# =======================================================================
_lo_scenario linux_gnome
_lo_uname Linux
_lo_shim gnome-session-quit <<'EOF'
#!/usr/bin/env bash
echo "gnome-session-quit: $*"
exit 0
EOF
_lo_shim loginctl <<'EOF'
#!/usr/bin/env bash
echo "loginctl should not run"
exit 0
EOF
_run_logout "" --force
_lo_expect "linux_prefers_gnome_session_quit" 0 \
  "Logging out from Linux..." "gnome-session-quit: --logout --no-prompt" \
  "NOT:loginctl should not run"

_lo_scenario linux_loginctl
_lo_uname Linux
_lo_shim loginctl <<'EOF'
#!/usr/bin/env bash
echo "loginctl: $*"
exit 0
EOF
_run_logout "" --force
_lo_expect "linux_falls_back_to_loginctl" 0 \
  "Logging out from Linux..." "loginctl: terminate-user fixtureuser"

_lo_scenario linux_bare
_lo_uname Linux
_run_logout "" --force
_lo_expect "linux_without_a_logout_method_returns_1" 1 \
  "Unable to determine logout method for your Linux system"

# =======================================================================
# 5. Windows shells: shutdown /l, success and failure.
# =======================================================================
_lo_scenario msys_ok
_lo_uname MSYS
_lo_shim shutdown <<'EOF'
#!/usr/bin/env bash
echo "shutdown: $*"
exit 0
EOF
_run_logout "" --force
_lo_expect "windows_msys_logout_succeeds" 0 "Logging out from Windows..." "shutdown: /l"

_lo_scenario cygwin_fail
_lo_uname CYGWIN
_lo_shim shutdown <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
_run_logout "" --force
_lo_expect "windows_logout_failure_returns_1" 1 "Failed to log out from Windows"

_lo_scenario mingw_ok
_lo_uname MINGW64
_lo_shim shutdown <<'EOF'
#!/usr/bin/env bash
echo "shutdown: $*"
exit 0
EOF
_run_logout "" --force
_lo_expect "windows_mingw_prefix_matches" 0 "Logging out from Windows..."

# =======================================================================
# 6. Unsupported platform.
# =======================================================================
_lo_scenario freebsd
_lo_uname FreeBSD
_run_logout "" --force
_lo_expect "unsupported_platform_returns_1" 1 "Unsupported operating system: freebsd"

# =======================================================================
# 7. The fallback log_* definitions, used when the shared logging library
#    is not a sibling of the sourced file.
# =======================================================================
_lo_scenario fallback
_lo_uname FreeBSD
ORPHAN_DIR="$TMP/lo-orphan"
mkdir -p "$ORPHAN_DIR"
cp "$LOGOUT_FILE" "$ORPHAN_DIR/logout.sh"
LOGOUT_SOURCE="$ORPHAN_DIR/logout.sh"
_run_logout "" --force
LOGOUT_SOURCE="$LOGOUT_FILE"
_lo_expect "fallback_logging_used_without_shared_library" 1 \
  "[ERROR] Unsupported operating system: freebsd"

# log_warning has no caller inside logout(), so exercise the fallback
# definition directly.
test_start "fallback_log_warning_writes_to_stderr"
_warn_out="$(
  env BASH_XTRACEFD=21 PATH="$LO_BIN:$SYSBIN" HOME="$TMP/lo-home" \
    "$BASH" -c 'source "$1"; log_warning "disk almost full"' _ \
    "$ORPHAN_DIR/logout.sh" 2>&1 >/dev/null
)" || true
assert_contains "[WARNING] disk almost full" "$_warn_out" \
  "the fallback log_warning must write a [WARNING] line to stderr"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
