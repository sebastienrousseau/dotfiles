#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC2034
# Behavioural coverage for scripts/theme/switch.sh — the desktop-facing and
# scheduling subcommands: ambient (run/enable/disable/status), rotate, reset,
# diff, export, import, fit, wallpaper, accent and status.
#
# Hermetic: HOME/XDG dirs live in a mktemp sandbox, CHEZMOI_SOURCE_DIR points
# at a synthetic source tree, and PATH is built only from recording stubs plus
# a symlinked toolbox of core utilities, so no host desktop tool, systemd unit
# or real dotfiles checkout is ever touched.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/theme/switch.sh"
REAL_BASH="${BASH:-$(command -v bash)}"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/theme-switch-cov.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME/dot"
unset NO_COLOR DOT_THEME_SUNRISE DOT_THEME_SUNSET DOT_THEME_LOCATION \
  XDG_CURRENT_DESKTOP DESKTOP_SESSION CHEZMOI_SOURCE_DIR

# ---------------------------------------------------------------------------
# Toolbox: only core utilities, so desktop tools on the host stay invisible.
# ---------------------------------------------------------------------------
TOOLS="$WORK/tools"
mkdir -p "$TOOLS"
for t in awk sed grep sort comm head tail tr cut mktemp mv cat date hostname \
  dirname realpath readlink rm mkdir locale; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" && "$p" == /* ]] && ln -s "$p" "$TOOLS/$t"
done

# ---------------------------------------------------------------------------
# Synthetic chezmoi source tree.
# ---------------------------------------------------------------------------
SRC="$WORK/src"
mkdir -p "$SRC/.chezmoidata"
DATA_FILE="$SRC/.chezmoidata.toml"
THEMES_FILE="$SRC/.chezmoidata/themes.toml"
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
TOML
WALLPAPERS="$WORK/wallpapers"
mkdir -p "$WALLPAPERS"

set_theme_to() {
  local theme="$1" mode="${2-auto}"
  printf 'theme = "%s"\ntheme_mode = "%s"\n' "$theme" "$mode" >"$DATA_FILE"
}

# ---------------------------------------------------------------------------
# Stubs — each in its own directory so a scenario chooses which exist.
# ---------------------------------------------------------------------------
STUBS="$WORK/stubs"
CALLS="$WORK/calls"
mkdir -p "$CALLS"
mkstub() {
  mkdir -p "$STUBS/$1"
  {
    printf '#!%s\n' "$REAL_BASH"
    printf 'CALLS=%q\n' "$CALLS"
    cat
  } >"$STUBS/$1/$1"
  chmod +x "$STUBS/$1/$1"
}
mkstub dot-theme-sync <<'EOF'
printf '%s\n' "$*" >>"$CALLS/sync"
echo "theme-sync $*"
exit "${FAKE_SYNC_RC:-0}"
EOF
mkstub uname <<'EOF'
[[ "${1:-}" == -s ]] && { echo "${FAKE_UNAME:-Linux}"; exit 0; }
echo "${FAKE_UNAME:-Linux}"
EOF
mkstub defaults <<'EOF'
[[ "${FAKE_APPLE_DARK:-1}" == 1 ]] && { echo Dark; exit 0; }
exit 1
EOF
mkstub gsettings <<'EOF'
printf '%s\n' "$*" >>"$CALLS/gsettings"
[[ "${1:-}" == get ]] && printf "'%s'\n" "${FAKE_COLOR_SCHEME:-prefer-dark}"
exit 0
EOF
mkstub kreadconfig6 <<'EOF'
echo "${FAKE_KDE_SCHEME:-BreezeDark}"
EOF
mkstub systemctl <<'EOF'
printf '%s\n' "$*" >>"$CALLS/systemctl"
case "$*" in
  *is-active*) exit "${FAKE_TIMER_RC:-3}" ;;
  *list-timers*) printf 'NEXT LEFT\n\nMon 10:00 5min dot-theme.timer\n' ;;
esac
exit 0
EOF
mkstub sunwait <<'EOF'
case "${2:-}" in
  rise) echo "${FAKE_RISE:-00:00}" ;;
  set) echo "${FAKE_SET:-00:00}" ;;
