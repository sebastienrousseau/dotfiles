#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Branch coverage for scripts/security/check-disclosure-key-expiry.sh
# with a deterministic `gpg` shim. The sibling test
# (test_check_disclosure_key_expiry.sh) only exercises the real gpg
# when available; this one drives every exit path — missing key
# file, gpg absent, import failure, no expiry, warn window, fail
# window, healthy — without touching a real keyring or the network.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Route child xtrace to the runner's trace stream even when a probe
# captures 2>&1 or discards stderr (fd 19: fd 9 is taken by the lock
# handling in several ops scripts).
exec 21>&2
export BASH_XTRACEFD=21

SCRIPT_FILE="$REPO_ROOT/scripts/security/check-disclosure-key-expiry.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# ── gpg shim ──────────────────────────────────────────────────────────
# Overrides the sandbox no-op shim. Import writes the `imported: N`
# marker the script greps for (or not, when GPG_SHIM_IMPORT_FAIL=1);
# --with-colons prints a `pub:` record whose field 7 is the expiry
# taken from GPG_SHIM_EXPIRES (0 = no expiry).
cat >"$DOTFILES_COV_TMPDIR/bin/gpg" <<'SHIM'
#!/usr/bin/env bash
case "$*" in
  *--import*)
    if [[ "${GPG_SHIM_IMPORT_FAIL:-0}" == "1" ]]; then
      echo "gpg: no valid OpenPGP data found." >&2
    else
      echo "gpg: key 0123456789ABCDEF: public key imported" >&2
      echo "gpg: Total number processed: 1" >&2
      echo "gpg: imported: 1" >&2
    fi
    exit 0
    ;;
  *--with-colons*)
    printf 'tru::1:1700000000:0:3:1:5\n'
    printf 'pub:u:255:22:0123456789ABCDEF:1700000000:%s::u:::scESC::::::23::0:\n' \
      "${GPG_SHIM_EXPIRES:-0}"
    exit 0
    ;;
  *) exit 0 ;;
esac
SHIM
chmod +x "$DOTFILES_COV_TMPDIR/bin/gpg"

_now="$(date -u +%s)"
_days_from_now() { printf '%s\n' "$((_now + $1 * 86400))"; }

test_start "help_prints_usage_and_exits_zero"
_out="$("$BASH_BIN" "$SCRIPT_FILE" --help 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "--help exits 0"
assert_contains "check-disclosure-key-expiry" "$_out" "help mentions the script name"

test_start "unknown_flag_exits_2"
_out="$("$BASH_BIN" "$SCRIPT_FILE" --nope 2>&1)"
_rc=$?
assert_equals 2 "$_rc" "unknown flag exits 2"
assert_contains "Unknown arg: --nope" "$_out" "unknown flag is named"

# Missing key file: symlink the script into a fixture tree so its
# BASH_SOURCE-relative REPO_ROOT has no docs/security/security-pubkey.asc.
test_start "missing_public_key_exits_2"
_fixture="$DOTFILES_COV_TMPDIR/nokey"
mkdir -p "$_fixture/scripts/security"
ln -s "$SCRIPT_FILE" "$_fixture/scripts/security/check-disclosure-key-expiry.sh"
_out="$("$BASH_BIN" "$_fixture/scripts/security/check-disclosure-key-expiry.sh" 2>&1)"
_rc=$?
assert_equals 2 "$_rc" "missing .asc exits 2"
assert_contains "::error::no public key" "$_out" "missing .asc is reported"

# gpg absent: a PATH that carries every tool the script needs except gpg.
test_start "gpg_missing_warns_and_exits_0"
_nogpg="$DOTFILES_COV_TMPDIR/nogpg"
mkdir -p "$_nogpg"
for _t in dirname mktemp chmod grep awk date cat rm sed; do
  _p="$(command -v "$_t" 2>/dev/null || true)"
  [[ -n "$_p" ]] && ln -sf "$_p" "$_nogpg/$_t"
done
_out="$(PATH="$_nogpg" "$BASH_BIN" "$SCRIPT_FILE" 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "no gpg exits 0"
assert_contains "gpg not installed" "$_out" "no-gpg warning printed"

test_start "import_failure_exits_2"
_out="$(GPG_SHIM_IMPORT_FAIL=1 "$BASH_BIN" "$SCRIPT_FILE" 2>&1)"
_rc=$?
assert_equals 2 "$_rc" "failed import exits 2"
assert_contains "gpg import failed" "$_out" "import failure reported"
assert_contains "no valid OpenPGP data" "$_out" "import.err is echoed"

test_start "no_expiry_warns_and_exits_0"
_out="$(GPG_SHIM_EXPIRES=0 "$BASH_BIN" "$SCRIPT_FILE" 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "no-expiry key exits 0"
assert_contains "has no expiry" "$_out" "no-expiry warning printed"

test_start "expiry_inside_fail_window_exits_1"
_out="$(GPG_SHIM_EXPIRES="$(_days_from_now 10)" "$BASH_BIN" "$SCRIPT_FILE" --fail-days 30 --warn-days 90 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "inside fail window exits 1"
assert_contains "::error::Disclosure key expires in" "$_out" "fail annotation printed"
assert_contains "fail threshold: 30 days" "$_out" "fail threshold echoed"

test_start "expiry_inside_warn_window_exits_0_with_warning"
_out="$(GPG_SHIM_EXPIRES="$(_days_from_now 60)" "$BASH_BIN" "$SCRIPT_FILE" --warn-days 90 --fail-days 30 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "inside warn window exits 0"
assert_contains "::warning::Disclosure key expires in" "$_out" "warn annotation printed"
assert_contains "warn threshold: 90 days" "$_out" "warn threshold echoed"

test_start "healthy_expiry_exits_0_without_annotations"
_out="$(GPG_SHIM_EXPIRES="$(_days_from_now 400)" "$BASH_BIN" "$SCRIPT_FILE" 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "healthy key exits 0"
assert_contains "Disclosure key expires:" "$_out" "expiry summary printed"
if [[ "$_out" != *"::warning::"* && "$_out" != *"::error::"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: no annotations"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: unexpected annotation in: $_out"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
