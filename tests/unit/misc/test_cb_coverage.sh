#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for the paste side of dot_local/bin/cb (stdin is a
# terminal) and its gum-styled feedback (stdout is a terminal). Both need
# a real TTY, so the script runs under a pseudo-terminal opened with
# python3's os.forkpty. Every backend (pbpaste, powershell.exe, wl-paste,
# xclip, xsel, gum) is a sandboxed stub; `uname` and the WSL probe are
# PATH shims.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CB="$REPO_ROOT/defaults/dot_local/bin/executable_cb"
BASH_BIN="$(command -v bash)"
PY_BIN="$(command -v python3 || true)"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/cb-cov.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"

# Minimal real tools, so each case's PATH exposes only chosen backends.
BASE="$SANDBOX/base"
mkdir -p "$BASE"
for t in bash cat tr env; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$BASE/$t"
done

_stub() { # <dir> <name> <body>
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\n%s\n' "$3" >"$1/$2"
  chmod +x "$1/$2"
}

# _case <name> <uname> <wsl:0|1> — fresh stub dir with uname + grep shims.
_case() {
  local d="$SANDBOX/$1" real_grep
  real_grep="$(command -v grep)"
  _stub "$d" uname "echo $2"
  _stub "$d" grep "if [[ \"\$*\" == *microsoft*/proc/version* ]]; then exit $3; fi
exec \"$real_grep\" \"\$@\""
  printf '%s' "$d"
}

# _tty <PATH> <cmd…> — run with stdin/stdout/stderr on a fresh pty.
_tty() {
  local path="$1"
  shift
  PATH="$path" "$PY_BIN" -c '
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
' "$BASH_BIN" "$@"
}

if [[ -z "$PY_BIN" ]]; then
  test_start "pty_unavailable"
  assert_true "true" "skipped: python3 needed for a pseudo-terminal"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

test_start "macos_paste"
d="$(_case mac Darwin 1)"
_stub "$d" pbpaste 'echo from-pbpaste'
out="$(_tty "$d:$BASE" "$CB")"
assert_equals "0" "$?" "exits 0"
assert_contains "from-pbpaste" "$out" "pbpaste output relayed"

test_start "wsl_paste_via_powershell"
d="$(_case wsl Linux 0)"
_stub "$d" powershell.exe 'echo "ps:$*"; printf "win-clip\r\n"'
out="$(_tty "$d:$BASE" "$CB")"
assert_equals "0" "$?" "exits 0"
assert_contains "ps:-command Get-Clipboard" "$out" "asks PowerShell for the clipboard"
assert_contains "win-clip" "$out" "clipboard relayed"

test_start "wsl_paste_without_powershell"
d="$(_case wsl-bare Linux 0)"
out="$(_tty "$d:$BASE" "$CB")"
assert_equals "1" "$?" "exits 1"
assert_contains "powershell.exe not on PATH" "$out" "interop hint"

test_start "wayland_paste"
d="$(_case wl Linux 1)"
_stub "$d" wl-copy 'exit 0'
_stub "$d" wl-paste 'echo from-wl-paste'
out="$(WAYLAND_DISPLAY=wayland-0 _tty "$d:$BASE" "$CB")"
assert_equals "0" "$?" "exits 0"
assert_contains "from-wl-paste" "$out" "wl-paste output relayed"

test_start "xclip_paste"
d="$(_case xclip Linux 1)"
_stub "$d" xclip 'echo "xclip:$*"'
out="$(_tty "$d:$BASE" "$CB")"
assert_equals "0" "$?" "exits 0"
assert_contains "xclip:-selection clipboard -o" "$out" "xclip asked to output"

test_start "xsel_paste"
d="$(_case xsel Linux 1)"
_stub "$d" xsel 'echo "xsel:$*"'
out="$(_tty "$d:$BASE" "$CB")"
assert_equals "0" "$?" "exits 0"
assert_contains "xsel:-b -o" "$out" "xsel asked to output"

test_start "gum_feedback_on_tty"
d="$(_case gum Darwin 1)"
_stub "$d" pbcopy 'cat >/dev/null'
_stub "$d" gum 'echo "gum:$*"'
# stdin is a pipe (copy mode) while stdout stays on the pty.
out="$(_tty "$d:$BASE" -c 'echo payload | bash "$0"' "$CB")"
assert_equals "0" "$?" "exits 0"
assert_contains "gum:style --foreground 212" "$out" "gum styles the confirmation"
assert_contains "Copied to macOS clipboard" "$out" "confirmation text"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
