#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for lib/dot/ui.sh on a pseudo-terminal: the step-runner
# (rich NDJSON mode and the plain fallback), the buffered table renderer,
# ui_pick's selector chain, accessibility mode and the product banner.
# script(1) supplies the pty; PATH-shadowed stubs stand in for gum / dot-ui
# / fzf so no real interactive binary runs.

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

# The pseudo-terminal runs below need an interpreter for the inner shell.
# Prefer one that supports `exec {fd}>` (bash 4.1+) because lib/dot/ui.sh
# uses it for the rich step-runner's FIFO; fall back to the interpreter
# running this file. macOS CI runners only have bash 3.2, so the handful
# of assertions that need the newer syntax are gated on PTY_BASH_HAS_VARFD.
_pick_pty_bash() {
  local candidate
  for candidate in "${BASH:-}" "$(command -v bash 2>/dev/null || true)" \
    /opt/homebrew/bin/bash /usr/local/bin/bash /bin/bash; do
    [[ -n "$candidate" && -x "$candidate" ]] || continue
    if "$candidate" -c 'exec {fd}>/dev/null' 2>/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  printf '%s\n' "$REAL_BASH"
}
PTY_BASH="$(_pick_pty_bash)"
PTY_BASH_HAS_VARFD=0
"$PTY_BASH" -c 'exec {fd}>/dev/null' 2>/dev/null && PTY_BASH_HAS_VARFD=1