esac
EOF
mkstub dot <<'EOF'
exit 0
EOF

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
# sw <args…> — run switch.sh with the stubs named in $USE (default set below)
# first on PATH. Stdout goes to $OUT; stderr is replayed so any xtrace
# records still reach the coverage runner. Echoes the exit status.
DEFAULT_USE="dot-theme-sync uname defaults gsettings systemctl"
sw() {
  local rc=0 path="" s
  for s in ${USE-$DEFAULT_USE}; do path="$path$STUBS/$s:"; done
  CHEZMOI_SOURCE_DIR="${SRC_OVERRIDE:-$SRC}" DOTFILES_WALLPAPER_DIR="$WALLPAPERS" \
    PATH="$path$TOOLS" "$REAL_BASH" "$SCRIPT_FILE" "$@" \
    <"${STDIN_FILE:-/dev/null}" >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}
reset_calls() { rm -f "$CALLS"/*; }
last_sync() { tail -n 1 "$CALLS/sync" 2>/dev/null; }

# Richer desktop stubs for this file (override the simpler ones above).
cat >>"$THEMES_FILE" <<'TOML'

[themes.maui-dark.ui]
accent = "#8aadf4"

[themes.maui-dark.term]
bg = "#1e2030"
fg = "#cad3f5"

[themes.maui-light.ui]
accent = "#1e66f5"

[themes.maui-light.term]
bg = "#eff1f5"
fg = "#4c4f69"

[other]
key = "ignored"
TOML
mkstub gsettings <<'EOF'
printf '%s\n' "$*" >>"$CALLS/gsettings"
if [[ "${1:-}" == get ]]; then
  case "${3:-}" in
    color-scheme) printf "'%s'\n" "${FAKE_COLOR_SCHEME:-prefer-dark}" ;;
    picture-uri | picture-uri-dark) printf "'file:///walls/%s.jpg'\n" "$3" ;;
    *) printf "'gs-%s'\n" "${3:-}" ;;
  esac
  exit 0
fi
[[ "${1:-}" == set ]] && exit "${FAKE_GS_SET_RC:-0}"
exit 0
EOF
mkstub kreadconfig6 <<'EOF'
case "$*" in
  *AccentColor*) echo "#3daee9" ;;
  *) echo "${FAKE_KDE_SCHEME:-BreezeDark}" ;;
esac
EOF
for s in kwriteconfig6 qdbus plasma-apply-wallpaperimage; do
  mkstub "$s" <<EOF
printf '%s\n' "$s \$*" >>"\$CALLS/desktop"
exit 0
EOF
done
mkstub xfconf-query <<'EOF'
printf '%s\n' "xfconf-query $*" >>"$CALLS/desktop"
if [[ "$*" == *" -l"* ]]; then
  printf '/backdrop/screen0/monitor0/workspace0/last-image\n/backdrop/other\n'
fi
exit 0
EOF

# ===========================================================================
# ambient
# ===========================================================================
AMB_STATE="$XDG_STATE_HOME/dot/theme-ambient.conf"
UNITS="$XDG_CONFIG_HOME/systemd/user"

test_start "ambient_env_window_selects_light"
set_theme_to bloom-dark
rm -f "$AMB_STATE"
reset_calls
rc="$(DOT_THEME_SUNRISE=00:00 DOT_THEME_SUNSET=24:00 sw ambient)"
assert_equals "0" "$rc" "ambient exits 0"
assert_file_contains "$OUT" "env sunrise=00:00" "the env source is reported"
assert_equals "bloom-light" "$(last_sync)" "daytime selects the light variant"

test_start "ambient_reports_an_already_matching_variant"
set_theme_to bloom-dark
reset_calls
rc="$(DOT_THEME_SUNRISE=00:00 DOT_THEME_SUNSET=00:00 sw ambient run)"
assert_equals "0" "$rc" "ambient exits 0"
assert_file_contains "$OUT" "already matches" "no change is needed at night"
assert_empty "$(last_sync)" "nothing is applied"

test_start "ambient_uses_sunwait_with_a_location"
set_theme_to bloom-dark
reset_calls
USE="$DEFAULT_USE sunwait" FAKE_RISE=00:00 FAKE_SET=00:00 DOT_THEME_LOCATION="51.5N,0.13W" \
  sw ambient >/dev/null
assert_file_contains "$OUT" "sunwait(51.5N,0.13W)" "the sunwait source is reported"

test_start "ambient_ignores_bad_sunwait_output_and_half_locations"
USE="$DEFAULT_USE sunwait" FAKE_RISE=soon FAKE_SET=later DOT_THEME_LOCATION="1N,1E" \
  sw ambient >/dev/null
assert_file_contains "$OUT" "defaults sunrise=07:00" "invalid sunwait output falls back to defaults"
USE="$DEFAULT_USE sunwait" DOT_THEME_LOCATION="51.5N," sw ambient >/dev/null
assert_file_contains "$OUT" "defaults sunrise=07:00" "a location without longitude is ignored"

test_start "ambient_reads_the_state_file"
printf 'sunrise=00:00\nsunset=24:00\n' >"$AMB_STATE"
set_theme_to bloom-dark
reset_calls
rc="$(sw ambient)"
assert_equals "0" "$rc" "ambient exits 0 with a state file"
assert_file_contains "$OUT" "state-file sunrise=00:00" "the state-file source is reported"
assert_equals "bloom-light" "$(last_sync)" "the state-file window is honoured"

test_start "ambient_survives_an_empty_or_partial_state_file"
# Regression: the state-file fallback expanded $DOT_THEME_SUNRISE and
# $DOT_THEME_SUNSET unguarded, so under `set -u` an empty state file — or one
# setting only one of the two times — aborted with "unbound variable"
# instead of falling back to the defaults.
: >"$AMB_STATE"
rc="$(sw ambient)"
assert_equals "0" "$rc" "an empty state file does not abort"
assert_file_contains "$OUT" "defaults sunrise=07:00 sunset=19:00" "the defaults apply"
assert_output_not_contains "unbound variable" "cat '$ERR'"
printf 'DOT_THEME_SUNRISE=00:00\n' >"$AMB_STATE"
rc="$(sw ambient)"
assert_equals "0" "$rc" "a partial state file does not abort"
assert_file_contains "$OUT" "state-file sunrise=00:00 sunset=19:00" "the missing time defaults"
rm -f "$AMB_STATE"

test_start "ambient_enable_and_disable_manage_units"
reset_calls
rc="$(USE="$DEFAULT_USE dot" sw ambient enable)"
assert_equals "0" "$rc" "ambient enable exits 0"
assert_file_contains "$UNITS/dot-theme-ambient.service" "$STUBS/dot/dot theme ambient" "the unit runs the dot on PATH"
assert_file_contains "$CALLS/systemctl" "--user enable --now dot-theme-ambient.timer" "the timer is enabled"
rc="$(sw ambient disable)"
assert_equals "0" "$rc" "ambient disable exits 0"
assert_false "[[ -e '$UNITS/dot-theme-ambient.timer' ]]" "the timer unit is removed"
assert_file_contains "$CALLS/systemctl" "--user disable --now dot-theme-ambient.timer" "the timer is disabled"

test_start "ambient_status_reports_times_and_timer"
printf 'sunrise=06:15\nsunset=20:45\n' >"$AMB_STATE"
rc="$(FAKE_TIMER_RC=0 sw ambient status)"
assert_equals "0" "$rc" "ambient status exits 0"
assert_file_contains "$OUT" "06:15" "the state-file sunrise is shown"
assert_file_contains "$OUT" "20:45" "the state-file sunset is shown"
assert_file_contains "$OUT" "dot-theme.timer" "active timers are listed"
rm -f "$AMB_STATE"
rc="$(sw ambient status)"
assert_file_contains "$OUT" "07:00 (default)" "the default sunrise is shown"
assert_file_contains "$OUT" "inactive" "an inactive timer is reported"

test_start "ambient_rejects_unknown_subcommands"
rc="$(sw ambient bogus)"
assert_equals "1" "$rc" "an unknown ambient subcommand fails"
assert_file_contains "$OUT" "ambient subcommand 'bogus'" "the subcommand is named"

# ===========================================================================
# rotate
# ===========================================================================
test_start "rotate_enable_writes_units_with_interval"
reset_calls
rc="$(sw rotate enable 5m)"
assert_equals "0" "$rc" "rotate enable exits 0"
assert_file_contains "$UNITS/dot-theme-rotate.timer" "OnUnitActiveSec=5m" "the interval is written"
assert_file_contains "$UNITS/dot-theme-rotate.service" "$HOME/.local/bin/dot theme random" "the unit falls back to ~/.local/bin/dot"
assert_file_contains "$CALLS/systemctl" "--user enable --now dot-theme-rotate.timer" "the timer is enabled"
rc="$(sw rotate)"
assert_file_contains "$UNITS/dot-theme-rotate.timer" "OnUnitActiveSec=30m" "no argument enables the 30m default"

test_start "rotate_status_and_disable"
rc="$(FAKE_TIMER_RC=0 sw rotate status)"
assert_equals "0" "$rc" "rotate status exits 0"
assert_file_contains "$OUT" "dot-theme.timer" "an active timer is listed"
rc="$(sw rotate status)"
assert_file_contains "$OUT" "inactive" "an inactive timer is reported"
rc="$(sw rotate disable)"
assert_equals "0" "$rc" "rotate disable exits 0"
assert_false "[[ -e '$UNITS/dot-theme-rotate.timer' ]]" "the timer unit is removed"

test_start "rotate_rejects_unknown_subcommands"
rc="$(sw rotate bogus)"
assert_equals "1" "$rc" "an unknown rotate subcommand fails"
assert_file_contains "$OUT" "dot theme rotate" "usage is printed"

# ===========================================================================
# reset / diff
# ===========================================================================
test_start "reset_restores_gnome_defaults"
reset_calls
rc="$(sw reset)"
assert_equals "0" "$rc" "reset exits 0"
assert_file_contains "$CALLS/gsettings" "reset org.gnome.desktop.interface accent-color" "accent is reset"
assert_file_contains "$CALLS/gsettings" "set org.gnome.shell.extensions.user-theme name" "shell theme is cleared"
rc="$(USE="uname" sw reset)"
assert_equals "0" "$rc" "reset without gsettings still exits 0"
assert_file_contains "$OUT" "wallpaper untouched" "the note is printed"

test_start "diff_validates_its_arguments"
rc="$(sw diff maui-dark)"
assert_equals "1" "$rc" "diff needs two themes"
assert_file_contains "$OUT" "dot theme diff <theme-a> <theme-b>" "usage is printed"
rc="$(sw diff nope-dark maui-dark)"
assert_equals "1" "$rc" "an unknown first theme fails"
assert_file_contains "$OUT" "theme 'nope-dark'" "the first theme is named"
rc="$(sw diff maui-dark nope-light)"
assert_equals "1" "$rc" "an unknown second theme fails"
assert_file_contains "$OUT" "theme 'nope-light'" "the second theme is named"

test_start "diff_compares_two_themes"
rc="$(sw diff maui-dark maui-light)"
assert_equals "0" "$rc" "diff exits 0"
assert_file_contains "$OUT" "Theme diff: maui-dark  vs  maui-light" "the header names both themes"
assert_file_contains "$OUT" "#8aadf4" "the left accent is shown"
assert_file_contains "$OUT" "#1e66f5" "the right accent is shown"
assert_file_contains "$OUT" "≠" "differences are flagged"

# ===========================================================================
# export / import
# ===========================================================================
test_start "export_prints_json_to_stdout"
set_theme_to maui-dark
rc="$(sw export)"
assert_equals "0" "$rc" "export exits 0"
assert_file_contains "$OUT" '"theme": "maui-dark"' "the theme is exported"
assert_file_contains "$OUT" '"fit": "gs-picture-options"' "the GNOME fit is exported"

test_start "export_writes_a_file"
rc="$(USE="uname" sw export "$WORK/snap.json")"
assert_equals "0" "$rc" "export to a file exits 0"
assert_file_contains "$WORK/snap.json" '"fit": ""' "without gsettings the fit is empty"
assert_file_contains "$OUT" "Export" "the export is confirmed"

test_start "import_validates_its_input"
rc="$(sw import)"
assert_equals "1" "$rc" "import without a file fails"
assert_file_contains "$OUT" "dot theme import <file.json>" "usage is printed"
printf '{ "version": 1 }\n' >"$WORK/empty.json"
rc="$(sw import "$WORK/empty.json")"
assert_equals "1" "$rc" "a snapshot without a theme fails"
assert_file_contains "$OUT" "no theme field" "the missing field is reported"
printf '{ "theme": "ghost-dark" }\n' >"$WORK/ghost.json"
rc="$(sw import "$WORK/ghost.json")"
assert_equals "1" "$rc" "an unknown theme fails"
assert_file_contains "$OUT" "not in themes.toml" "the unknown theme is reported"

test_start "import_applies_theme_and_fit"
printf '{\n  "theme": "maui-light",\n  "fit": "zoom"\n}\n' >"$WORK/good.json"
reset_calls
rc="$(sw import "$WORK/good.json")"
assert_equals "0" "$rc" "import exits 0"
assert_equals "maui-light" "$(last_sync)" "the theme is applied"
assert_file_contains "$CALLS/gsettings" "set org.gnome.desktop.background picture-options zoom" "the fit is applied"

# ===========================================================================
# fit
# ===========================================================================
test_start "fit_without_argument_shows_current_and_valid"
rc="$(sw fit)"
assert_equals "0" "$rc" "fit exits 0"
assert_file_contains "$OUT" "gs-picture-options" "the current fit is shown"
assert_file_contains "$OUT" "zoom | spanned" "valid values are listed"

test_start "fit_validates_and_applies"
rc="$(sw fit sideways)"
assert_equals "1" "$rc" "an invalid fit fails"
reset_calls
rc="$(sw fit scaled)"
assert_equals "0" "$rc" "a valid fit exits 0"
assert_file_contains "$CALLS/gsettings" "picture-options scaled" "the fit is written"
rc="$(USE="uname" sw fit scaled)"
assert_equals "1" "$rc" "fit fails without gsettings"
assert_file_contains "$OUT" "gsettings not available" "the missing tool is reported"

# ===========================================================================
# wallpaper
# ===========================================================================
IMG="$WORK/pics/wall.jpg"
mkdir -p "$WORK/pics"
: >"$IMG"

test_start "wallpaper_without_argument_shows_current"
rc="$(sw wallpaper)"
assert_equals "0" "$rc" "wallpaper exits 0"
assert_file_contains "$OUT" "picture-uri-dark.jpg" "the dark wallpaper is shown"

test_start "wallpaper_rejects_a_missing_file"
rc="$(sw wallpaper "$WORK/pics/missing.jpg")"
assert_equals "1" "$rc" "a missing file fails"
assert_file_contains "$OUT" "file not found" "the error names the problem"

test_start "wallpaper_sets_gnome_from_a_relative_path"
reset_calls
rc="$(cd "$WORK/pics" && sw wallpaper wall.jpg)"
assert_equals "0" "$rc" "a relative path is resolved"
assert_file_contains "$CALLS/gsettings" "picture-uri file://" "the GNOME wallpaper is set"
assert_file_contains "$OUT" "(gnome)" "GNOME is the default desktop"

test_start "wallpaper_sets_kde_via_plasma_or_qdbus"
reset_calls
rc="$(USE="uname plasma-apply-wallpaperimage qdbus" XDG_CURRENT_DESKTOP=KDE sw wallpaper "$IMG")"
assert_equals "0" "$rc" "KDE wallpaper exits 0"
assert_file_contains "$CALLS/desktop" "plasma-apply-wallpaperimage $IMG" "plasma-apply is preferred"
reset_calls
rc="$(USE="uname qdbus" DESKTOP_SESSION=plasma sw wallpaper "$IMG")"
assert_equals "0" "$rc" "qdbus fallback exits 0"
assert_file_contains "$CALLS/desktop" "evaluateScript" "the Plasma script is evaluated"

test_start "wallpaper_sets_xfce_last_image"
reset_calls
rc="$(USE="uname xfconf-query" XDG_CURRENT_DESKTOP=XFCE sw wallpaper "$IMG")"
assert_equals "0" "$rc" "XFCE wallpaper exits 0"
assert_file_contains "$CALLS/desktop" "last-image -s $IMG" "the last-image property is set"

test_start "wallpaper_fails_without_a_mechanism"
rc="$(USE="uname" XDG_CURRENT_DESKTOP=KDE sw wallpaper "$IMG")"
assert_equals "1" "$rc" "no KDE tool fails"
assert_file_contains "$OUT" "no wallpaper mechanism found for kde" "the desktop is named"

# ===========================================================================
# accent
# ===========================================================================
test_start "accent_without_argument_shows_current"
rc="$(USE="$DEFAULT_USE kreadconfig6" sw accent)"
assert_equals "0" "$rc" "accent exits 0"
assert_file_contains "$OUT" "gs-accent-color" "the GNOME accent is shown"
assert_file_contains "$OUT" "#3daee9" "the KDE accent is shown"

test_start "accent_maps_numeric_values"
for pair in -1:slate 0:red 1:orange 2:yellow 3:green 4:blue 5:purple 6:pink; do
  reset_calls
  sw accent "${pair%%:*}" >/dev/null
  assert_file_contains "$CALLS/gsettings" "accent-color ${pair#*:}" "${pair%%:*} maps to ${pair#*:}"
done

test_start "accent_writes_kde_and_reconfigures_kwin"
reset_calls
rc="$(USE="uname kwriteconfig6 qdbus" sw accent teal)"
assert_equals "0" "$rc" "a KDE-only accent exits 0"
assert_file_contains "$CALLS/desktop" "kwriteconfig6 --file kdeglobals --group General --key AccentColor #1abc9c" "the KDE hex is written"
assert_file_contains "$CALLS/desktop" "qdbus org.kde.KWin /KWin reconfigure" "KWin is reconfigured"
assert_file_contains "$OUT" "teal (#1abc9c)" "the result is confirmed"

test_start "accent_rejects_bad_values_and_missing_tools"
rc="$(sw accent magenta)"
assert_equals "1" "$rc" "an unknown accent fails"
rc="$(USE="uname" sw accent blue)"
assert_equals "1" "$rc" "no accent tool fails"
assert_file_contains "$OUT" "no gsettings or kwriteconfig6 available" "the missing tools are named"

# ===========================================================================
# status
# ===========================================================================
test_start "status_detects_each_linux_desktop"
set_theme_to maui-dark
for pair in budgie:budgie cinnamon:X-Cinnamon mate:MATE unity:Unity lxqt:LXQt \
  kde:KDE xfce:XFCE sway:sway hyprland:Hyprland niri:niri gnome:ubuntu:GNOME \
  unknown:weird; do
  want="${pair%%:*}"
  rc="$(XDG_CURRENT_DESKTOP="${pair#*:}" sw status)"
  assert_file_contains "$OUT" "Detected DE" "$want: the desktop line is printed"
  assert_file_contains "$OUT" "$want" "$want: the desktop is detected"
done

test_start "status_prints_live_state"
rc="$(USE="$DEFAULT_USE kreadconfig6" XDG_CURRENT_DESKTOP=GNOME sw status)"
assert_equals "0" "$rc" "status exits 0"
assert_file_contains "$OUT" "maui-dark" "the recorded theme is shown"
assert_file_contains "$OUT" "picture-uri.jpg" "the light wallpaper basename is shown"
assert_file_contains "$OUT" "KDE accent" "the KDE accent is shown"

test_start "status_succeeds_off_linux"
# Regression: the dashboard ended with `[[ -n "$de" ]] && ui_info …`. Off
# Linux $de is empty, so that test was the script's last command and
# `dot theme status` exited 1 after printing a complete dashboard.
rc="$(FAKE_UNAME=Darwin sw status)"
assert_equals "0" "$rc" "status exits 0 on macOS"
assert_output_not_contains "Detected DE" "cat '$OUT'"

test_start "status_json_is_machine_readable"
rc="$(USE="$DEFAULT_USE kreadconfig6" XDG_CURRENT_DESKTOP=KDE sw status --json)"
assert_equals "0" "$rc" "status --json exits 0"
assert_file_contains "$OUT" '"recorded": "maui-dark"' "the recorded theme is emitted"
assert_file_contains "$OUT" '"detected_de": "kde"' "the desktop is emitted"
assert_file_contains "$OUT" '"accent": "#3daee9"' "the KDE accent is emitted"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
