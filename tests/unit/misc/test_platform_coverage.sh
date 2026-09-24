#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Behavioural coverage for lib/dot/platform.sh across every platform arm:
# uname, grep, wslpath, wslview, explorer.exe, xdg-open and open are
# PATH-shadowed recording stubs, so each OS branch runs on any host and
# nothing is actually opened.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

LIB="$REPO_ROOT/lib/dot/platform.sh"
REAL_BASH="${BASH:-$(command -v bash)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/platform-cov.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
BIN="$WORK/bin"
WSLBIN="$WORK/wslbin"
WSLPATH_ONLY="$WORK/wslpathonly"
mkdir -p "$BIN" "$WSLBIN" "$WSLPATH_ONLY"
CALLS="$WORK/calls"

cat >"$BIN/uname" <<EOF
#!$REAL_BASH
echo "\${FAKE_UNAME:-Linux}"
EOF
# grep stub: answers the WSL osrelease probe from FAKE_WSL, else real grep.
cat >"$BIN/grep" <<EOF
#!$REAL_BASH
if [[ "\$*" == *osrelease* ]]; then
  [[ "\${FAKE_WSL:-0}" == 1 ]]
  exit
fi
exec /usr/bin/grep "\$@"
EOF
for c in xdg-open open explorer.exe; do
  cat >"$BIN/$c" <<EOF
