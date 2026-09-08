#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for lib/dot/ui.sh in non-TTY (plain) mode: theme-file
# resolution, the DOT_UI_* colour export, the picker/confirm fallbacks and
# the table/steps guards. Every branch is driven through inputs — env
# toggles, stub exit codes and fixture files — never by editing the library.
#
# TTY-only branches live in test_auto_ui_tty_modes.sh and
# test_auto_ui_tty_steps.sh (they need a pseudo-terminal and are split out
# to keep each file well inside the coverage runner's per-file timeout).

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
# Section A — non-TTY behaviour with stubs (runs in-process, no pty needed)
# ===========================================================================

test_start "theme_files_follow_chezmoiroot_indirection"
out="$(in_ui '_ui_theme_files && printf "%s\n" "$_UI_THEMES_FILE"')"
assert_equals "$THEME_SRC/defaults/.chezmoidata/themes.toml" "$out" "themes.toml resolved under the .chezmoiroot subdir"

test_start "theme_files_fall_back_to_home_dotfiles_when_chezmoi_silent"
out="$(FAKE_CHEZMOI_SRC="" in_ui '_ui_theme_files; echo "rc=$? file=$_UI_THEMES_FILE"')"
assert_equals "rc=0 file=$HOME/.dotfiles/defaults/.chezmoidata/themes.toml" "$out" "falls back to ~/.dotfiles (+ .chezmoiroot) when chezmoi prints nothing"

test_start "theme_files_fail_without_any_source"
out="$(FAKE_CHEZMOI_SRC="" HOME="$WORK/nohome" in_ui '_ui_theme_files; echo "rc=$?"')"
assert_equals "rc=1" "$out" "no chezmoi source-path, no ~/.dotfiles, no ~/.local/share/chezmoi → rc=1"

test_start "theme_files_fail_when_themes_toml_missing"
mkdir -p "$WORK/empty-src"
out="$(FAKE_CHEZMOI_SRC="$WORK/empty-src" in_ui '_ui_theme_files; echo "rc=$?"')"
assert_equals "rc=1" "$out" "source dir without .chezmoidata/themes.toml → rc=1"

test_start "active_mode_darwin_dark"
out="$(FAKE_UNAME=Darwin FAKE_APPLE_STYLE=Dark in_ui '_ui_active_mode')"
assert_equals "dark" "$out" "AppleInterfaceStyle=Dark → dark"

test_start "active_mode_darwin_light"
out="$(FAKE_UNAME=Darwin FAKE_APPLE_STYLE=Light in_ui '_ui_active_mode')"
assert_equals "light" "$out" "no AppleInterfaceStyle → light"

test_start "active_mode_linux_prefers_dark"
out="$(FAKE_UNAME=Linux FAKE_COLOR_SCHEME=prefer-dark in_ui '_ui_active_mode')"
assert_equals "dark" "$out" "gsettings prefer-dark → dark"

test_start "active_mode_linux_default_light"
out="$(FAKE_UNAME=Linux FAKE_COLOR_SCHEME=default in_ui '_ui_active_mode')"
assert_equals "light" "$out" "gsettings default → light"

test_start "active_theme_section_pairs_family_with_mode"
out="$(FAKE_UNAME=Linux FAKE_COLOR_SCHEME=prefer-dark in_ui '_ui_active_theme_section')"
assert_equals "bloom-dark" "$out" "family bloom + dark mode → bloom-dark"

test_start "active_theme_section_fails_without_family"
printf '# no theme key\n' >"$WORK/empty-src/.chezmoidata.toml"
mkdir -p "$WORK/empty-src/.chezmoidata"
printf '[themes.x-dark]\n' >"$WORK/empty-src/.chezmoidata/themes.toml"
out="$(FAKE_CHEZMOI_SRC="$WORK/empty-src" in_ui '_ui_active_theme_section; echo "rc=$?"')"
assert_equals "rc=1" "$out" "a data file with no theme key → rc=1"

test_start "active_theme_section_fails_when_family_absent_from_themes"
printf 'theme = "ghost"\n' >"$WORK/empty-src/.chezmoidata.toml"
out="$(FAKE_CHEZMOI_SRC="$WORK/empty-src" in_ui '_ui_active_theme_section; echo "rc=$?"')"
assert_equals "rc=1" "$out" "family with no [themes.ghost*] section → rc=1"

test_start "theme_ui_value_reads_hex"
out="$(in_ui 'theme_ui_value bloom-dark ui accent; theme_ui_value bloom-dark term bg')"
assert_equals $'#455c67\n#101010' "$out" "reads [themes.bloom-dark.ui] accent + [.term] bg"

