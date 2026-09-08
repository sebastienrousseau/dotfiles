#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for scripts/theme/switch.sh: every subcommand, the
# light/dark toggle, family cycling, system-appearance sync on both
# platforms, the interactive picker, and the guards for a missing source
# tree or data file.
#
# The script runs from its real location against a synthetic chezmoi source
# tree (CHEZMOI_SOURCE_DIR), so nothing reads or writes the real dotfiles.
# dot-theme-sync is a recording stub, so no theme is ever applied; the
# rebuild hand-off is intercepted through a PATH-shadowed bash.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/theme/switch.sh"
REAL_BASH="${BASH:-$(command -v bash)}"
REAL_UNAME="$(command -v uname)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/theme/switch.sh must exist"

_pass() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
}
_fail() {
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $1"
}

# ---------------------------------------------------------------------------
# Synthetic chezmoi source tree, with the .chezmoiroot indirection the real
# repo uses. Three families: two paired (dark+light), one dark-only, plus the
# synthetic `fallback` family the switcher must always hide.
# ---------------------------------------------------------------------------
SRC="$WORK/src"
mkdir -p "$SRC/defaults/.chezmoidata"
echo "defaults" >"$SRC/.chezmoiroot"
DATA_FILE="$SRC/defaults/.chezmoidata.toml"
THEMES_FILE="$SRC/defaults/.chezmoidata/themes.toml"
printf 'theme = "bloom-dark"\n' >"$DATA_FILE"
cat >"$THEMES_FILE" <<'TOML'
[themes.bloom-dark]
family = "bloom"
mode = "dark"

[themes.bloom-light]
family = "bloom"
mode = "light"

[themes.maui-dark]
family = "maui"
mode = "dark"

[themes.maui-light]
family = "maui"
mode = "light"

[themes.solo-dark]
family = "solo"
mode = "dark"

[themes.fallback-dark]
family = "fallback"
mode = "dark"

[themes.fallback-light]
family = "fallback"
mode = "light"
TOML

WALLPAPERS="$WORK/wallpapers"
mkdir -p "$WALLPAPERS"
: >"$WALLPAPERS/maui.heic" # makes the maui family "Custom"

# ---------------------------------------------------------------------------
# Stubs
# ---------------------------------------------------------------------------
SYNC_CALLS="$WORK/theme-sync.calls"
cat >"$BIN/dot-theme-sync" <<EOF
#!$REAL_BASH
printf '%s\n' "\$*" >>"$SYNC_CALLS"
echo "theme-sync applied \$*"
exit 0
EOF
cat >"$BIN/uname" <<EOF
#!$REAL_BASH
if [[ -n "\${FAKE_UNAME:-}" && "\${1:-}" == "-s" ]]; then echo "\$FAKE_UNAME"; exit 0; fi
exec "$REAL_UNAME" "\$@"
EOF
cat >"$BIN/defaults" <<EOF
#!$REAL_BASH
[[ "\${1:-}" == read ]] || exit 0
[[ "\${FAKE_APPLE_DARK:-0}" == "1" ]] || exit 1
echo Dark
EOF
cat >"$BIN/gsettings" <<EOF
#!$REAL_BASH
[[ "\${1:-}" == get ]] && printf "'%s'\n" "\${FAKE_COLOR_SCHEME:-prefer-dark}"
exit 0
EOF
# The picker: dot-ui pick echoes the row the test asked for.
cat >"$BIN/dot-ui" <<EOF
#!$REAL_BASH
if [[ "\${1:-}" == pick ]]; then
  input="\$(cat)"
  [[ -n "\${FAKE_PICK:-}" ]] && printf '%s\n' "\$FAKE_PICK"
  exit "\${FAKE_PICK_RC:-0}"
fi
exit 0
EOF
# switch.sh hands `rebuild` off with `bash <script-dir>/rebuild-themes.sh`;
# `bash` resolves through PATH, so a shim can answer for it and exec the real
# interpreter for everything else. The real rebuild-themes.sh scans the
# host's wallpapers and rewrites theme data — it must never run here.
cat >"$BIN/bash" <<EOF
#!$REAL_BASH
case "\${1:-}" in
  *rebuild-themes.sh)
    printf 'rebuild-invoked %s\n' "\${*:2}"
    exit 0
    ;;
