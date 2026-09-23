#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for hostinfo: help, the macOS-only probes (scselect,
# scutil), the curl and wget public-IP fallbacks and the "Not available"
# defaults. Lists are joined with ", " (regression: `paste -sd ", "`
# cycles its delimiters and produced "a,b c" for three items). Every network/system probe is a PATH stub; no request leaves
# the host. A scoped `command` wrapper hides individual tools per case.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/system/hostinfo.sh"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/hostinfo-cov.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME" "$SANDBOX/bin"

_stub() {
  local name="$1" body="$2"
  printf '#!/usr/bin/env bash\n%s\n' "$body" >"$SANDBOX/bin/$name"
  chmod +x "$SANDBOX/bin/$name"
}
_stub whoami 'echo tester'
_stub hostname 'echo box.local'
_stub w 'printf "alice tty1\nbob tty2\nalice tty3\ncarol tty4\n"'
_stub uptime 'echo "  10:00  up 3 days, 2 users"'
_stub scselect 'printf "Defined sets include: (* = currently active)\n * ABCD (Home)\n   EFGH (Work)\n"'
_stub scutil 'printf "resolver #1\n  nameserver[0] : 1.1.1.1\n  nameserver[1] : 9.9.9.9\n  nameserver[2] : 8.8.8.8\n"'
_stub curl 'echo 203.0.113.7'
_stub wget 'echo 198.51.100.9'
export PATH="$SANDBOX/bin:$PATH"

source "$FUNC_FILE"

test_start "help"
out="$(hostinfo --help 2>&1)"
assert_equals "0" "$?" "help returns 0"
assert_contains "Host Information Viewer" "$out" "help banner"

test_start "all_probes_available"
out="$(hostinfo 2>&1)"
assert_equals "0" "$?" "returns 0"
assert_contains "tester" "$out" "username"
assert_contains "box.local" "$out" "hostname"
assert_contains "alice, bob, carol" "$out" "deduplicated users"
assert_contains "up 3 days" "$out" "uptime stats"
assert_contains "ABCD (Home)" "$out" "network location from scselect"
assert_contains "203.0.113.7" "$out" "public IP via curl"
assert_contains "1.1.1.1, 9.9.9.9, 8.8.8.8" "$out" "DNS from scutil"

test_start "wget_fallback_and_no_macos_tools"
out="$(
  command() {
    if [[ "${1:-}" == "-v" ]]; then
      case "${2:-}" in curl | scselect | scutil) return 1 ;; esac
    fi
    builtin command "$@"
  }
  hostinfo 2>&1
)"
assert_equals "0" "$?" "returns 0"
assert_contains "198.51.100.9" "$out" "public IP via wget"
assert_contains "Not available" "$out" "network location default"

test_start "no_http_client"
out="$(
  command() {
    if [[ "${1:-}" == "-v" ]]; then
      case "${2:-}" in curl | wget) return 1 ;; esac
    fi
    builtin command "$@"
  }
  hostinfo 2>&1
)"
assert_equals "0" "$?" "returns 0"
assert_true "[[ \"\$(printf '%s\n' \"\$out\" | grep 'Public IP')\" == *'Not available'* ]]" "public IP not available"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
