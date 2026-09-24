#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for sysinfo. The file collects facts at source time,
# so each platform case sources it in a subshell whose probes (uname,
# hostname, system_profiler, sw_vers, uptime, lscpu, lspci, xrandr, the
# /proc/meminfo grep) are shell functions returning canned data. A
# scoped `command` wrapper hides optional Linux tools, and a python3
# pseudo-terminal covers the coloured (stdout-is-a-tty) branch.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/system/sysinfo.sh"

SANDBOX="$(mktemp -d "${TMPDIR:-/tmp}/sysinfo-cov.XXXXXX")"
trap 'rm -rf "$SANDBOX"' EXIT
export HOME="$SANDBOX/home"
mkdir -p "$HOME"
export SHELL=/bin/zsh TERM=xterm-test
unset TERM_PROGRAM NO_COLOR

# Canned probes shared by every case; FAKE_OS picks the uname answer.
_probes() {
  uname() {
    case "${1:-}" in
      -r) echo "9.9.9-test" ;;
      *) echo "$FAKE_OS" ;;
    esac
  }
  hostname() { echo "box"; }
  system_profiler() {
    case "$1" in
      SPHardwareDataType)
        printf '      Model Name: MacBook Test\n      Model Identifier: Mac99,1\n      Chip: Apple T1\n      Total Number of Cores: 8\n      Memory: 16 GB\n'
        ;;
      SPDisplaysDataType)
        printf '      Chipset Model: Apple T1 GPU\n          Resolution: 3024 x 1964 Retina\n'
        ;;
    esac
  }
  sw_vers() { echo "26.0"; }
  uptime() {
    if [[ "${1:-}" == "-p" ]]; then echo "up 2 hours"; else echo "10:00  up 3 days, 1 user"; fi
  }
  lscpu() { printf 'Architecture: x86_64\nModel name:   Test CPU 3000\n'; }
  lspci() { printf '00:02.0 VGA compatible controller: Test GPU\n'; }
  xrandr() { printf 'Screen 0\n   1920x1080     60.00*+\n'; }
  grep() {
    if [[ "${2:-}" == "/proc/meminfo" ]]; then
      [[ -n "${FAKE_MEM:-}" ]] && echo "MemTotal:       $FAKE_MEM kB"
      return 0
    fi
    command grep "$@"
  }
}

# _sys <os> [hide-linux-tools:0|1]
_sys() {
  local hide="${2:-0}"
  (
    FAKE_OS="$1"
    _probes
    if [[ "$hide" == 1 ]]; then
      command() {
        if [[ "${1:-}" == "-v" ]]; then
          case "${2:-}" in lscpu | lspci | xrandr) return 1 ;; esac
        fi
        builtin command "$@"
      }
    fi
    source "$FUNC_FILE"
    sysinfo
  ) 2>&1
}

test_start "darwin"
out="$(_sys Darwin)"
assert_contains "box" "$out" "hostname"
assert_contains "OS:         macOS 26.0" "$out" "macOS version"
assert_contains "Uptime:     3 days" "$out" "uptime trimmed"
assert_contains "CPU:        Apple T1 (8 cores)" "$out" "chip and cores"
assert_contains "GPU:        Apple T1 GPU" "$out" "GPU"
assert_contains "Memory:     16 GB" "$out" "memory"
assert_contains "Terminal:   xterm-test" "$out" "TERM fallback for terminal"
assert_contains "Resolution: 3024 x 1964 Retina" "$out" "resolution"
assert_contains "Model:      MacBook Test (Mac99,1)" "$out" "model line"
assert_false "[[ '$out' == *$'\033'* ]]" "no colour when stdout is not a tty"

test_start "linux_with_tools"
out="$(FAKE_MEM=16777216 _sys Linux)"
assert_contains "Kernel:     9.9.9-test" "$out" "kernel"
assert_contains "Uptime:     2 hours" "$out" "uptime -p"
assert_contains "CPU:        Test CPU 3000" "$out" "lscpu model"
assert_contains "GPU:        Test GPU" "$out" "lspci GPU"
assert_contains "Memory:     16.0GiB" "$out" "meminfo converted"
assert_contains "Resolution: 1920x1080" "$out" "xrandr resolution"
assert_contains "Shell:      zsh" "$out" "shell basename"
assert_false "[[ '$out' == *Model:* ]]" "no model line on Linux"

test_start "linux_without_tools"
out="$(_sys Linux 1)"
assert_contains "CPU:        Unknown CPU" "$out" "no lscpu"
assert_contains "GPU:        Unknown GPU" "$out" "no lspci"
assert_contains "Memory:     Unknown" "$out" "no meminfo"
assert_contains "Resolution: Unknown" "$out" "no xrandr"

test_start "windows_shells_and_other_fallback"
out="$(_sys MINGW64_NT-10.0)"
assert_contains "OS:         MINGW64_NT-10.0" "$out" "fallback OS name"
assert_contains "Uptime:     Unknown" "$out" "fallback uptime"
out="$(_sys FreeBSD)"
assert_contains "OS:         FreeBSD" "$out" "other OS name"
assert_contains "CPU:        Unknown" "$out" "fallback CPU"

test_start "colour_on_tty"
PY_BIN="$(command -v python3 || true)"
if [[ -n "$PY_BIN" ]]; then
  export FUNC_FILE
  out="$("$PY_BIN" -c '
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
os.waitpid(pid, 0)
sys.stdout.write(out.decode("utf-8", "replace").replace("\r", ""))
' "$(command -v bash)" -c 'uname() { echo "SunOS"; }; source "$FUNC_FILE"; sysinfo')"
  # Regression: the colours were single-quoted '\033…' strings printed
  # with plain echo, so a terminal showed the literal text "\033[0;32m".
  assert_contains $'\033[0;32mOS:\033[0m' "$out" "real ESC colour codes on a tty"
  assert_false "[[ \"\$out\" == *'\\033'* ]]" "no literal backslash escapes"
else
  assert_true "true" "skipped: python3 needed for a pseudo-terminal"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