esac
exec "$REAL_BASH" "\$@"
EOF
chmod +x "$BIN/dot-theme-sync" "$BIN/uname" "$BIN/defaults" "$BIN/gsettings" \
  "$BIN/dot-ui" "$BIN/bash"

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
# switch <args…> — run the theme switcher against the synthetic source tree.
# Stdout is captured; stderr is replayed onto fd 2 so the coverage runner
# still receives the xtrace records. Echoes the exit status.
switch() {
  local rc=0
  CHEZMOI_SOURCE_DIR="$SRC" \
    DOTFILES_WALLPAPER_DIR="$WALLPAPERS" \
    PATH="$BIN:/usr/bin:/bin" \
    "$REAL_BASH" "$SCRIPT_FILE" "$@" </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}
set_theme_to() { printf 'theme = "%s"\n' "$1" >"$DATA_FILE"; }
last_sync() { tail -n 1 "$SYNC_CALLS" 2>/dev/null; }

# ===========================================================================
# Listing and current state
# ===========================================================================
test_start "list_shows_only_paired_families"
set_theme_to bloom-dark
: >"$SYNC_CALLS"
rc="$(switch list)"
assert_equals "0" "$rc" "list exits 0"
assert_file_contains "$OUT" "bloom" "the paired bloom family is listed"
assert_file_contains "$OUT" "maui" "the paired maui family is listed"
assert_output_not_contains "solo" "cat '$OUT'"
assert_output_not_contains "fallback" "cat '$OUT'"

test_start "list_labels_wallpaper_provenance"
assert_file_contains "$OUT" "Custom" "a family with a wallpaper file is Custom"
assert_file_contains "$OUT" "System" "a family without one is System"

test_start "list_marks_the_active_family"
assert_file_contains "$OUT" "◀" "the active family is flagged"

test_start "current_reports_theme_family_and_mode"
rc="$(switch current)"
assert_equals "0" "$rc" "current exits 0"
assert_file_contains "$OUT" "bloom-dark (bloom, dark)" "current names the theme, family and mode"

test_start "current_reports_light_mode"
set_theme_to bloom-light
switch current >/dev/null
assert_file_contains "$OUT" "bloom-light (bloom, light)" "a light theme is reported as light"

test_start "current_prefers_the_machine_local_chezmoi_override"
mkdir -p "$XDG_CONFIG_HOME/chezmoi"
printf 'theme = "maui-dark"\n' >"$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"
switch current >/dev/null
assert_file_contains "$OUT" "maui-dark" "the chezmoi.toml override wins over .chezmoidata.toml"
rm -f "$XDG_CONFIG_HOME/chezmoi/chezmoi.toml"

# ===========================================================================
# Explicit selection
# ===========================================================================
test_start "set_delegates_to_dot_theme_sync"
set_theme_to bloom-dark
: >"$SYNC_CALLS"
rc="$(switch set maui-light)"
assert_equals "0" "$rc" "set exits 0"
assert_equals "maui-light" "$(last_sync)" "the requested theme is handed to dot-theme-sync"

test_start "a_bare_theme_name_is_treated_as_a_quick_switch"
: >"$SYNC_CALLS"
rc="$(switch maui-dark)"
assert_equals "0" "$rc" "a known theme name exits 0"
assert_equals "maui-dark" "$(last_sync)" "the theme name is handed to dot-theme-sync"

test_start "an_unknown_argument_is_rejected"
: >"$SYNC_CALLS"
rc="$(switch definitely-not-a-theme)"
assert_equals "1" "$rc" "an unknown argument fails"
assert_file_contains "$OUT" "Unknown command or theme" "the error explains the rejection"
assert_empty "$(last_sync)" "nothing is applied for an unknown argument"

# ===========================================================================
# Toggle and family cycling
# ===========================================================================
test_start "toggle_switches_dark_to_light"
set_theme_to bloom-dark
: >"$SYNC_CALLS"
switch toggle >/dev/null
assert_equals "bloom-light" "$(last_sync)" "a dark theme toggles to its light pair"

test_start "toggle_switches_light_to_dark"
set_theme_to bloom-light
: >"$SYNC_CALLS"
switch toggle >/dev/null
assert_equals "bloom-dark" "$(last_sync)" "a light theme toggles to its dark pair"

test_start "toggle_from_an_unsuffixed_theme_uses_the_default_pair"
set_theme_to plain
: >"$SYNC_CALLS"
switch toggle >/dev/null
assert_equals "bloom-dark" "$(last_sync)" "an unsuffixed theme falls back to the default dark theme"

