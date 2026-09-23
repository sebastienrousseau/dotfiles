#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC2016
# Coverage for lib/dot/ui.sh fallbacks the TTY suites rarely reach:
#   * ui_section's colour arm without gum;
#   * _ui_now_ms on a `date` without %N (BSD/macOS);
#   * _ui_steps_emit when the renderer died, with its PID already reaped;
#   * ui_steps_begin when XDG_RUNTIME_DIR is unusable (TMPDIR fallback) and
#     when the FIFO writer cannot be opened (reader killed, plain fallback);
#   * the colour arms of ui_header, ui_progress and the table fallback;
#   * ui_pick's fzf backend with a --preview command, and the colour
#     spinner / ui_run_cmd animation (on a pty).
# The rich-mode gate is stubbed where only the fallback matters; dot-ui,
# date and fzf are PATH stubs; HOME, TMPDIR and XDG_RUNTIME_DIR are mktemp
# directories.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

UI="$REPO_ROOT/lib/dot/ui.sh"
REAL_BASH="${BASH:-$(command -v bash)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/ui-cov.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home" TMPDIR="$WORK/tmp" XDG_RUNTIME_DIR="$WORK/run"
mkdir -p "$HOME" "$TMPDIR" "$XDG_RUNTIME_DIR" "$WORK/bin"
unset NO_COLOR DOTFILES_ACCESSIBILITY DOTFILES_NO_TUI

stub() {
  printf '#!%s\n%s\n' "$REAL_BASH" "$2" >"$WORK/bin/$1"
  chmod +x "$WORK/bin/$1"
}
# A renderer that drains its events, and a date without %N support.
stub dot-ui 'cat >/dev/null'
stub date '[[ "$1" == "+%s%N" ]] && { echo "1700000000N"; exit 0; }
exec /bin/date "$@"'
stub fzf 'read -r first; echo "fzf-args: $*"; echo "picked: $first"'
BASE_PATH="/usr/bin:/bin"

# ui <snippet> — source ui.sh in a fresh bash (stubs first on PATH).
ui() {
  PATH="$WORK/bin:$BASE_PATH" "$REAL_BASH" -c "source '$UI'; $1" 2>&1
}

test_start "section_colour_without_gum"
out="$(ui 'UI_INITED=1; UI_COLOR=1; UI_ENABLED=0; BOLD=B; CYAN=C; NORMAL=N; ui_section Title')"
assert_equals "BCTitleN" "$out" "colour escape wraps the section title"

test_start "colour_arms_without_a_tty"
# ui_init already ran (UI_INITED=1) on a colour terminal without gum.
COLOUR='UI_INITED=1; UI_COLOR=1; UI_ENABLED=0; BOLD=B; BLUE=L; GRAY=G; NORMAL=N'
out="$(ui "$COLOUR; ui_header Head")"
assert_equals "BLHeadN" "$out" "header colour arm"
out="$(ui "$COLOUR; _GL_BAR_FILL=#; _GL_BAR_EMPTY=-; ui_progress 1 2 4")"
assert_equals "L##NG--N" "$out" "progress bar colour arm"
out="$(ui "$COLOUR; ui_table_begin A B; ui_table_add x y; ui_table_end")"
assert_contains "BA       N" "$out" "table fallback bold header"
assert_contains "x       y" "$out" "table fallback row"

test_start "now_ms_without_nanoseconds"
out="$(ui '_ui_now_ms')"
assert_equals "0" "$((out % 1000))" "falls back to whole seconds"
assert_not_empty "$out" "a timestamp is produced"

test_start "emit_after_renderer_exit_reaps_and_falls_back"
out="$(ui '
  exec 9> >(:)
  wait "$!" 2>/dev/null || sleep 1
  sleep 0 &
  dead=$!
  wait "$dead"
  _UI_STEPS_FD=9 _UI_STEPS_RICH=1 _UI_STEPS_PID=$dead
  _ui_steps_emit "{\"t\":\"x\"}"
  echo "fd=[$_UI_STEPS_FD] rich=$_UI_STEPS_RICH pid=[$_UI_STEPS_PID]"
