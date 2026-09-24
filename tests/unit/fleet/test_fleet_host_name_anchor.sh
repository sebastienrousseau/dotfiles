#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# `dot fleet apply` validates every host NAME against ^[a-zA-Z0-9._-]+$
# before any SSH fan-out (the name becomes a temp-file name and is echoed
# into ui output). The mutation gate found the start anchor unprotected:
# with `^` dropped, any name that merely ENDS in a valid run (for example
# `evil;rm -rf x`) was accepted, because the only other guard is the
# leading-'.' check. Pinned here:
#   - a name with shell metacharacters before a valid tail is refused
#     (exit 1, "invalid host name", ssh never invoked)
#   - a name with an embedded space is refused the same way
#   - a fully valid name still fans out (control: the validator is not
#     simply rejecting everything)
# ssh is a recording stub; HOME/TMPDIR are sandboxed; nothing reaches the
# network.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_BIN="$REPO_ROOT/bin/dot"

WORK="$(mktemp -d -t fleet-name-anchor.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stubs" "$WORK/home" "$WORK/tmp"

cat >"$WORK/stubs/ssh" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$WORK/ssh.log"
exit 0
STUB
chmod +x "$WORK/stubs/ssh"

fleet() { # fleet <toml> args...
  local toml="$1"
  shift
  printf '%s' "$toml" >"$WORK/fleet.toml"
  rm -f "$WORK/ssh.log"
  FL_OUT="$(HOME="$WORK/home" TMPDIR="$WORK/tmp" DOTFILES_FLEET_HOSTS="$WORK/fleet.toml" \
    PATH="$WORK/stubs:$PATH" perl -e 'alarm 20; exec @ARGV' \
    bash "$DOT_BIN" fleet apply "$@" 2>&1 </dev/null)"
  FL_RC=$?
}

test_start "fleet_rejects_host_name_with_junk_before_valid_tail"
fleet '[hosts.evil;rm -rf x]
ssh = "user@alpha.test"
' --cmd true
assert_equals "1" "$FL_RC" "a name with metacharacters before a valid tail is refused"
assert_contains "invalid host name" "$FL_OUT" "the refusal names the host-name rule"
assert_file_not_exists "$WORK/ssh.log" "ssh is never invoked for the refused name"

test_start "fleet_rejects_host_name_with_embedded_space"
fleet '[hosts.bad host]
ssh = "user@alpha.test"
' --cmd true
assert_equals "1" "$FL_RC" "a name with an embedded space is refused"
assert_contains "invalid host name" "$FL_OUT" "the refusal names the host-name rule"
assert_file_not_exists "$WORK/ssh.log" "ssh is never invoked for the refused name"

test_start "fleet_accepts_fully_valid_host_name"
fleet '[hosts.alpha-1.test_x]
ssh = "user@alpha.test"
' --cmd true
assert_equals "0" "$FL_RC" "a name made only of [a-zA-Z0-9._-] is accepted"
assert_contains "-- user@alpha.test true" "$(cat "$WORK/ssh.log" 2>/dev/null)" \
  "the accepted host is applied over ssh"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
