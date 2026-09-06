#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for lib/dot/ui.sh on a pseudo-terminal: the colour
# palette, gum delegation, spinner animation, ui_run_cmd and ui_confirm.
# script(1) supplies the pty so `[[ -t 1 ]]` branches fire; PATH-shadowed
# stubs stand in for gum / dot-ui / fzf so no real interactive binary runs.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/lib/dot/ui.sh"
REAL_UNAME="$(command -v uname)"
# The bash running this file — pinned into every stub PATH below. macOS
# ships bash 3.2 at /bin/bash, which lacks the `exec {fd}>` redirection the
# pty helper needs, so a PATH-shadowed `bash` must be this interpreter.
REAL_BASH="${BASH:-$(command -v bash)}"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
STUB_BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "lib/dot/ui.sh must exist"

# ---------------------------------------------------------------------------
# Stubs. Each records its argv to $WORK/<name>.calls so tests can assert on
# what the library asked for. Behaviour is steered by *_RC env vars.
# ---------------------------------------------------------------------------
cat >"$STUB_BIN/gum" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${STUB_CALLS_DIR:?}/gum.calls"
case "${1:-}" in
  style) shift; while [[ "${1:-}" == --* ]]; do shift; done; printf 'gum-style:%s\n' "$*" ;;
  confirm) exit "${GUM_CONFIRM_RC:-0}" ;;
  table) cat; exit "${GUM_TABLE_RC:-0}" ;;
  choose) head -n 1 ;;
esac
exit 0
STUB
cat >"$STUB_BIN/dot-ui" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${STUB_CALLS_DIR:?}/dot-ui.calls"
case "${1:-}" in
  run) cat >"${STUB_CALLS_DIR}/dot-ui.events" ;;
  pick)
    input="$(cat)"
    if [[ "${DOT_UI_PICK_RC:-0}" == "0" ]]; then printf '%s\n' "$input" | head -n 1; fi
    exit "${DOT_UI_PICK_RC:-0}" ;;
  table) cat >"${STUB_CALLS_DIR}/dot-ui.table"; exit "${DOT_UI_TABLE_RC:-0}" ;;
esac
exit 0
STUB
cat >"$STUB_BIN/fzf" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${STUB_CALLS_DIR:?}/fzf.calls"
tail -n 1
STUB
cat >"$STUB_BIN/uname" <<STUB
#!/usr/bin/env bash
if [[ -n "\${FAKE_UNAME:-}" && "\${1:-}" == "-s" ]]; then echo "\$FAKE_UNAME"; exit 0; fi
exec "$REAL_UNAME" "\$@"
STUB
cat >"$STUB_BIN/gsettings" <<'STUB'
#!/usr/bin/env bash
[[ "${1:-}" == get ]] && printf "'%s'\n" "${FAKE_COLOR_SCHEME:-default}"
exit 0
STUB
cat >"$STUB_BIN/defaults" <<'STUB'
#!/usr/bin/env bash
[[ "${1:-}" == read ]] && printf '%s\n' "${FAKE_APPLE_STYLE:-Light}"
exit 0
STUB
chmod +x "$STUB_BIN"/gum "$STUB_BIN"/dot-ui "$STUB_BIN"/fzf "$STUB_BIN"/uname \
  "$STUB_BIN"/gsettings "$STUB_BIN"/defaults
export STUB_CALLS_DIR="$WORK"

# Theme fixture: a chezmoi source tree with a `.chezmoiroot` indirection so
# the descend-into-subdir branch of _ui_theme_files is exercised.
THEME_SRC="$WORK/src"
mkdir -p "$THEME_SRC/defaults/.chezmoidata"
echo "defaults" >"$THEME_SRC/.chezmoiroot"
printf 'theme = "bloom"\n' >"$THEME_SRC/defaults/.chezmoidata.toml"
cat >"$THEME_SRC/defaults/.chezmoidata/themes.toml" <<'TOML'
[themes.bloom-dark]
family = "bloom"
mode = "dark"

[themes.bloom-dark.term]
fg = "#f0f0f0"
bg = "#101010"

[themes.bloom-dark.ui]
accent = "#455c67"
error = "#997d7a"
warning = "#8a836f"
success = "#479174"
info = "#5f86b7"
panel = "#242435"
border = "#302f38"