#!$REAL_BASH
echo "$c \$*" >>"$CALLS"
EOF
done
cat >"$WSLBIN/wslpath" <<EOF
#!$REAL_BASH
echo "wslpath:\$1:\$2"
EOF
cat >"$WSLBIN/wslview" <<EOF
#!$REAL_BASH
echo "wslview \$*" >>"$CALLS"
EOF
chmod +x "$BIN"/* "$WSLBIN"/*
cp "$WSLBIN/wslpath" "$WSLPATH_ONLY/wslpath"

# run <extra-path> <snippet> [env...] — source platform.sh with stubs first.
run() {
  local extra="$1" snippet="$2"
  PATH="$extra$BIN:/usr/bin:/bin" "$REAL_BASH" -c "source '$LIB'; set +e; $snippet" 2>&1
}

test_start "platform_id_every_uname"
assert_equals "macos" "$(FAKE_UNAME=Darwin run "" dot_platform_id)" "Darwin"
assert_equals "linux" "$(FAKE_UNAME=Linux run "" '_DOT_IS_WSL=1; dot_platform_id')" "Linux"
assert_equals "wsl" "$(FAKE_UNAME=Linux run "" '_DOT_IS_WSL=0; dot_platform_id')" "Linux under WSL"
assert_equals "bsd" "$(FAKE_UNAME=FreeBSD run "" dot_platform_id)" "FreeBSD"
assert_equals "unknown" "$(FAKE_UNAME=Plan9 run "" dot_platform_id)" "unknown"
assert_equals $'macos\nmacos' "$(FAKE_UNAME=Darwin run "" 'dot_platform_id; FAKE_UNAME=Linux dot_platform_id')" "memoised"

test_start "host_os_every_uname"
assert_equals "windows" "$(run "" '_DOT_IS_WSL=0; dot_host_os')" "WSL host is windows"
assert_equals "macos" "$(FAKE_UNAME=Darwin run "" '_DOT_IS_WSL=1; dot_host_os')" "Darwin"
assert_equals "linux" "$(FAKE_UNAME=Linux run "" '_DOT_IS_WSL=1; dot_host_os')" "Linux"
assert_equals "bsd" "$(FAKE_UNAME=NetBSD run "" '_DOT_IS_WSL=1; dot_host_os')" "NetBSD"
assert_equals "unknown" "$(FAKE_UNAME=Haiku run "" '_DOT_IS_WSL=1; dot_host_os')" "unknown"
assert_equals $'linux\nlinux' "$(run "" '_DOT_IS_WSL=1; dot_host_os; _DOT_IS_WSL=0; dot_host_os')" "memoised"

test_start "is_wsl_osrelease_probe"
if [[ -f /proc/sys/kernel/osrelease ]]; then
  assert_equals "0" "$(FAKE_WSL=1 run "" 'dot_is_wsl; echo $?')" "microsoft kernel detected"
  assert_equals "1" "$(FAKE_WSL=0 run "" 'dot_is_wsl; echo $?')" "plain kernel"
else
  assert_equals "1" "$(run "" 'dot_is_wsl; echo $?')" "no /proc means not WSL"
fi
assert_equals "0" "$(run "" '_DOT_IS_WSL=0; dot_is_wsl; echo $?')" "cached answer reused"
assert_equals "kept" "$(run "" 'dot_is_wsl(){ echo kept; }; source "'"$LIB"'"; dot_is_wsl')" "existing dot_is_wsl not overridden"

test_start "path_conversion"
assert_equals "1" "$(run "" 'dot_path_to_unix; echo $?')" "empty unix path"
assert_equals "1" "$(run "" 'dot_path_to_native; echo $?')" "empty native path"
assert_equals "/a/b" "$(run "" '_DOT_IS_WSL=1; dot_path_to_unix /a/b')" "non-WSL unix passthrough"
assert_equals "/a/b" "$(run "" '_DOT_IS_WSL=1; dot_path_to_native /a/b')" "non-WSL native passthrough"
assert_equals "wslpath:-u:C:\\x" "$(run "$WSLBIN:" '_DOT_IS_WSL=0; dot_path_to_unix "C:\\x"')" "WSL unix via wslpath"
assert_equals "wslpath:-w:/mnt/c" "$(run "$WSLBIN:" '_DOT_IS_WSL=0; dot_path_to_native /mnt/c')" "WSL native via wslpath"
out="$(run "" '_DOT_IS_WSL=0; dot_path_to_unix x; echo rc=$?')"
assert_contains "wslpath required" "$out" "unix: missing wslpath reported"
assert_contains "rc=2" "$out" "unix: rc 2"
out="$(run "" '_DOT_IS_WSL=0; dot_path_to_native x; echo rc=$?')"
assert_contains "dot_path_to_native: wslpath required" "$out" "native: missing wslpath reported"
assert_contains "rc=2" "$out" "native: rc 2"

test_start "open_path_every_platform"
: >"$CALLS"
assert_equals "1" "$(run "" 'dot_open_path; echo $?')" "empty target"
run "" '_DOT_PLATFORM_ID=macos; dot_open_path /m' >/dev/null
run "$WSLBIN:" '_DOT_PLATFORM_ID=wsl; dot_open_path /w1' >/dev/null
run "$WSLPATH_ONLY:" '_DOT_PLATFORM_ID=wsl; _DOT_IS_WSL=0; dot_open_path /w2' >/dev/null
run "" '_DOT_PLATFORM_ID=linux; dot_open_path /l' >/dev/null
run "" '_DOT_PLATFORM_ID=bsd; dot_open_path /b' >/dev/null
assert_file_contains "$CALLS" "open /m" "macOS uses open"
assert_file_contains "$CALLS" "wslview /w1" "WSL prefers wslview"
assert_file_contains "$CALLS" "explorer.exe wslpath:-w:/w2" "WSL without wslview uses explorer.exe on the native path"
assert_file_contains "$CALLS" "xdg-open /l" "Linux uses xdg-open"
assert_file_contains "$CALLS" "xdg-open /b" "BSD uses xdg-open"
assert_equals "1" "$(run "" '_DOT_PLATFORM_ID=unknown; dot_open_path /u; echo $?')" "unknown platform fails"

test_start "require_platform"
assert_equals "ok" "$(run "" '_DOT_PLATFORM_ID=linux; dot_require_platform macos linux; echo ok')" "allowed platform passes"
out="$(run "" '_DOT_PLATFORM_ID=bsd; dot_require_platform macos linux; echo not-reached')"
assert_contains "requires macos linux (detected: bsd)" "$out" "disallowed platform explained"
assert_output_not_contains "not-reached" "printf '%s' '$out'"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