test_start "family_cycles_to_the_next_paired_family"
set_theme_to bloom-dark
: >"$SYNC_CALLS"
switch family >/dev/null
assert_equals "maui-dark" "$(last_sync)" "bloom cycles to maui, preserving the mode"

test_start "family_wraps_around_and_preserves_light_mode"
set_theme_to maui-light
: >"$SYNC_CALLS"
switch family >/dev/null
assert_equals "bloom-light" "$(last_sync)" "the last family wraps to the first, staying light"

test_start "family_from_an_unknown_family_starts_at_the_first"
set_theme_to solo-dark
: >"$SYNC_CALLS"
switch family >/dev/null
assert_equals "bloom-dark" "$(last_sync)" "a family with no pair starts the cycle over"

# ===========================================================================
# System-appearance sync
# ===========================================================================
test_start "sync_follows_a_light_macos_appearance"
set_theme_to bloom-dark
: >"$SYNC_CALLS"
FAKE_UNAME=Darwin FAKE_APPLE_DARK=0 switch sync >/dev/null
assert_file_contains "$OUT" "System is light" "the light system appearance is announced"
assert_equals "bloom-light" "$(last_sync)" "dotfiles follow macOS into light mode"

test_start "sync_follows_a_dark_macos_appearance"
set_theme_to bloom-light
: >"$SYNC_CALLS"
FAKE_UNAME=Darwin FAKE_APPLE_DARK=1 switch sync >/dev/null
assert_file_contains "$OUT" "System is dark" "the dark system appearance is announced"
assert_equals "bloom-dark" "$(last_sync)" "dotfiles follow macOS into dark mode"

test_start "sync_follows_a_light_gnome_colour_scheme"
set_theme_to bloom-dark
: >"$SYNC_CALLS"
FAKE_UNAME=Linux FAKE_COLOR_SCHEME=prefer-light switch sync >/dev/null
assert_equals "bloom-light" "$(last_sync)" "GNOME's prefer-light is honoured"

test_start "sync_is_a_no_op_when_already_matching"
set_theme_to bloom-dark
: >"$SYNC_CALLS"
FAKE_UNAME=Linux FAKE_COLOR_SCHEME=prefer-dark switch sync >/dev/null
assert_file_contains "$OUT" "already match" "a matching system needs no change"
assert_empty "$(last_sync)" "nothing is applied when the modes already agree"

# ===========================================================================
# Interactive picker
# ===========================================================================
test_start "the_picker_applies_the_selected_family"
set_theme_to bloom-dark
: >"$SYNC_CALLS"
rc="$(FAKE_PICK="○  maui                                 Custom" switch)"
assert_equals "0" "$rc" "the picker exits 0"
assert_equals "maui-dark" "$(last_sync)" "the picked family is applied in the current mode"

test_start "picking_the_active_family_changes_nothing"
set_theme_to bloom-dark
: >"$SYNC_CALLS"
FAKE_PICK="✓  bloom                                System  dark" switch >/dev/null
assert_file_contains "$OUT" "already on bloom-dark" "re-picking the active family is reported, not re-applied"
assert_empty "$(last_sync)" "no theme is applied"

test_start "cancelling_the_picker_applies_nothing"
: >"$SYNC_CALLS"
rc="$(FAKE_PICK="" FAKE_PICK_RC=1 switch)"
assert_equals "0" "$rc" "a cancelled pick still exits 0"
assert_empty "$(last_sync)" "cancelling applies nothing"

test_start "set_with_an_empty_name_opens_the_picker"
set_theme_to bloom-dark
: >"$SYNC_CALLS"
rc="$(FAKE_PICK="○  maui                                 Custom" switch set "")"
assert_equals "0" "$rc" "set with an empty name exits 0"
assert_equals "maui-dark" "$(last_sync)" "an empty name falls through to the interactive picker"

test_start "a_theme_absent_from_themes_toml_falls_back_to_suffix_stripping"
# get_theme_family cannot read a family for an unlisted theme, so it strips
# the -dark/-light suffix instead.
set_theme_to ghost-light
rc="$(switch current)"
assert_equals "0" "$rc" "an unlisted theme still reports"
assert_file_contains "$OUT" "ghost-light (ghost, light)" "the family is derived from the name"

test_start "family_falls_back_to_the_default_when_nothing_is_paired"
UNPAIRED_SRC="$WORK/unpaired-src"
mkdir -p "$UNPAIRED_SRC/.chezmoidata"
printf 'theme = "solo-dark"\n' >"$UNPAIRED_SRC/.chezmoidata.toml"
printf '[themes.solo-dark]\nfamily = "solo"\nmode = "dark"\n' \
  >"$UNPAIRED_SRC/.chezmoidata/themes.toml"