# tty_run <bash snippet> [stdin-text] — run the snippet with stdout AND
# stderr attached to a pseudo-terminal, so `[[ -t 1 ]]` / `[[ -t 2 ]]`
# branches fire. The typescript (what the terminal showed) is written to
# $TTY_OUT with CRs stripped; the snippet's exit status is returned.
#
# Three details keep this portable and deterministic:
#   * No `exec {fd}>` / BASH_XTRACEFD — both are bash 4.1+, and macOS
#     ships 3.2 as /bin/bash, which is what the macOS CI runner resolves.
#     Under the coverage runner the inner shell's xtrace therefore lands
#     on the pty together with the program's output, so the records are
#     split back out below: replayed on fd 2 for the aggregator, and kept
#     out of the text the assertions read.
#   * script(1) stops relaying pty output once its own stdin reaches EOF,
#     so stdin is held open (after feeding any text) until the inner
#     script has written its exit status.
#   * That exit status travels through a file rather than script(1),
#     whose own status differs between the BSD and util-linux builds.
TTY_OUT="$WORK/tty.out"
tty_run() {
  local snippet="$1" stdin_text="${2:-}" inner rcfile rc
  inner="$WORK/tty_inner.sh"
  rcfile="$WORK/tty.rc"
  rm -f "$rcfile"
  cat >"$inner" <<EOF
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
    script -q "$TTY_OUT.raw" "$PTY_BASH" "$inner" >/dev/null 2>&1
  else
    script -qec "$PTY_BASH '$inner'" "$TTY_OUT.raw" >/dev/null 2>&1
  fi
  tr -d '\r' <"$TTY_OUT.raw" >"$TTY_OUT.all"
  grep -E '^\++@COV@:' "$TTY_OUT.all" >&2
  grep -vE '^\++@COV@:' "$TTY_OUT.all" >"$TTY_OUT"
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

test_start "tty_steps_rich_mode_streams_ndjson_to_dot_ui"
rm -f "$WORK/dot-ui.events"
if [[ "$PTY_BASH_HAS_VARFD" != "1" ]]; then
  # ui_steps_begin opens its renderer FIFO with `exec {fd}>`, which is
  # bash 4.1+. On a host whose only bash is 3.2 (stock macOS, and the
  # macOS CI runner) the rich path cannot be entered at all, so there is
  # nothing to assert here — the plain-mode fallback is covered below.
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped — $PTY_BASH lacks {fd} redirection (bash 4.1+)"
elif FAKE_UNAME=Linux FAKE_COLOR_SCHEME=prefer-dark tty_run 'ui_steps_begin "dot theme" "bloom"; echo "rich=$_UI_STEPS_RICH"; ui_step a "Alpha" run; ui_step_progress 1 2; ui_step_wait "hold"; ui_step a "Alpha" ok "fine"; ui_steps_end "all good"; echo "active=$_UI_STEPS_ACTIVE"'; then
  assert_file_contains "$TTY_OUT" "rich=1" "rich mode engaged"
  assert_file_contains "$TTY_OUT" "active=0" "steps deactivated after end"
  assert_file_contains "$WORK/dot-ui.events" '{"t":"header","title":"dot theme","subtitle":"bloom"}' "header event emitted"
  assert_file_contains "$WORK/dot-ui.events" '"t":"progress","cur":1,"total":2' "progress event emitted"
  assert_file_contains "$WORK/dot-ui.events" '"t":"wait","label":"hold"' "wait event emitted"
  assert_file_contains "$WORK/dot-ui.events" '"state":"ok","detail":"fine"' "step event emitted"
  assert_file_contains "$WORK/dot-ui.events" '"summary":"all good"' "done event emitted"
else
  _fail "pty run failed"
fi

test_start "tty_steps_rich_gate_honours_opt_outs"
if DOTFILES_NO_TUI=1 tty_run 'ui_steps_begin "T" "S"; echo "rich=$_UI_STEPS_RICH"; ui_steps_end'; then
  assert_file_contains "$TTY_OUT" "rich=0" "DOTFILES_NO_TUI=1 → plain mode on a TTY"
  assert_file_contains "$TTY_OUT" "T · S" "plain header prints title · subtitle"
else
  _fail "pty run failed"
fi

test_start "tty_steps_rich_falls_back_when_mkfifo_fails"
if TMPDIR="$WORK/nope" tty_run 'mkfifo() { return 1; }; ui_steps_begin "T"; echo "rich=$_UI_STEPS_RICH"; ui_steps_end'; then
  assert_file_contains "$TTY_OUT" "rich=0" "fifo creation failure → plain mode"
else
  _fail "pty run failed"
fi

test_start "tty_table_end_prefers_dot_ui_then_gum_then_printf"
rm -f "$WORK/dot-ui.table" "$WORK/gum.calls"
if tty_run 'ui_table_begin "Tool" "Ver"; ui_table_add "rg" "14"; ui_table_end; echo "hdrs=${#_UI_TABLE_HEADERS[@]}"'; then
  assert_file_contains "$WORK/dot-ui.table" $'rg\x1f14' "rows streamed to dot-ui table"
  assert_file_contains "$TTY_OUT" "hdrs=0" "buffers cleared after render"
else
  _fail "pty run (dot-ui) failed"
fi
if DOT_UI_TABLE_RC=1 tty_run 'ui_table_begin "Tool" "Ver"; ui_table_add "rg" "14"; ui_table_end'; then
  assert_file_contains "$WORK/gum.calls" "table --print" "dot-ui failure → gum table"
else
  _fail "pty run (gum) failed"
fi
if DOT_UI_TABLE_RC=1 GUM_TABLE_RC=1 tty_run 'ui_table_begin "Tool" "Ver"; ui_table_add "rg" "14"; ui_table_end'; then
  assert_file_contains "$TTY_OUT" "Tool" "gum failure → printf fallback prints header"
  assert_file_contains "$TTY_OUT" "rg" "printf fallback prints rows"
else
  _fail "pty run (printf) failed"
fi
if DOT_UI_TABLE_RC=1 tty_run 'ui_table_begin "Only"; ui_table_end'; then
  assert_file_contains "$WORK/gum.calls" "table --print" "zero-row table still rendered"
else
  _fail "pty run (zero rows) failed"
fi

test_start "tty_pick_uses_fzf_then_gum_when_dot_ui_cannot_run"
rm -f "$WORK/fzf.calls" "$WORK/gum.calls"
if DOT_UI_PICK_RC=2 tty_run 'printf "one\ntwo\n" | ui_pick --header H --prompt P'; then
  assert_file_contains "$WORK/fzf.calls" "--header H --prompt P " "fzf receives header/prompt"
  assert_file_contains "$TTY_OUT" "two" "fzf stub selection printed"
else
  _fail "pty run (fzf) failed"
fi
if DOT_UI_PICK_RC=2 PATH="$NOFZF_BIN:/usr/bin:/bin" tty_run 'printf "one\ntwo\n" | ui_pick'; then
  assert_file_contains "$WORK/gum.calls" "choose" "no fzf → gum choose"
  assert_file_contains "$TTY_OUT" "one" "gum choose stub selection printed"
else
  _fail "pty run (gum choose) failed"
fi

test_start "tty_accessibility_overrides_glyphs_and_gum"
if DOTFILES_ACCESSIBILITY=1 tty_run 'ui_header "H"; ui_ok "fine"; ui_cmd "c" "d"; ui_logo_dot; echo "enabled=$UI_ENABLED"'; then
  assert_file_contains "$TTY_OUT" "[OK]" "ASCII glyphs on a TTY"
  assert_file_contains "$TTY_OUT" "enabled=0" "gum disabled by accessibility mode"
else
  _fail "pty run failed"
fi

test_start "tty_product_banner_prints_once"
if tty_run 'ui_product_banner "One"; ui_dot_banner "Two"; echo "printed=$DOTFILES_LOGO_PRINTED"'; then
  assert_file_contains "$TTY_OUT" "printed=1" "logo flag set after first banner"
  if [[ "$(grep -c DOTFILES "$TTY_OUT")" == "1" ]]; then _pass; else _fail "logo printed more than once"; fi
else
  _fail "pty run failed"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
