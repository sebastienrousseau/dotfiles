#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for dot_local/bin/open: help, unknown options, the
# default target, macOS, WSL (wslpath + explorer.exe), xdg-open and the
# no-opener error, plus gum feedback. The macOS arm calls /usr/bin/open by
# absolute path, which PATH cannot shadow, so the script is sourced in a
# subshell where a function named /usr/bin/open records the call instead
# of launching anything.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

OPEN="$REPO_ROOT/defaults/dot_local/bin/executable_open"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/open-cov.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
REAL_GREP="$(command -v grep)"

BASE="$SANDBOX/base"
mkdir -p "$BASE"
for t in bash cat env; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$BASE/$t"
done

_stub() { # <dir> <name> <body>
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\n%s\n' "$3" >"$1/$2"
  chmod +x "$1/$2"
}

_case() { # <name> <uname> <wsl:0|1>
  local d="$SANDBOX/$1"
  _stub "$d" uname "echo $2"
  _stub "$d" grep "if [[ \"\$*\" == *microsoft*/proc/version* ]]; then exit $3; fi
exec \"$REAL_GREP\" \"\$@\""
  printf '%s' "$d"
}

# _open <PATH> [args…] — source the script in a subshell with a
# recording /usr/bin/open.
_open() {
  local path="$1"
  shift
  (
    function /usr/bin/open { echo "usr-bin-open:$*"; }
    PATH="$path"
    source "$OPEN" "$@"
  ) 2>&1
}

test_start "help"
out="$(_open "$BASE" --help)"
assert_equals "0" "$?" "help exits 0"
assert_contains "Usage: open [path-or-url]" "$out" "usage printed"

test_start "unknown_option"
out="$(_open "$BASE" --bogus)"
assert_equals "2" "$?" "unknown option exits 2"
assert_contains "Unknown option: --bogus" "$out" "names the option"

test_start "macos_default_target"
d="$(_case mac Darwin 1)"
out="$(_open "$d:$BASE")"
assert_equals "0" "$?" "exits 0"
assert_contains "open: ." "$out" "defaults to current directory"
assert_contains "usr-bin-open:." "$out" "delegates to /usr/bin/open"

test_start "wsl_explorer"
d="$(_case wsl Linux 0)"
_stub "$d" wslpath 'echo "C:\\win\\$2"'
_stub "$d" explorer.exe 'echo "explorer:$*"'
out="$(_open "$d:$BASE" notes.txt)"
assert_equals "0" "$?" "exits 0"
assert_contains 'explorer:C:\win\notes.txt' "$out" "explorer gets the translated path"

test_start "wsl_wslpath_failure_passes_raw_target"
d="$(_case wsl-raw Linux 0)"
_stub "$d" wslpath 'exit 1'
_stub "$d" explorer.exe 'echo "explorer:$*"'
out="$(_open "$d:$BASE" https://example.com)"
assert_contains "explorer:https://example.com" "$out" "raw target used"

test_start "xdg_open"
d="$(_case xdg Linux 1)"
_stub "$d" xdg-open 'echo "xdg:$*"'
out="$(_open "$d:$BASE" file.pdf)"
assert_equals "0" "$?" "exits 0"
assert_contains "xdg:file.pdf" "$out" "xdg-open called"

test_start "no_opener"
d="$(_case none Linux 1)"
out="$(_open "$d:$BASE" file.pdf)"
assert_equals "1" "$?" "exits 1"
assert_contains "No opener found" "$out" "error explained"

test_start "gum_feedback_on_tty"
PY_BIN="$(command -v python3 || true)"
if [[ -n "$PY_BIN" ]]; then
  d="$(_case gum Linux 1)"
  _stub "$d" xdg-open 'exit 0'
  _stub "$d" gum 'echo "gum:$*"'
  out="$(PATH="$d:$BASE" "$PY_BIN" -c '
import os, sys
pid, fd = os.forkpty()
if pid == 0:
    os.execv(sys.argv[1], sys.argv[1:])
out = b""
while True:
    try:
        d = os.read(fd, 4096)
    except OSError:
        break
    if not d:
        break
    out += d
_, st = os.waitpid(pid, 0)
sys.stdout.write(out.decode("utf-8", "replace").replace("\r", ""))
sys.exit(os.WEXITSTATUS(st) if os.WIFEXITED(st) else 1)
' "$(command -v bash)" "$OPEN" doc.md)"
  assert_equals "0" "$?" "exits 0"
  assert_contains "gum:style --foreground 39" "$out" "gum styles the message"
  assert_contains "Opening: doc.md" "$out" "names the target"
else
  assert_true "true" "skipped: python3 needed for a pseudo-terminal"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
