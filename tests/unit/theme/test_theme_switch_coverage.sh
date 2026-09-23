#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC2034
# Behavioural coverage for scripts/theme/switch.sh — the state-changing
# subcommands: mode, sync, ambient (run/enable/disable/status), rotate,
# plan, undo, history, preview, random and the family quick-switch.
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

# ===========================================================================
# mode
# ===========================================================================
test_start "mode_rejects_an_unknown_value"
set_theme_to bloom-dark
reset_calls
rc="$(sw mode sepia)"
assert_equals "1" "$rc" "an unknown mode fails"
assert_file_contains "$OUT" "dot theme mode <dark|light|auto>" "usage is printed"
assert_empty "$(last_sync)" "nothing is applied"

test_start "mode_is_a_no_op_when_already_in_the_manual_mode"
set_theme_to bloom-light light
reset_calls
rc="$(sw mode light)"
assert_equals "0" "$rc" "mode light exits 0"
assert_file_contains "$OUT" "already in light mode" "no change is announced"
assert_empty "$(last_sync)" "nothing is applied"

test_start "mode_light_switches_the_variant"
set_theme_to bloom-dark dark
reset_calls
sw mode light >/dev/null
assert_equals "bloom-light" "$(last_sync)" "the light variant is applied"

# ===========================================================================
# theme_mode_preference fallback + system appearance detection
# ===========================================================================
test_start "an_unset_mode_preference_is_derived_from_the_variant"
set_theme_to bloom-light ""
sw current >/dev/null
assert_file_contains "$OUT" "bloom-light (bloom, light; light)" "a light variant implies manual light"
set_theme_to bloom-dark ""
sw current >/dev/null
assert_file_contains "$OUT" "bloom-dark (bloom, dark; dark)" "a dark variant implies manual dark"

test_start "sync_in_manual_mode_reapplies_even_when_matching"
set_theme_to bloom-dark dark
reset_calls
FAKE_COLOR_SCHEME=prefer-dark sw sync >/dev/null
assert_file_contains "$OUT" "System is dark" "manual mode is converted to auto"
assert_equals "bloom-dark --auto" "$(last_sync)" "the variant is re-applied in auto mode"

test_start "sync_if_auto_proceeds_in_auto_mode"
set_theme_to bloom-dark auto
reset_calls
FAKE_COLOR_SCHEME=prefer-light sw sync --if-auto >/dev/null
assert_equals "bloom-light --auto" "$(last_sync)" "background sync follows the system in auto mode"

test_start "gnome_default_scheme_counts_as_dark"
set_theme_to bloom-light auto
reset_calls
FAKE_COLOR_SCHEME=default sw sync >/dev/null
assert_equals "bloom-dark --auto" "$(last_sync)" "'default' maps to dark"

test_start "kde_colour_scheme_overrides_gnome"
set_theme_to bloom-dark auto
reset_calls
USE="$DEFAULT_USE kreadconfig6" FAKE_KDE_SCHEME=BreezeLight sw sync >/dev/null
assert_equals "bloom-light --auto" "$(last_sync)" "a KDE Light scheme selects light"
set_theme_to bloom-light auto
reset_calls
USE="$DEFAULT_USE kreadconfig6" FAKE_COLOR_SCHEME=prefer-light FAKE_KDE_SCHEME=BreezeDark \
  sw sync >/dev/null
assert_equals "bloom-dark --auto" "$(last_sync)" "a KDE Dark scheme wins over GNOME prefer-light"

test_start "an_unknown_platform_defaults_to_dark"
set_theme_to bloom-light auto
reset_calls
FAKE_UNAME=FreeBSD sw sync >/dev/null
assert_equals "bloom-dark --auto" "$(last_sync)" "the fallback appearance is dark"

# ===========================================================================
# Quick switch by family name
# ===========================================================================
test_start "a_bare_family_name_switches_in_auto_mode"
set_theme_to bloom-dark
reset_calls
rc="$(sw maui)"
assert_equals "0" "$rc" "a family quick switch exits 0"
assert_equals "maui-dark --auto" "$(last_sync)" "the family follows the system appearance"

