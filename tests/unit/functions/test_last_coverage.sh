#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for last/detect_tool: help, input validation, the find
# path, the fd fallback and the no-tool arm. `command -v /usr/bin/find`
# cannot be hidden via PATH, so a scoped `command` wrapper hides it.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/misc/last.sh"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/last-cov.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME" "$SANDBOX/bin" "$SANDBOX/tree/sub"
cat >"$SANDBOX/bin/fd" <<'STUB'
#!/usr/bin/env bash
echo "fd-stub $*"
STUB
chmod +x "$SANDBOX/bin/fd"
: >"$SANDBOX/tree/sub/fresh.txt"
cd "$SANDBOX/tree" || exit 1

source "$FUNC_FILE"

test_start "help"
out="$(last --help 2>&1)"
assert_equals "0" "$?" "help returns 0"
assert_contains "Recently Modified Files Viewer" "$out" "help banner"

test_start "invalid_minutes"
out="$(last abc 2>&1)"
assert_equals "1" "$?" "non-numeric returns 1"
assert_contains "Invalid input: 'abc'" "$out" "invalid message"

test_start "too_large"
out="$(last 10081 2>&1)"
assert_equals "1" "$?" "over 7 days returns 1"
assert_contains "Time range too large" "$out" "range message"

test_start "find_path"
if [[ -x /usr/bin/find ]]; then
  out="$(last 5 2>&1)"
  assert_equals "0" "$?" "find path returns 0"
  assert_contains "using find" "$out" "uses find"
  assert_contains "./sub/fresh.txt" "$out" "lists the fresh file"
else
  assert_true "true" "skipped: no /usr/bin/find on this host"
fi

test_start "fd_fallback"
out="$(
  PATH="$SANDBOX/bin:$PATH"
  command() {
    [[ "${1:-}" == "-v" && "${2:-}" == "/usr/bin/find" ]] && return 1
    builtin command "$@"
  }
  last 30 2>&1
)"
assert_equals "0" "$?" "fd path returns 0"
assert_contains "using fd" "$out" "uses fd"
assert_contains "fd-stub --type file --changed-within 30m" "$out" "fd arguments"

test_start "no_tool"
out="$(
  command() {
    [[ "${1:-}" == "-v" ]] && [[ "${2:-}" == "/usr/bin/find" || "${2:-}" == "fd" ]] && return 1
    builtin command "$@"
  }
  last 2>&1
)"
assert_equals "1" "$?" "no tool returns 1"
assert_contains "No compatible tools found" "$out" "detect_tool error"
assert_contains "Unknown tool detected" "$out" "last falls to unknown-tool arm"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