[themes.bloom-light]
family = "bloom"
mode = "light"
TOML
cat >"$STUB_BIN/chezmoi" <<STUB
#!/usr/bin/env bash
[[ "\${1:-}" == source-path ]] && echo "\${FAKE_CHEZMOI_SRC-$THEME_SRC}"
exit 0
STUB
chmod +x "$STUB_BIN/chezmoi"

# The host may have real gum / dot-ui / fzf installed. Pin PATH to the stub
# dir plus system dirs so no test can reach a real interactive binary. Two
# reduced variants drop the selector binaries so the fallback chains in
# ui_pick / ui_confirm can be reached.
ln -sf "$REAL_BASH" "$STUB_BIN/bash"
export PATH="$STUB_BIN:/usr/bin:/bin"
NOFZF_BIN="$WORK/nofzf-bin"
NOGUM_BIN="$WORK/nogum-bin"
mkdir -p "$NOFZF_BIN" "$NOGUM_BIN"
for s in gum dot-ui uname gsettings defaults chezmoi bash; do
  ln -sf "$STUB_BIN/$s" "$NOFZF_BIN/$s"
done
for s in uname gsettings defaults chezmoi bash; do
  ln -sf "$STUB_BIN/$s" "$NOGUM_BIN/$s"
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
# _pass / _fail — record a hand-rolled check in the framework counters.
_pass() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
}
_fail() {
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $1"
}

# in_ui <bash snippet> — source ui.sh fresh in a child bash and run the
# snippet; stdout is captured, xtrace (stderr) is passed through.
in_ui() {
  bash -c "set +e; source '$SCRIPT_FILE'; $1"
}

# tty_run <bash snippet> [stdin-text] — run the snippet with stdout AND
# stderr attached to a pseudo-terminal, so `[[ -t 1 ]]` / `[[ -t 2 ]]`
# branches fire. The typescript (what the terminal showed) is written to
# $TTY_OUT with CRs stripped; the snippet's exit status is returned.
#
# Two details keep this deterministic:
#   * xtrace goes to BASH_XTRACEFD (a file replayed on our stderr) so the
#     coverage aggregator still sees every traced line while fd 2 stays a
#     terminal for the `[[ -t 2 ]]` branches.
#   * script(1) stops relaying pty output once its own stdin reaches EOF,
#     so stdin is held open (after feeding any text) until the inner
#     script has written its exit status.
TTY_OUT="$WORK/tty.out"
tty_run() {
  local snippet="$1" stdin_text="${2:-}" inner trace rcfile rc
  inner="$WORK/tty_inner.sh"
  trace="$WORK/tty.trace"
  rcfile="$WORK/tty.rc"
  : >"$trace"
  rm -f "$rcfile"
  cat >"$inner" <<EOF
exec {__xfd}>>'$trace'
export BASH_XTRACEFD=\$__xfd
set +e
source '$SCRIPT_FILE'
$snippet
echo \$? >'$rcfile'
EOF
  {
    [[ -n "$stdin_text" ]] && printf '%s\n' "$stdin_text"
    local _i=0
    while [[ ! -f "$rcfile" && $_i -lt 400 ]]; do
      sleep 0.05
      _i=$((_i + 1))
    done
  } | if [[ "$("$REAL_UNAME" -s)" == Darwin ]]; then
    script -q "$TTY_OUT.raw" bash "$inner" >/dev/null 2>&1
  else
    script -qec "bash '$inner'" "$TTY_OUT.raw" >/dev/null 2>&1
  fi
  tr -d '\r' <"$TTY_OUT.raw" >"$TTY_OUT"
  cat "$trace" >&2
  rc="$(cat "$rcfile" 2>/dev/null || echo 255)"
  return "$rc"
}

_has_pty() { command -v script >/dev/null 2>&1; }

# ===========================================================================
# Section B — pseudo-terminal runs (colour / gum / dot-ui rich mode)
# ===========================================================================
if ! _has_pty; then
  test_start "pty_available"
  _fail "script(1) not found — TTY branches cannot be exercised"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 1
fi

test_start "tty_colour_layout_primitives"
if TERM=xterm tty_run 'ui_header "Head"; ui_section "Sect"; ui_ok "ok" "d"; ui_cmd "cmd" "desc"; ui_bullet "b"; ui_kv "k" "v"; ui_logo_dot "T"; ui_table_header "A" "B"; ui_table_row "1" "2"; ui_table_sep; echo "color=$UI_COLOR utf8=$UI_UTF8"' </dev/null; then
  assert_file_contains "$TTY_OUT" "color=1" "UI_COLOR=1 on a colour TTY"
  assert_file_contains "$TTY_OUT" $'\033[1m' "header rendered with bold escape"
