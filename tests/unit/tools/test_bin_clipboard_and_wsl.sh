#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for the two platform-shim CLIs in dot_local/bin:
#
#   cb  — universal clipboard: macOS pbcopy/pbpaste, WSL clip.exe /
#         powershell.exe, Wayland wl-copy, X11 xclip/xsel, and the
#         "no backend" error.
#   win — WSL Windows-interop shim: the non-WSL refusal, the missing
#         argument usage and wslpath translation of existing paths.
#
# Both scripts branch on `uname -s` and on `grep -qi microsoft
# /proc/version`, neither of which a macOS or Linux CI host can
# provide for the *other* platform, so this drives them through
# PATH-shadowed `uname`/`grep` plus fake backends. Every backend
# records what it received into a log the assertions read back.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Hand children a copy of the real stderr so their xtrace still reaches
# the coverage runner even though the probes capture output with 2>&1.
exec 21>&2
export BASH_XTRACEFD=21

CB="$REPO_ROOT/defaults/dot_local/bin/executable_cb"
WIN="$REPO_ROOT/defaults/dot_local/bin/executable_win"
# Run the scripts under the same bash the harness uses: a PATH stub that
# resolved to /bin/bash 3.2 would both change behaviour and truncate the
# xtrace records the coverage runner reads.
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

LOG="$DOTFILES_COV_TMPDIR/backend.log"
: >"$LOG"

# _shim <dir> <name> [body…] — record the call, then run the body.
_shim() {
  local dir="$1" name="$2"
  shift 2
  mkdir -p "$dir"
  {
    echo '#!/usr/bin/env bash'
    printf 'printf "%s %%s\\n" "$*" >>"%s"\n' "$name" "$LOG"
    printf 'cat >/dev/null 2>&1 || true\n'
    printf '%s\n' "$@"
  } >"$dir/$name"
  chmod +x "$dir/$name"
}

# Minimal real tools every branch needs, so PATH can stay tiny.
BASE="$DOTFILES_COV_TMPDIR/base"
mkdir -p "$BASE"
for t in bash cat echo printf tr command; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$BASE/$t"
done

# _uname_shim <dir> <value> — `uname -s` answers <value>.
_uname_shim() {
  mkdir -p "$1"
  printf '#!/usr/bin/env bash\necho "%s"\n' "$2" >"$1/uname"
  chmod +x "$1/uname"
}

# _grep_shim <dir> <microsoft?> — stands in for the `grep -qi microsoft
# /proc/version` WSL probe; other greps go to the real binary.
_grep_shim() {
  local real
  real="$(command -v grep)"
  mkdir -p "$1"
  cat >"$1/grep" <<EOF
#!/usr/bin/env bash
if [[ "\$*" == *microsoft*/proc/version* ]]; then
  exit ${2}
fi
exec "$real" "\$@"
EOF
  chmod +x "$1/grep"
}

_run() { # <PATH> <script> [args…]  (stdin passes through)
  local path="$1" script="$2"
  shift 2
  PATH="$path" "$BASH_BIN" "$script" "$@" 2>&1
}

# ── cb: macOS ────────────────────────────────────────────────────────
test_start "cb_macos_copies_stdin_to_pbcopy"
_d="$DOTFILES_COV_TMPDIR/cb-mac"
_uname_shim "$_d" Darwin
_shim "$_d" pbcopy
: >"$LOG"
_out="$(printf 'clip me\n' | _run "$_d:$BASE" "$CB")"
_rc=$?
assert_equals 0 "$_rc" "cb exits 0 on macOS"
assert_contains "Copied to macOS clipboard" "$_out" "confirmation printed"
assert_file_contains "$LOG" "pbcopy" "pbcopy received the copy"

# ── cb: WSL ──────────────────────────────────────────────────────────
test_start "cb_wsl_copies_via_clip_exe"
_d="$DOTFILES_COV_TMPDIR/cb-wsl"
_uname_shim "$_d" Linux
_grep_shim "$_d" 0
_shim "$_d" clip.exe
: >"$LOG"
_out="$(printf 'to windows\n' | _run "$_d:$BASE" "$CB")"
_rc=$?
assert_equals 0 "$_rc" "cb exits 0 under WSL"
assert_contains "Copied to Windows clipboard (WSL)" "$_out" "WSL confirmation printed"
assert_file_contains "$LOG" "clip.exe" "clip.exe received the copy"