: >"$SYNC_CALLS"
rc=0
CHEZMOI_SOURCE_DIR="$UNPAIRED_SRC" DOTFILES_WALLPAPER_DIR="$WALLPAPERS" \
  PATH="$BIN:/usr/bin:/bin" \
  "$REAL_BASH" "$SCRIPT_FILE" family >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "0" "$rc" "family exits 0 with no paired families"
assert_equals "bloom-dark" "$(last_sync)" "with nothing to cycle, the default dark theme is applied"

# ===========================================================================
# Help and rebuild
# ===========================================================================
test_start "help_lists_the_commands_and_current_theme"
set_theme_to bloom-dark
for flag in help --help -h; do
  rc="$(switch "$flag")"
  assert_equals "0" "$rc" "$flag exits 0"
done
assert_file_contains "$OUT" "Interactive theme picker" "the picker is documented"
assert_file_contains "$OUT" "bloom-dark" "help ends with the current theme"

test_start "rebuild_delegates_to_the_theme_rebuilder"
rc="$(switch rebuild --force)"
assert_equals "0" "$rc" "rebuild exits 0"
assert_file_contains "$OUT" "rebuild-invoked --force" "arguments are forwarded to rebuild-themes.sh"

test_start "the_family_listing_works_on_the_system_bash"
# Regression: paired_families used two associative arrays. `local -A` is a
# hard error on bash 3.2 — still /bin/bash on macOS and what the macOS CI
# runner resolves — so both stayed empty and `dot theme list`, `dot theme
# family` and the picker silently offered nothing. Re-run the listing under
# /bin/bash explicitly so the regression cannot come back unnoticed.
if [[ -x /bin/bash ]]; then
  set_theme_to bloom-dark
  rc=0
  CHEZMOI_SOURCE_DIR="$SRC" DOTFILES_WALLPAPER_DIR="$WALLPAPERS" \
    PATH="$BIN:/usr/bin:/bin" \
    /bin/bash "$SCRIPT_FILE" list </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  assert_equals "0" "$rc" "the listing exits 0 under $(/bin/bash -c 'echo bash ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}')"
  assert_file_contains "$OUT" "bloom" "paired families are listed under the system bash"
  assert_file_contains "$OUT" "maui" "every paired family is listed under the system bash"
  assert_output_not_contains "invalid option" "cat '$ERR'"
else
  _fail "/bin/bash not found"
fi

# ===========================================================================
# Guards
# ===========================================================================
test_start "a_missing_data_file_is_fatal"
EMPTY_SRC="$WORK/empty-src"
mkdir -p "$EMPTY_SRC"
rc=0
CHEZMOI_SOURCE_DIR="$EMPTY_SRC" PATH="$BIN:/usr/bin:/bin" \
  "$REAL_BASH" "$SCRIPT_FILE" list >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "1" "$rc" "a source tree without .chezmoidata.toml is fatal"
assert_file_contains "$OUT" "Missing" "the error names the missing file"

test_start "a_missing_source_tree_is_fatal"
rc=0
HOME="$WORK/nohome" CHEZMOI_SOURCE_DIR="" PATH="$BIN:/usr/bin:/bin" \
  "$REAL_BASH" "$SCRIPT_FILE" list >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "1" "$rc" "no chezmoi source anywhere is fatal"
assert_file_contains "$OUT" "not found" "the error says the source was not found"

test_start "the_legacy_chezmoi_source_location_is_honoured"
LEGACY_HOME="$WORK/legacy-home"
mkdir -p "$LEGACY_HOME/.local/share/chezmoi/.chezmoidata"
printf 'theme = "bloom-dark"\n' >"$LEGACY_HOME/.local/share/chezmoi/.chezmoidata.toml"
cp "$THEMES_FILE" "$LEGACY_HOME/.local/share/chezmoi/.chezmoidata/themes.toml"
rc=0
HOME="$LEGACY_HOME" CHEZMOI_SOURCE_DIR="" DOTFILES_WALLPAPER_DIR="$WALLPAPERS" \
  PATH="$BIN:/usr/bin:/bin" \
  "$REAL_BASH" "$SCRIPT_FILE" current >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "0" "$rc" "the legacy chezmoi source location is found when the dotfiles dir is absent"
assert_file_contains "$OUT" "bloom-dark" "the legacy tree's theme is reported"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