else
  _fail "pty run failed rc=$?"
fi

test_start "tty_no_color_env_disables_palette"
if NO_COLOR=1 PATH="$NOGUM_BIN:/usr/bin:/bin" tty_run 'ui_header "Head"; echo "color=$UI_COLOR"'; then
  assert_file_contains "$TTY_OUT" "color=0" "NO_COLOR keeps UI_COLOR=0"
  assert_file_contains "$TTY_OUT" "--- Head ---" "plain header fallback"
else
  _fail "pty run failed"
fi

test_start "tty_gum_enabled_uses_gum_style"
rm -f "$WORK/gum.calls"
if tty_run 'ui_header "Head"; ui_section "Sect"; echo "enabled=$UI_ENABLED"'; then
  assert_file_contains "$TTY_OUT" "enabled=1" "gum on PATH + TTY → UI_ENABLED=1"
  assert_file_contains "$WORK/gum.calls" "style --foreground 212 --bold Head" "header delegated to gum style"
  assert_file_contains "$WORK/gum.calls" "style --foreground 212 --bold Sect" "section delegated to gum style"
else
  _fail "pty run failed"
fi

test_start "tty_spinner_animates_and_stops"
if tty_run 'ui_spinner_start "Load"; sleep 0.3; ui_spinner_stop; echo "pid=[$_UI_SPINNER_PID]"'; then
  assert_file_contains "$TTY_OUT" "Load" "spinner label drawn on the terminal"
  assert_file_contains "$TTY_OUT" "pid=[]" "spinner pid cleared after stop"
else
  _fail "pty run failed"
fi

test_start "tty_spinner_no_color_branch"
if NO_COLOR=1 tty_run 'ui_spinner_start "Mono"; sleep 0.3; ui_spinner_stop'; then
  assert_file_contains "$TTY_OUT" "Mono" "monochrome spinner frame drawn"
else
  _fail "pty run failed"
fi

test_start "tty_run_cmd_success_and_failure"
if tty_run 'ui_run_cmd "good" 0 2 sleep 0.3; echo "rc1=$?"; ui_run_cmd "bad" 1 2 false; echo "rc2=$?"; NO_COLOR=1 UI_COLOR=0 ui_run_cmd "mono" 1 2 sleep 0.2; echo "rc3=$?"'; then
  assert_file_contains "$TTY_OUT" "rc1=0" "successful command → rc 0"
  assert_file_contains "$TTY_OUT" "rc2=1" "failing command → rc 1"
  assert_file_contains "$TTY_OUT" "rc3=0" "monochrome spinner branch → rc 0"
  # The colour branch injects an SGR escape between "Installing " and the
  # label, so match the fixed prefix rather than the joined string.
  assert_file_contains "$TTY_OUT" "Installing " "spinner frame drawn while the command runs"
else
  _fail "pty run failed"
fi

test_start "tty_progress_colour_bar"
if tty_run 'ui_progress 2 4 8; echo; echo "done"'; then
  assert_file_contains "$TTY_OUT" "￭￭￭￭" "filled segment rendered"
else
  _fail "pty run failed"
fi

test_start "tty_confirm_reads_answer_from_terminal"
# gum is on PATH, so first prove the gum path; then hide gum for the read path.
if GUM_CONFIRM_RC=0 tty_run 'ui_confirm "Go?"; echo "gum_rc=$?"'; then
  assert_file_contains "$TTY_OUT" "gum_rc=0" "gum confirm rc forwarded"
else
  _fail "pty run (gum) failed"
fi
if PATH="$NOGUM_BIN:/usr/bin:/bin" tty_run 'ui_confirm "Go?" n; echo "ans_rc=$?"' "y"; then
  assert_file_contains "$TTY_OUT" "[y/N]" "default-no hint shown"
  assert_file_contains "$TTY_OUT" "ans_rc=0" "typed y → rc 0"
else
  _fail "pty run (read) failed"
fi
if PATH="$NOGUM_BIN:/usr/bin:/bin" tty_run 'ui_confirm "Go?"; echo "ans_rc=$?"' "n"; then
  assert_file_contains "$TTY_OUT" "[Y/n]" "default-yes hint shown"
  assert_file_contains "$TTY_OUT" "ans_rc=1" "typed n → rc 1"
else
  _fail "pty run (read) failed"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