test_start "set_forwards_extra_flags_for_a_family"
reset_calls
sw set maui >/dev/null
assert_equals "maui-dark --auto" "$(last_sync)" "set of a family resolves to auto"

# ===========================================================================
# plan
# ===========================================================================
test_start "plan_requires_a_name"
reset_calls
rc="$(sw plan)"
assert_equals "1" "$rc" "plan without a name fails"
assert_file_contains "$OUT" "dot theme plan <family|variant>" "usage is printed"

test_start "plan_mode_flag_requires_a_value"
rc="$(sw plan maui --mode)"
assert_equals "1" "$rc" "--mode without a value fails"
assert_file_contains "$OUT" "--mode requires auto, dark, or light" "the error explains --mode"

test_start "plan_rejects_unknown_options_and_modes"
rc="$(sw plan maui --bogus)"
assert_equals "1" "$rc" "an unknown option fails"
assert_file_contains "$OUT" "Unknown option" "the option is named"
rc="$(sw plan maui --mode=sepia)"
assert_equals "1" "$rc" "an invalid mode fails"
assert_empty "$(last_sync)" "no plan is requested on a usage error"

test_start "plan_explicit_variant_is_passed_through"
reset_calls
rc="$(sw plan maui-light --json)"
assert_equals "0" "$rc" "plan exits 0"
assert_equals "maui-light --plan --json" "$(last_sync)" "the variant is planned verbatim"

test_start "plan_family_defaults_to_auto"
reset_calls
sw plan maui >/dev/null
assert_equals "maui-dark --plan --auto" "$(last_sync)" "a family plans against the system appearance"

test_start "plan_manual_mode_selects_the_variant"
reset_calls
sw plan maui-dark --mode light >/dev/null
assert_equals "maui-light --plan" "$(last_sync)" "--mode light picks the light variant"
reset_calls
sw plan maui --mode=dark >/dev/null
assert_equals "maui-dark --plan" "$(last_sync)" "--mode=dark picks the dark variant"

# ===========================================================================
# history / undo
# ===========================================================================
HIST="$XDG_STATE_HOME/dot/theme-history"

test_start "history_reports_an_empty_stack"
rm -f "$HIST"
rc="$(sw history)"
assert_equals "0" "$rc" "empty history exits 0"
assert_file_contains "$OUT" "apply a theme to start tracking" "empty history is explained"

test_start "history_lists_entries_newest_first"
printf 'maui-light\nbloom-light\n' >"$HIST"
set_theme_to bloom-dark
rc="$(sw history)"
assert_equals "0" "$rc" "history exits 0"
assert_file_contains "$OUT" " 1  maui-light" "the newest entry is numbered 1"
assert_file_contains "$OUT" " 2  bloom-light" "the older entry follows"

test_start "undo_fails_on_an_empty_history"
rm -f "$HIST"
reset_calls
rc="$(sw undo)"
assert_equals "1" "$rc" "undo with no history fails"
assert_file_contains "$OUT" "no previous theme recorded" "the error explains why"

test_start "undo_applies_the_previous_theme_and_pushes_the_current"
printf 'maui-light\nbloom-dark\nbloom-light\n' >"$HIST"
set_theme_to bloom-dark
reset_calls
rc="$(sw undo)"
assert_equals "0" "$rc" "undo exits 0"
assert_equals "maui-light" "$(last_sync)" "the previous theme is applied"
assert_equals "bloom-dark
bloom-light" "$(cat "$HIST")" "the current theme moves to the top, deduplicated"

test_start "undo_with_a_single_entry_leaves_only_the_current"
printf 'maui-light\n' >"$HIST"
set_theme_to bloom-dark
reset_calls
sw undo >/dev/null
assert_equals "bloom-dark" "$(cat "$HIST")" "only the current theme remains"

# ===========================================================================
# preview
# ===========================================================================
test_start "preview_requires_a_name"
rc="$(sw preview)"
assert_equals "1" "$rc" "preview without a name fails"
assert_file_contains "$OUT" "dot theme preview <name>" "usage is printed"

