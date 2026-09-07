#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for scripts/tools/emoji-picker.sh: the missing-list
# guard, the fzf picker, the `select` fallback when fzf is absent, the
# empty-selection exit and each clipboard backend it tries in turn
# (cb, pbcopy, wl-copy, xclip). `fzf` and every clipboard tool are
# PATH shims that record what they received, so nothing here needs a
# terminal or touches the real clipboard.
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

PICKER="$REPO_ROOT/scripts/tools/emoji-picker.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

LOG="$DOTFILES_COV_TMPDIR/clipboard.log"
: >"$LOG"

# Minimal PATH: the host's own fzf/pbcopy would otherwise decide which
# branch runs.
BASE="$DOTFILES_COV_TMPDIR/base"
mkdir -p "$BASE"
for _t in bash cat printf echo awk sed tr head command; do
  _p="$(command -v "$_t" 2>/dev/null || true)"
  [[ -n "$_p" ]] && ln -sf "$_p" "$BASE/$_t"
done

_shim() { # <dir> <name> [body…]
  local dir="$1" name="$2"
  shift 2
  mkdir -p "$dir"
  {
    echo '#!/usr/bin/env bash'
    printf 'printf "%s %%s\\n" "$*" >>"%s"\n' "$name" "$LOG"
    printf 'cat >>"%s" 2>/dev/null || true\n' "$LOG"
    printf '%s\n' "$@"
  } >"$dir/$name"
  chmod +x "$dir/$name"
}

EMOJI_LIST="$DOTFILES_COV_TMPDIR/emoji.txt"
printf '🚀 rocket\n🐛 bug\n✨ sparkles\n' >"$EMOJI_LIST"

_pick() { # <PATH> [stdin…]
  EMOJI_FILE="$EMOJI_LIST" PATH="$1" "$BASH_BIN" "$PICKER" 2>&1
}

test_start "emoji_picker_requires_an_emoji_list"
_out="$(EMOJI_FILE="$DOTFILES_COV_TMPDIR/absent.txt" PATH="$BASE" "$BASH_BIN" "$PICKER" 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "missing list exits 1"
assert_contains "Emoji list not found" "$_out" "the missing path is reported"

test_start "emoji_picker_uses_fzf_and_prints_only_the_glyph"
_d="$DOTFILES_COV_TMPDIR/pick-fzf"
_shim "$_d" fzf 'echo "🐛 bug"'
: >"$LOG"
_out="$(_pick "$_d:$BASE" </dev/null)"
_rc=$?
assert_equals 0 "$_rc" "a selection exits 0"
assert_equals "🐛" "$_out" "only the glyph is printed, not the label"
assert_file_contains "$LOG" "fzf --prompt=emoji>" "fzf was invoked with the picker prompt"

test_start "emoji_picker_copies_through_cb_when_present"
_d="$DOTFILES_COV_TMPDIR/pick-cb"
_shim "$_d" fzf 'echo "✨ sparkles"'
_shim "$_d" cb
: >"$LOG"
_out="$(_pick "$_d:$BASE" </dev/null)"
assert_equals 0 "$?" "copy path exits 0"
assert_equals "✨" "$_out" "glyph still printed"
assert_file_contains "$LOG" "✨" "cb received the glyph"

test_start "emoji_picker_falls_back_through_pbcopy_wl_copy_and_xclip"
for _backend in pbcopy wl-copy xclip; do
  _d="$DOTFILES_COV_TMPDIR/pick-$_backend"
  _shim "$_d" fzf 'echo "🚀 rocket"'
  _shim "$_d" "$_backend"
  : >"$LOG"
  _out="$(_pick "$_d:$BASE" </dev/null)"
  assert_equals "🚀" "$_out" "glyph printed with $_backend available"
  assert_file_contains "$LOG" "$_backend" "$_backend was chosen as the clipboard backend"
done

test_start "emoji_picker_still_prints_without_any_clipboard_tool"
_d="$DOTFILES_COV_TMPDIR/pick-noclip"
_shim "$_d" fzf 'echo "🐛 bug"'
_out="$(_pick "$_d:$BASE" </dev/null)"
assert_equals 0 "$?" "no clipboard backend still exits 0"
assert_equals "🐛" "$_out" "glyph printed to stdout"

test_start "emoji_picker_fails_when_nothing_is_selected"
_d="$DOTFILES_COV_TMPDIR/pick-empty"
_shim "$_d" fzf 'exit 130'
_out="$(_pick "$_d:$BASE" </dev/null)"
_rc=$?
assert_equals 1 "$_rc" "an aborted picker exits 1"
assert_equals "" "$_out" "nothing is printed"

test_start "emoji_picker_falls_back_to_select_without_fzf"
# No fzf on PATH: the `select` menu reads the choice number from stdin.
_out="$(printf '2\n' | _pick "$BASE")"
_rc=$?
assert_equals 0 "$_rc" "select fallback exits 0"
assert_contains "🐛" "$_out" "the numbered choice resolves to its glyph"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