')"
assert_contains "fd=[] rich=0 pid=[]" "$out" "writer state reset after EPIPE"

test_start "steps_begin_falls_back_to_tmpdir"
out="$(XDG_RUNTIME_DIR="$WORK/missing/run" ui '
  _ui_steps_rich_ok() { return 0; }
  ui_steps_begin "Title" "sub"
  echo "rich=$_UI_STEPS_RICH"
  ui_step one "One" ok "fine"
  ui_steps_end "done"
')"
assert_contains "rich=1" "$out" "rich mode starts from the TMPDIR fifo"
assert_equals "0" "$(find "$TMPDIR" -name 'dot-ui.*' | wc -l | tr -d ' ')" "fifo dir cleaned up"

test_start "steps_begin_writer_open_failure_falls_back"
out="$(ui '
  _ui_steps_rich_ok() { return 0; }
  ulimit -n 10
  ui_steps_begin "Title" "sub"
  echo "rich=$_UI_STEPS_RICH pid=[$_UI_STEPS_PID]"
  ui_step one "One" ok "fine"
  ui_steps_end "done"
')"
assert_contains "rich=0 pid=[]" "$out" "plain mode after the fifo writer fails"
assert_contains "== Title · sub ==" "$out" "plain section header printed"
assert_contains "One" "$out" "step still reported"
assert_equals "0" "$(find "$XDG_RUNTIME_DIR" -name 'dot-ui.*' | wc -l | tr -d ' ')" "fifo dir removed"

test_start "pty_pick_fzf_preview_and_colour_spinners"
if command -v script >/dev/null 2>&1; then
  inner="$WORK/pick.sh"
  rcfile="$WORK/pick.rc"
  cat >"$inner" <<EOF
PATH="$WORK/bin:$BASE_PATH"
DOTFILES_NO_TUI=1
source '$UI'
printf 'alpha\nbeta\n' | ui_pick --header "Head" --prompt "P>" --preview "cat {}" --bogus
# Colour spinner and run-command animation (need a TTY on stdout).
UI_INITED=1 UI_COLOR=1 UI_ENABLED=0
ui_spinner_start "spinning"
sleep 0.5
ui_spinner_stop
ui_run_cmd "slow step" 0 1 sleep 0.5
echo \$? >'$rcfile'
EOF
  {
    i=0
    # script(1) hangs up the child once its stdin hits EOF: hold it open
    # until the picker reports back (generous cap for a loaded CI box).
    while [[ ! -f "$rcfile" && $i -lt 1800 ]]; do
      sleep 0.1
      i=$((i + 1))
    done
  } | if [[ "$(uname -s)" == Darwin ]]; then
    script -q "$WORK/pick.raw" "$REAL_BASH" "$inner" >/dev/null 2>&1
  else
    script -qec "$REAL_BASH '$inner'" "$WORK/pick.raw" >/dev/null 2>&1
  fi
  tr -d '\r' <"$WORK/pick.raw" | grep -vE '^\++@COV@:' >"$WORK/pick.out"
  assert_file_contains "$WORK/pick.out" "picked: alpha" "fzf selection returned"
  assert_file_contains "$WORK/pick.out" "--preview cat {} --preview-window right:50%:wrap" "preview passed to fzf"
  assert_file_contains "$WORK/pick.out" "--header Head --prompt P> " "header and prompt passed"
  assert_file_contains "$WORK/pick.out" "spinning" "spinner animated"
  assert_file_contains "$WORK/pick.out" "Installing" "run-command spinner animated"
  assert_file_contains "$WORK/pick.out" "slow step" "run-command result line"
else
  echo "  script(1) missing — pty case skipped"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