test_start "export_theme_colors_sets_dot_ui_env"
out="$(FAKE_UNAME=Linux FAKE_COLOR_SCHEME=prefer-dark in_ui '_ui_export_theme_colors; _ui_export_theme_colors; echo "$DOT_UI_ACCENT $DOT_UI_ERROR $DOT_UI_FG $DOT_UI_BG $_UI_COLORS_EXPORTED"')"
assert_equals "#455c67 #997d7a #f0f0f0 #101010 1" "$out" "DOT_UI_* exported from the active section (second call is a no-op)"

test_start "export_theme_colors_noop_without_section"
out="$(FAKE_CHEZMOI_SRC="$WORK/empty-src" in_ui '_ui_export_theme_colors; echo "rc=$? accent=${DOT_UI_ACCENT:-unset}"')"
assert_equals "rc=0 accent=unset" "$out" "no active section → returns 0 without exporting"

test_start "ui_pick_returns_dot_ui_selection"
out="$(printf 'alpha\nbeta\n' | DOT_UI_PICK_RC=0 in_ui 'ui_pick --header H --prompt P --ignored')"
assert_equals "alpha" "$out" "dot-ui pick rc=0 → prints the selection"
assert_file_contains "$WORK/dot-ui.calls" "pick --header H --prompt P" "header/prompt forwarded to dot-ui"

test_start "ui_pick_cancel_prints_nothing"
out="$(printf 'alpha\nbeta\n' | DOT_UI_PICK_RC=1 in_ui 'ui_pick; echo "rc=$?"')"
assert_equals "rc=0" "$out" "dot-ui pick rc=1 (cancel) → empty selection, rc=0"

test_start "ui_pick_falls_through_when_dot_ui_cannot_run_and_no_tty"
out="$(printf 'alpha\nbeta\n' | DOT_UI_PICK_RC=2 in_ui 'ui_pick; echo "rc=$?"')"
assert_equals "rc=0" "$out" "dot-ui rc=2 and no TTY → no fzf/gum, empty, rc=0"

test_start "ui_pick_honours_opt_outs"
out="$(printf 'alpha\n' | DOTFILES_NO_TUI=1 in_ui 'ui_pick; echo "rc=$?"')"
assert_equals "rc=0" "$out" "DOTFILES_NO_TUI=1 skips dot-ui entirely"

test_start "ui_confirm_default_no_noninteractive"
out="$(DOTFILES_NONINTERACTIVE=1 in_ui 'ui_confirm "Go?" n; echo "rc=$?"')"
assert_equals "rc=1" "$out" "non-interactive + default n → rc=1"

test_start "ui_steps_plain_mode_uses_stored_labels"
out="$(in_ui 'ui_steps_begin "Sync" ""; ui_step one "First" run; ui_step one "" ok "done"; ui_step two "" fail; ui_steps_end ""')"
assert_contains "First" "$out" "label stored on run and reused on ok"
assert_contains "two" "$out" "unknown id falls back to the id itself"

test_start "ui_table_end_without_header_is_noop"
out="$(in_ui 'ui_table_end; echo "rc=$?"')"
assert_equals "rc=0" "$out" "ui_table_end before ui_table_begin returns 0 silently"

test_start "ui_table_add_without_header_fails"
out="$(in_ui 'ui_table_add a b; echo "rc=$?"')"
assert_equals "rc=1" "$out" "ui_table_add before ui_table_begin returns 1"

test_start "ui_table_sep_before_header_draws_only_padding"
out="$(in_ui 'ui_table_sep' | cat -v)"
assert_equals "  " "$out" "no widths yet → just the two-space indent"

test_start "ui_progress_zero_total_is_noop"
out="$(in_ui 'ui_progress 3 0; echo "rc=$?"')"
assert_equals "rc=0" "$out" "total=0 short-circuits without printing"

test_start "ui_now_ms_is_numeric"
out="$(in_ui '_ui_now_ms')"
if [[ "$out" =~ ^[0-9]{12,}$ ]]; then _pass; else _fail "got '$out'"; fi

test_start "ui_json_esc_escapes_quotes_backslashes_newlines"
out="$(in_ui '_ui_json_esc "a\"b\\c
d	e"')"
assert_equals 'a\"b\\c d e' "$out" "quotes/backslashes escaped, newline+tab flattened"

test_start "ui_steps_emit_without_fd_is_noop"
out="$(in_ui '_UI_STEPS_FD=""; _ui_steps_emit "{}"; echo "rc=$?"')"
assert_equals "rc=0" "$out" "no renderer fd → returns 0"

test_start "ui_logo_dot_utf8_and_ascii_variants"
out="$(LC_ALL=C in_ui 'UI_UTF8=0; UI_INITED=1; ui_logo_dot "T"')"
assert_contains "DOTFILES" "$out" "non-UTF8 path prints plain DOTFILES"
out="$(in_ui 'UI_UTF8=1; UI_INITED=1; ui_logo_dot')"
assert_contains "◈ DOTFILES" "$out" "UTF-8 path prints the glyph logo"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
