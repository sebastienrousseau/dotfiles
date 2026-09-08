#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Branch coverage for scripts/security/dns-doh.sh. The platform is
# pinned through _DOT_PLATFORM_ID and `resolvectl` / `sudo` are PATH
# shims, so the systemd-resolved arm runs (dry-run and apply) without
# changing any resolver on the host.
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

SCRIPT_FILE="$REPO_ROOT/scripts/security/dns-doh.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

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

# resolvectl + sudo shims that record their argv so the apply path
# can be asserted without touching systemd-resolved.
_sysd="$DOTFILES_COV_TMPDIR/sysd"
mkdir -p "$_sysd"
cat >"$_sysd/resolvectl" <<'SHIM'
#!/usr/bin/env bash
printf 'resolvectl %s\n' "$*" >>"${DOH_SHIM_LOG:?}"
SHIM
cat >"$_sysd/sudo" <<'SHIM'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"${DOH_SHIM_LOG:?}"
exec "$@"
SHIM
chmod +x "$_sysd/resolvectl" "$_sysd/sudo"
export DOH_SHIM_LOG="$DOTFILES_COV_TMPDIR/doh.log"

_run() { # <platform> <path> [args]
  local platform="$1" path="$2"
  shift 2
  _DOT_PLATFORM_ID="$platform" PATH="$path" "$BASH_BIN" "$SCRIPT_FILE" "$@" 2>&1
}

test_start "disabled_by_default_exits_1"
_out="$(DOTFILES_DOH='' _run linux "$_sysd:$_base")"
_rc=$?
assert_equals 1 "$_rc" "opt-in gate exits 1"
assert_contains "disabled by default" "$_out" "opt-in hint printed"
assert_contains "DOTFILES_DOH=1" "$_out" "re-run hint printed"

test_start "dry_run_linux_prints_planned_commands"
: >"$DOH_SHIM_LOG"
_out="$(_run linux "$_sysd:$_base" --dry-run)"
_rc=$?
assert_equals 0 "$_rc" "dry-run exits 0"
assert_contains "dry-run (no changes will be made)" "$_out" "dry-run mode announced"
assert_contains "sudo resolvectl dns-over-https on" "$_out" "planned command printed"
assert_equals "" "$(cat "$DOH_SHIM_LOG")" "dry-run never invokes resolvectl"

test_start "apply_linux_runs_resolvectl_through_sudo"
: >"$DOH_SHIM_LOG"
_out="$(DOTFILES_DOH=1 _run linux "$_sysd:$_base")"
_rc=$?
assert_equals 0 "$_rc" "apply exits 0"
assert_contains "systemd-resolved DoH" "$_out" "enable message printed"
assert_contains "sudo resolvectl dns-over-https on" "$(cat "$DOH_SHIM_LOG")" "DoH toggled via sudo"
assert_contains "resolvectl dns 1.1.1.1 1.0.0.1" "$(cat "$DOH_SHIM_LOG")" "resolvers set via sudo"

test_start "apply_wsl_without_resolvectl_exits_1"
_out="$(DOTFILES_DOH=1 _run wsl "$_base")"
_rc=$?
assert_equals 1 "$_rc" "missing resolvectl exits 1"
assert_contains "systemd-resolved" "$_out" "resolved not detected reported"

test_start "macos_points_at_browser_exits_0"
_out="$(DOTFILES_DOH=1 _run macos "$_base")"
_rc=$?
assert_equals 0 "$_rc" "macos exits 0"
assert_contains "DoH in your browser" "$_out" "browser hint printed"

test_start "unsupported_platform_exits_1"
_out="$(DOTFILES_DOH=1 _run bsd "$_base")"
_rc=$?
assert_equals 1 "$_rc" "unsupported platform exits 1"
assert_contains "Unsupported OS" "$_out" "unsupported platform reported"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
