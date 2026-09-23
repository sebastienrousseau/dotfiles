#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# scripts/diagnostics/perf.sh paths the other suites leave dark: measuring
# nushell and PowerShell (their per-shell targets and invocations), the
# "Good" score band, and the gum-enabled key/value rendering of the
# component breakdown (gum + a real TTY, supplied by a python pty).
#
# Every shell is a PATH stub that sleeps a fixed interval, so timings are
# bounded and nothing reads a real profile. HOME/XDG live in mktemp.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PERF="$REPO_ROOT/scripts/diagnostics/perf.sh"
WORK="$(mktemp -d -t perf-cov.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

H="$WORK/home"
mkdir -p "$H" "$WORK/stubs"
for s in zsh nu pwsh; do
  printf '#!/bin/sh\nsleep 0.2\nexit 0\n' >"$WORK/stubs/$s"
  chmod +x "$WORK/stubs/$s"
done
# gum stub: echo whatever it was asked to render.
printf '#!/bin/sh\nfor a; do last="$a"; done\nprintf "%%s\\n" "$last"\n' >"$WORK/stubs/gum"
chmod +x "$WORK/stubs/gum"

OUT=""
RC=0
perf_run() {
  RC=0
  OUT="$(HOME="$H" XDG_CACHE_HOME="$H/.cache" XDG_STATE_HOME="$H/.local/state" \
    PATH="$WORK/stubs:$PATH" "$@" 2>&1 </dev/null)" || RC=$?
}

test_start "perf_measures_nushell_in_the_good_band"
perf_run env NO_COLOR=1 DOTFILES_PERF_MAX_MS=4000 \
  "${BASH:-bash}" "$PERF" --shell nu --runs 1 --target 0 --no-baseline-check
assert_equals 0 "$RC" "perf exits 0"
assert_contains " nu " "$OUT" "nushell row printed"
assert_contains "target  500ms" "$OUT" "nushell default target applied"
assert_contains "Good (tune to reach 100)" "$OUT" "score lands in the good band"

test_start "perf_measures_powershell_with_gum_rendering"
if command -v python3 >/dev/null 2>&1; then
  perf_run env NO_COLOR=1 python3 -c '
import os, pty, sys
status = pty.spawn(sys.argv[1:])
sys.exit(os.WEXITSTATUS(status) if os.WIFEXITED(status) else 1)
' "${BASH:-bash}" "$PERF" --shell pwsh --runs 1 --no-baseline-check
  assert_equals 0 "$RC" "perf under a TTY exits 0"
  assert_contains "pwsh" "$OUT" "powershell row printed"
  assert_contains "target  600ms" "$OUT" "powershell default target applied"
  assert_contains "bare zsh" "$OUT" "component breakdown rendered"
  if [[ "$OUT" == *"bare zsh:"* ]]; then
    assert_equals "ui_kv row" "plain row" "gum-enabled breakdown uses ui_kv"
  else
    assert_equals "ui_kv row" "ui_kv row" "gum-enabled breakdown uses ui_kv"
  fi
else
  assert_equals "skip" "skip" "python3 unavailable; pty case skipped"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" == 0 ]]
