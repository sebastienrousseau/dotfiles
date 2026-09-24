#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for hiddenfiles: the macOS guard, help, hide/show and
# the invalid-argument arm. `uname`, `defaults`, `osascript` and `sleep`
# are PATH stubs that record their argv, so Finder is never touched.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/files/hiddenfiles.sh"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/hiddenfiles-cov.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME" "$SANDBOX/bin"
LOG="$SANDBOX/calls.log"
: >"$LOG"

for cmd in defaults osascript sleep; do
  cat >"$SANDBOX/bin/$cmd" <<STUB
#!/usr/bin/env bash
printf '%s %s\n' "$cmd" "\$*" >>"$LOG"
STUB
  chmod +x "$SANDBOX/bin/$cmd"
done
cat >"$SANDBOX/bin/uname" <<'STUB'
#!/usr/bin/env bash
echo "${FAKE_UNAME:-Darwin}"
STUB
chmod +x "$SANDBOX/bin/uname"
export PATH="$SANDBOX/bin:$PATH"

source "$FUNC_FILE"

test_start "non_darwin_refused"
out="$(FAKE_UNAME=Linux hiddenfiles show 2>&1)"
rc=$?
assert_equals "1" "$rc" "returns 1 off macOS"
assert_contains "macOS only" "$out" "prints macOS only"

export FAKE_UNAME=Darwin

test_start "help"
out="$(hiddenfiles --help 2>&1)"
rc=$?
assert_equals "0" "$rc" "help returns 0"
assert_contains "Hidden Files Visibility Toggle" "$out" "help banner"
assert_contains "hiddenfiles show" "$out" "help examples"

test_start "default_hides"
: >"$LOG"
out="$(hiddenfiles 2>&1)"
rc=$?
assert_equals "0" "$rc" "default returns 0"
assert_contains "Hiding hidden files" "$out" "hide message"
assert_contains "Finder settings updated successfully" "$out" "success message"
assert_contains "defaults write com.apple.Finder AppleShowAllFiles NO" "$(cat "$LOG")" "writes NO"
assert_contains 'osascript -e tell application "Finder" to quit' "$(cat "$LOG")" "quits Finder"
assert_contains 'osascript -e tell application "Finder" to activate' "$(cat "$LOG")" "relaunches Finder"
assert_contains "sleep 0.25" "$(cat "$LOG")" "waits between quit and activate"

test_start "show"
: >"$LOG"
out="$(hiddenfiles show 2>&1)"
rc=$?
assert_equals "0" "$rc" "show returns 0"
assert_contains "Showing hidden files" "$out" "show message"
assert_contains "defaults write com.apple.Finder AppleShowAllFiles YES" "$(cat "$LOG")" "writes YES"

test_start "invalid_argument"
: >"$LOG"
out="$(hiddenfiles bogus 2>&1)"
rc=$?
assert_equals "1" "$rc" "invalid returns 1"
assert_contains "Invalid argument: 'bogus'" "$out" "names the bad argument"
assert_equals "" "$(cat "$LOG")" "no defaults/osascript call on invalid argument"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
