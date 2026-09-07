#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Branch coverage for scripts/security/encryption-check.sh. The
# platform is pinned through _DOT_PLATFORM_ID (honoured by
# lib/dot/platform.sh) and the probes (`fdesetup`, `lsblk`, `rg`)
# are PATH shims, so every arm of the case statement runs on any
# host without reading real disk-encryption state.
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

SCRIPT_FILE="$REPO_ROOT/scripts/security/encryption-check.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# A PATH that carries only the tools ui.sh/platform.sh need, plus
# whatever shim a case adds. Lets a test remove `fdesetup`, `rg` or
# `lsblk` from view on hosts that ship them.
_link_real_tools() {
  local dir="$1" t p
  shift
  for t in "$@"; do
    p="$(command -v "$t" 2>/dev/null || true)"
    [[ -n "$p" ]] && ln -sf "$p" "$dir/$t"
  done
}
_base="$DOTFILES_COV_TMPDIR/base"
mkdir -p "$_base"
_link_real_tools "$_base" bash dirname uname tput cat grep sed awk head tr mkdir date

_mk_shim() { # <dir> <name> <body>
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\n%s\n' "$3" >"$1/$2"
  chmod +x "$1/$2"
}

_run() { # <platform> <path> [args]
  local platform="$1" path="$2"
  shift 2
  _DOT_PLATFORM_ID="$platform" PATH="$path" "$BASH_BIN" "$SCRIPT_FILE" "$@" 2>&1
}

test_start "macos_filevault_on_exits_0"
_d="$DOTFILES_COV_TMPDIR/fv-on"
_mk_shim "$_d" fdesetup 'echo "FileVault is On."'
_out="$(_run macos "$_d:$_base")"
_rc=$?
assert_equals 0 "$_rc" "FileVault on exits 0"
assert_contains "FileVault is On" "$_out" "fdesetup status echoed"

test_start "macos_filevault_off_exits_1"
_d="$DOTFILES_COV_TMPDIR/fv-off"
_mk_shim "$_d" fdesetup 'echo "FileVault is Off."'
_out="$(_run macos "$_d:$_base")"
_rc=$?
assert_equals 1 "$_rc" "FileVault off exits 1"
assert_contains "appears to be off" "$_out" "off warning printed"

test_start "macos_without_fdesetup_exits_1"
_out="$(_run macos "$_base")"
_rc=$?
assert_equals 1 "$_rc" "no fdesetup exits 1"
assert_contains "not found" "$_out" "missing fdesetup reported"

test_start "linux_luks_detected_via_rg_exits_0"
_d="$DOTFILES_COV_TMPDIR/luks-rg"
_mk_shim "$_d" lsblk 'printf "NAME FSTYPE\nsda1 crypto_LUKS\n"'
_mk_shim "$_d" rg 'exec grep -Ei "${@: -1}"'
_out="$(_run linux "$_d:$_base")"
_rc=$?
assert_equals 0 "$_rc" "LUKS via rg exits 0"
assert_contains "encrypted block device detected" "$_out" "LUKS reported"

test_start "linux_luks_detected_via_grep_exits_0"
_d="$DOTFILES_COV_TMPDIR/luks-grep"
_mk_shim "$_d" lsblk 'printf "NAME FSTYPE\nnvme0n1p2 crypto_LUKS\n"'
_out="$(_run wsl "$_d:$_base")"
_rc=$?
assert_equals 0 "$_rc" "LUKS via grep exits 0"
assert_contains "encrypted block device detected" "$_out" "LUKS reported without rg"

test_start "linux_no_crypto_volume_exits_1"
_d="$DOTFILES_COV_TMPDIR/nocrypto"
_mk_shim "$_d" lsblk 'printf "NAME FSTYPE\nsda1 ext4\n"'
_mk_shim "$_d" rg 'exec grep -Ei "${@: -1}"'
_out="$(_run linux "$_d:$_base")"
_rc=$?
assert_equals 1 "$_rc" "no crypto volume exits 1"
assert_contains "no crypto volume detected" "$_out" "warning printed"

test_start "linux_without_lsblk_falls_through_exit_0"
_out="$(_run linux "$_base")"
_rc=$?
assert_equals 0 "$_rc" "no lsblk falls through the case with rc 0"
assert_contains "Encryption Check" "$_out" "header still printed"

test_start "unsupported_platform_exits_1"
_out="$(_run bsd "$_base")"
_rc=$?
assert_equals 1 "$_rc" "unsupported platform exits 1"
assert_contains "Unsupported OS" "$_out" "unsupported platform reported"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