test_start "cb_wsl_without_interop_fails"
_d="$DOTFILES_COV_TMPDIR/cb-wsl-bare"
_uname_shim "$_d" Linux
_grep_shim "$_d" 0
_out="$(printf 'x\n' | _run "$_d:$BASE" "$CB")"
_rc=$?
assert_equals 1 "$_rc" "missing clip.exe exits 1"
assert_contains "clip.exe not on PATH" "$_out" "interop failure explained"

# ── cb: Wayland / X11 / none ─────────────────────────────────────────
test_start "cb_wayland_prefers_wl_copy"
_d="$DOTFILES_COV_TMPDIR/cb-wl"
_uname_shim "$_d" Linux
_grep_shim "$_d" 1
_shim "$_d" wl-copy
: >"$LOG"
_out="$(printf 'wayland\n' | WAYLAND_DISPLAY=wayland-0 _run "$_d:$BASE" "$CB")"
assert_equals 0 "$?" "cb exits 0 on Wayland"
assert_contains "Copied to Wayland clipboard" "$_out" "Wayland confirmation printed"
assert_file_contains "$LOG" "wl-copy" "wl-copy received the copy"

test_start "cb_x11_falls_back_to_xclip_then_xsel"
_d="$DOTFILES_COV_TMPDIR/cb-x11"
_uname_shim "$_d" Linux
_grep_shim "$_d" 1
_shim "$_d" xclip
: >"$LOG"
_out="$(printf 'x11\n' | _run "$_d:$BASE" "$CB")"
assert_contains "Copied to X11 clipboard" "$_out" "xclip branch taken"
assert_file_contains "$LOG" "xclip -selection clipboard" "xclip got the selection flag"

_d="$DOTFILES_COV_TMPDIR/cb-xsel"
_uname_shim "$_d" Linux
_grep_shim "$_d" 1
_shim "$_d" xsel
: >"$LOG"
_out="$(printf 'xsel\n' | _run "$_d:$BASE" "$CB")"
assert_contains "Copied to X11 clipboard (xsel)" "$_out" "xsel fallback taken"
assert_file_contains "$LOG" "xsel -b" "xsel got the clipboard flag"

test_start "cb_without_any_backend_fails"
_d="$DOTFILES_COV_TMPDIR/cb-none"
_uname_shim "$_d" Linux
_grep_shim "$_d" 1
_out="$(printf 'nope\n' | _run "$_d:$BASE" "$CB")"
_rc=$?
assert_equals 1 "$_rc" "no backend exits 1"
assert_contains "no clipboard backend found" "$_out" "install hint printed"

test_start "cb_unknown_os_is_a_no_op"
_d="$DOTFILES_COV_TMPDIR/cb-other"
_uname_shim "$_d" SunOS
_out="$(printf 'x\n' | _run "$_d:$BASE" "$CB")"
assert_equals 0 "$?" "unknown OS exits 0"
assert_equals "" "$_out" "and prints nothing"

# ── win ──────────────────────────────────────────────────────────────
test_start "win_refuses_outside_wsl"
_d="$DOTFILES_COV_TMPDIR/win-nonwsl"
_grep_shim "$_d" 1
_out="$(_run "$_d:$BASE" "$WIN" notepad.exe)"
_rc=$?
assert_equals 1 "$_rc" "non-WSL exits 1"
assert_contains "only for WSL systems" "$_out" "refusal explained"

test_start "win_translates_existing_paths_and_passes_the_rest"
_d="$DOTFILES_COV_TMPDIR/win-wsl"
_grep_shim "$_d" 0
_shim "$_d" wslpath 'echo "C:\\translated"'
_shim "$_d" notepad.exe
_file="$DOTFILES_COV_TMPDIR/real-file.txt"
: >"$_file"
: >"$LOG"
_out="$(_run "$_d:$BASE" "$WIN" notepad.exe "$_file" /flag)"
_rc=$?
assert_equals 0 "$_rc" "wsl invocation exits 0"
assert_file_contains "$LOG" 'wslpath -w' "existing path handed to wslpath"
assert_file_contains "$LOG" 'notepad.exe C:\translated /flag' "translated path and passthrough arg forwarded"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