test_start "preview_keeps_the_theme_on_enter"
set_theme_to bloom-dark
reset_calls
printf '\n' >"$WORK/enter"
rc="$(STDIN_FILE="$WORK/enter" sw preview maui-light)"
assert_equals "0" "$rc" "preview exits 0 on ENTER"
assert_equals "--force maui-light" "$(last_sync)" "the previewed theme is applied with --force"
assert_file_contains "$OUT" "Kept" "keeping the theme is confirmed"

test_start "preview_reverts_when_apply_fails"
set_theme_to bloom-dark
reset_calls
rc="$(FAKE_SYNC_RC=1 sw preview maui-light)"
assert_equals "1" "$rc" "a failed preview exits 1"
assert_file_contains "$OUT" "apply failed" "the failure is reported"
assert_equals "--force bloom-dark" "$(last_sync)" "the previous theme is restored"

# ===========================================================================
# random
# ===========================================================================
test_start "random_rejects_bad_arguments"
rc="$(sw random --mode sepia)"
assert_equals "1" "$rc" "an invalid --mode fails"
assert_file_contains "$OUT" "--mode dark|light" "the valid modes are listed"
rc="$(sw random --bogus)"
assert_equals "1" "$rc" "an unknown argument fails"
assert_file_contains "$OUT" "dot theme random" "usage is printed"

test_start "random_picks_another_family_and_keeps_auto"
set_theme_to bloom-light auto
reset_calls
rc="$(sw random)"
assert_equals "0" "$rc" "random exits 0"
assert_equals "maui-light --auto" "$(last_sync)" "the other family is picked in the current mode"

test_start "random_explicit_mode_is_manual"
set_theme_to bloom-dark auto
reset_calls
sw random --mode light >/dev/null
assert_equals "maui-light" "$(last_sync)" "--mode light applies a manual light variant"
reset_calls
sw random --mode=dark >/dev/null
assert_equals "maui-dark" "$(last_sync)" "--mode=dark applies a manual dark variant"

test_start "random_with_one_family_reuses_it"
ONE_SRC="$WORK/one-src"
mkdir -p "$ONE_SRC/.chezmoidata"
printf 'theme = "maui-dark"\ntheme_mode = "dark"\n' >"$ONE_SRC/.chezmoidata.toml"
printf '[themes.maui-dark]\nmode = "dark"\n[themes.maui-light]\nmode = "light"\n' \
  >"$ONE_SRC/.chezmoidata/themes.toml"
reset_calls
rc="$(SRC_OVERRIDE="$ONE_SRC" sw random)"
assert_equals "0" "$rc" "random exits 0 with a single family"
assert_equals "maui-dark" "$(last_sync)" "the only family is re-applied"

test_start "random_fails_without_paired_families"
NONE_SRC="$WORK/none-src"
mkdir -p "$NONE_SRC/.chezmoidata"
printf 'theme = "solo-dark"\n' >"$NONE_SRC/.chezmoidata.toml"
printf '[themes.solo-dark]\nmode = "dark"\n' >"$NONE_SRC/.chezmoidata/themes.toml"
reset_calls
rc="$(SRC_OVERRIDE="$NONE_SRC" sw random)"
assert_equals "1" "$rc" "random fails with nothing to pick"
assert_file_contains "$OUT" "run 'dot theme rebuild' first" "the remedy is suggested"

# ===========================================================================
# picker guard
# ===========================================================================
test_start "picker_fails_without_a_themes_file"
NOTHEMES_SRC="$WORK/nothemes-src"
mkdir -p "$NOTHEMES_SRC"
printf 'theme = "maui-dark"\n' >"$NOTHEMES_SRC/.chezmoidata.toml"
rc="$(SRC_OVERRIDE="$NOTHEMES_SRC" sw)"
assert_equals "1" "$rc" "the picker cannot run without themes.toml"
assert_file_contains "$OUT" "themes.toml" "the missing file is named"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
