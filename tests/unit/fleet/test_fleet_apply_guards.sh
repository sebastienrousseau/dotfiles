#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Input guards for `dot fleet apply`:
#   - --jobs must be a positive integer (0 used to spin forever)
#   - an ssh target may not start with '-' (parsed as an ssh option)
#   - host names become temp-file names, so no path separators
#   - ssh gets `--` before the target and keep-alive options
# No case opens a network connection: ssh is a recording stub.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DOT_BIN="$REPO_ROOT/bin/dot"

WORK="$(mktemp -d -t fleet-guards.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stubs" "$WORK/home"

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
  mkdir -p "$WORK/tmp"
  FL_OUT="$(HOME="$WORK/home" TMPDIR="$WORK/tmp" DOTFILES_FLEET_HOSTS="$WORK/fleet.toml" \
    PATH="$WORK/stubs:$PATH" perl -e 'alarm 20; exec @ARGV' \
    bash "$DOT_BIN" fleet apply "$@" 2>&1 </dev/null)"
  FL_RC=$?
}

GOOD='[hosts.alpha]
ssh = "user@alpha.test"
'

test_start "fleet_jobs_zero_rejected"
fleet "$GOOD" --jobs 0 --cmd true
assert_equals "2" "$FL_RC" "--jobs 0 is a usage error, not a hang"

test_start "fleet_jobs_non_numeric_rejected"
fleet "$GOOD" --jobs many --cmd true
assert_equals "2" "$FL_RC" "--jobs many is a usage error"

test_start "fleet_jobs_error_names_flag"
assert_contains "--jobs" "$FL_OUT" "the error names the flag"

test_start "fleet_jobs_valid_runs"
fleet "$GOOD" --jobs 2 --cmd true
assert_equals "0" "$FL_RC" "--jobs 2 applies normally"

test_start "fleet_ssh_gets_option_terminator"
assert_contains "-- user@alpha.test true" "$(cat "$WORK/ssh.log" 2>/dev/null)" \
  "ssh receives -- before the target"

test_start "fleet_ssh_keepalive"
assert_contains "ServerAliveInterval=" "$(cat "$WORK/ssh.log" 2>/dev/null)" \
  "a hung remote is detected by keep-alives"

test_start "fleet_rejects_option_like_target"
fleet '[hosts.evil]
ssh = "-F/nonexistent"
' --cmd true
assert_equals "1" "$FL_RC" "a target starting with - is refused"
test_start "fleet_option_like_target_never_ssh"
assert_file_not_exists "$WORK/ssh.log" "ssh is never invoked for a refused target"

test_start "fleet_rejects_path_like_host_name"
fleet '[hosts.../victim]
ssh = "user@alpha.test"
' --cmd true
assert_equals "1" "$FL_RC" "a host name with / is refused"
test_start "fleet_path_like_name_writes_nothing_outside"
assert_file_not_exists "$WORK/tmp/victim.out" "output never escapes the fleet temp dir"
test_start "fleet_path_like_name_never_ssh"
assert_file_not_exists "$WORK/ssh.log" "ssh is never invoked for a refused name"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
