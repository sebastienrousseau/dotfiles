#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# _load_theme_fields reads themes.toml as data: a value that holds shell
# syntax is assigned literally and never executed.
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"
mkdir -p "$TMPHOME/dotfiles/.chezmoidata"
export CHEZMOI_SOURCE_DIR="$TMPHOME/dotfiles"
touch "$TMPHOME/dotfiles/.chezmoidata.toml"
MARK="$TMPHOME/MARK"
MARK2="$TMPHOME/MARK2"
MARK3="$TMPHOME/MARK3"
cat >"$TMPHOME/dotfiles/.chezmoidata/themes.toml" <<TOML
[themes.Evil-dark]
mode = "dark\$(touch $MARK)"
family = "Evil; touch $MARK2"
wallpaper = "/w/x\$(touch $MARK).jpg"
macos_accent = "\`touch $MARK3\`"

[themes.Evil-dark.app]
gtk_theme = "Adwaita; touch $MARK2"
gtk_icon = "\`touch $MARK3\`"
gnome_shell = "shell\$(touch $MARK)"
mono_font = "JetBrains Mono 11"
ui_font = "Inter a=b 10"
document_font = "Doc Font"

[themes.Plain-light]
mode = "light"
TOML

source "$REPO_ROOT/bin/dot-theme-sync"

test_start "loader_does_not_execute_shell_syntax_in_values"
_load_theme_fields "Evil-dark"
assert_false "[[ -e '$MARK' ]]" "no \$() substitution ran"
assert_false "[[ -e '$MARK2' ]]" "no ; command ran"
assert_false "[[ -e '$MARK3' ]]" "no backtick command ran"

test_start "loader_assigns_values_literally"
assert_equals "/w/x\$(touch $MARK).jpg" "$TH_WALLPAPER" "wallpaper is byte for byte"
assert_equals "dark\$(touch $MARK)" "$TH_MODE" "mode is literal"
assert_equals "Evil; touch $MARK2" "$TH_FAMILY" "family is literal"
assert_equals "\`touch $MARK3\`" "$TH_MACOS_ACCENT" "accent is literal"
assert_equals "Adwaita; touch $MARK2" "$TH_GTK_THEME" "gtk theme is literal"
assert_equals "\`touch $MARK3\`" "$TH_GTK_ICON" "gtk icon is literal"
assert_equals "shell\$(touch $MARK)" "$TH_GNOME_SHELL" "gnome shell is literal"

test_start "loader_round_trips_spaces_and_equals"
assert_equals "JetBrains Mono 11" "$TH_MONO_FONT" "value with spaces"
assert_equals "Inter a=b 10" "$TH_UI_FONT" "value with = inside"
assert_equals "Doc Font" "$TH_DOC_FONT" "document font"

test_start "loader_resets_fields_for_the_next_theme"
_load_theme_fields "Plain-light"
assert_equals "light" "$TH_MODE" "mode of the next theme"
assert_equals "" "$TH_WALLPAPER" "wallpaper cleared"
assert_equals "" "$TH_UI_FONT" "app field cleared"

test_start "loader_assigns_at_global_scope"
_caller() { _load_theme_fields "Evil-dark"; }
TH_MODE=""
_caller
assert_equals "dark\$(touch $MARK)" "$TH_MODE" "visible after the call returns"

test_start "loader_assigns_only_the_keys_it_knows"
# An extractor that emits a foreign key must not reach that variable.
EVIL_VAR="untouched"
awk() { printf 'EVIL_VAR=pwned\n\nTH_MODE=ok\n'; }
_load_theme_fields "Plain-light"
unset -f awk
assert_equals "ok" "$TH_MODE" "known key assigned"
assert_equals "untouched" "$EVIL_VAR" "unknown key ignored"

test_summary
