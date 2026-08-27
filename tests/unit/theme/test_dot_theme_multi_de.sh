#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Behavioral tests for dot-theme-sync's multi-DE dispatcher, wallpaper
# resolution, accent mapping, and cursor picker. Sources the script
# (source guard prevents main() from running) and calls the pure
# helpers directly with mocked env.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/bin/dot-theme-sync"

# Isolate any file writes the sourced script might do at load time.
TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"
mkdir -p "$TMPHOME/Pictures/Wallpapers" "$TMPHOME/dotfiles/.chezmoidata"
# Point resolve_source_dir at our fake tree so the script loads cleanly.
export CHEZMOI_SOURCE_DIR="$TMPHOME/dotfiles"
# Seed the readonly THEMES_FILE with a real file the resolver tests can use.
cat > "$TMPHOME/dotfiles/.chezmoidata/themes.toml" <<'EOF'
[themes.Solar-dark]
mode = "dark"
family = "Solar"
wallpaper = "/tmp/solar-fixture.heic"
macos_accent = 2
EOF
touch "$TMPHOME/dotfiles/.chezmoidata.toml"

# Source dot-theme-sync — source guard means main() won't run.
# shellcheck source=/dev/null
source "$SCRIPT_FILE"

# ---------------------------------------------------------------------------
# _detect_linux_de — XDG_CURRENT_DESKTOP dispatch
# ---------------------------------------------------------------------------

_detect_case() {
  local input="$1" expected="$2" actual
  # env must be set BEFORE the command substitution runs (inline VAR=val
  # applies to the subsequent command, but $(...) has already been
  # evaluated by then). Export + call, then unset.
  export XDG_CURRENT_DESKTOP="$input"
  export DESKTOP_SESSION=""
  actual="$(_detect_linux_de)"
  unset XDG_CURRENT_DESKTOP DESKTOP_SESSION
  assert_equals "$expected" "$actual" \
    "XDG_CURRENT_DESKTOP='$input' -> $expected"
}

test_start "detect_gnome_from_xdg"
_detect_case "GNOME" gnome
test_start "detect_gnome_with_wayland_suffix"
_detect_case "ubuntu:GNOME" gnome
test_start "detect_kde_from_xdg"
_detect_case "KDE" kde
test_start "detect_plasma_from_xdg"
_detect_case "plasma" kde
test_start "detect_kde_case_insensitive"
_detect_case "Kde" kde
test_start "detect_xfce_from_xdg"
_detect_case "XFCE" xfce
test_start "detect_cinnamon"
_detect_case "X-Cinnamon" cinnamon
test_start "detect_mate"
_detect_case "MATE" mate
test_start "detect_budgie"
_detect_case "Budgie:GNOME" budgie
test_start "detect_lxqt"
_detect_case "LXQt" lxqt
test_start "detect_sway"
_detect_case "sway" sway
test_start "detect_hyprland"
_detect_case "Hyprland" hyprland
test_start "detect_niri"
_detect_case "niri" niri

# ---------------------------------------------------------------------------
# _macos_accent_to_gnome — int -> enum name
# ---------------------------------------------------------------------------

test_start "gnome_accent_slate_for_neg_one"
assert_equals "slate" "$(_macos_accent_to_gnome -1)" "graphite -> slate"
test_start "gnome_accent_red_for_zero"
assert_equals "red" "$(_macos_accent_to_gnome 0)" "0 -> red"
test_start "gnome_accent_orange_for_one"
assert_equals "orange" "$(_macos_accent_to_gnome 1)" "1 -> orange"
test_start "gnome_accent_yellow_for_two"
assert_equals "yellow" "$(_macos_accent_to_gnome 2)" "2 -> yellow"
test_start "gnome_accent_green_for_three"
assert_equals "green" "$(_macos_accent_to_gnome 3)" "3 -> green"
test_start "gnome_accent_blue_for_four"
assert_equals "blue" "$(_macos_accent_to_gnome 4)" "4 -> blue"
test_start "gnome_accent_purple_for_five"
assert_equals "purple" "$(_macos_accent_to_gnome 5)" "5 -> purple"
test_start "gnome_accent_pink_for_six"
assert_equals "pink" "$(_macos_accent_to_gnome 6)" "6 -> pink"
test_start "gnome_accent_empty_for_unknown"
assert_equals "" "$(_macos_accent_to_gnome 99)" "99 -> empty"
test_start "gnome_accent_empty_for_missing"
assert_equals "" "$(_macos_accent_to_gnome "")" "empty -> empty"

# ---------------------------------------------------------------------------
# _macos_accent_to_hex — int -> KDE Plasma hex
# ---------------------------------------------------------------------------

test_start "kde_hex_slate_for_neg_one"
assert_equals "#4d4d4d" "$(_macos_accent_to_hex -1)"
test_start "kde_hex_red_for_zero"
assert_equals "#da4453" "$(_macos_accent_to_hex 0)"
test_start "kde_hex_blue_for_four"
assert_equals "#3daee9" "$(_macos_accent_to_hex 4)"
test_start "kde_hex_empty_for_unknown"
assert_equals "" "$(_macos_accent_to_hex 99)"

# ---------------------------------------------------------------------------
# _cursor_theme_for_mode — env override + fallback
# ---------------------------------------------------------------------------

# Set up a fake icons dir so _cursor_theme_for_mode can find themes.
mkdir -p "$TMPHOME/.local/share/icons/Bibata-Modern-Classic"
mkdir -p "$TMPHOME/.local/share/icons/Bibata-Modern-Ice"

test_start "cursor_dark_defaults_to_bibata_classic"
unset DOT_THEME_CURSOR_DARK DOT_THEME_CURSOR_LIGHT
assert_equals "Bibata-Modern-Classic" "$(_cursor_theme_for_mode dark)" \
  "dark falls back to Bibata Classic"

test_start "cursor_light_defaults_to_bibata_ice"
assert_equals "Bibata-Modern-Ice" "$(_cursor_theme_for_mode light)" \
  "light falls back to Bibata Ice"

test_start "cursor_env_override_dark"
export DOT_THEME_CURSOR_DARK="Bibata-Modern-Classic"
_actual="$(_cursor_theme_for_mode dark)"
unset DOT_THEME_CURSOR_DARK
assert_equals "Bibata-Modern-Classic" "$_actual"

# ---------------------------------------------------------------------------
# _wallpaper_for_mode — mode picking with fallback
# ---------------------------------------------------------------------------

test_start "wallpaper_for_light_prefers_light"
WP_LIGHT="/tmp/light.png"; WP_DARK="/tmp/dark.png"
assert_equals "/tmp/light.png" "$(_wallpaper_for_mode light)"

test_start "wallpaper_for_dark_prefers_dark"
WP_LIGHT="/tmp/light.png"; WP_DARK="/tmp/dark.png"
assert_equals "/tmp/dark.png" "$(_wallpaper_for_mode dark)"

test_start "wallpaper_dark_falls_back_to_light"
WP_LIGHT="/tmp/light.png"; WP_DARK=""
assert_equals "/tmp/light.png" "$(_wallpaper_for_mode dark)" \
  "dark mode falls back to light when no dark variant"

test_start "wallpaper_light_falls_back_to_dark"
WP_LIGHT=""; WP_DARK="/tmp/dark.png"
assert_equals "/tmp/dark.png" "$(_wallpaper_for_mode light)" \
  "light mode falls back to dark when no light variant"

# ---------------------------------------------------------------------------
# _resolve_theme_wallpapers — prefers -0/-1 pair, falls back to wallpaper field
# ---------------------------------------------------------------------------

# THEMES_FILE is readonly (set at load time) — seeded above via CHEZMOI_SOURCE_DIR.

# Case A: paired PNGs exist -> resolver picks them.
touch "$TMPHOME/Pictures/Wallpapers/Solar-0.png" "$TMPHOME/Pictures/Wallpapers/Solar-1.png"
DOTFILES_WALLPAPER_DIR="$TMPHOME/Pictures/Wallpapers" _resolve_theme_wallpapers "Solar-dark"

test_start "resolver_finds_paired_light"
assert_equals "$TMPHOME/Pictures/Wallpapers/Solar-0.png" "$WP_LIGHT"
test_start "resolver_finds_paired_dark"
assert_equals "$TMPHOME/Pictures/Wallpapers/Solar-1.png" "$WP_DARK"
test_start "resolver_reads_family"
assert_equals "Solar" "$WP_FAMILY"
test_start "resolver_reads_macos_accent"
assert_equals "2" "$MACOS_ACCENT"

# Case B: no paired PNGs, wallpaper field exists on disk -> use it for both.
rm "$TMPHOME/Pictures/Wallpapers/Solar-0.png" "$TMPHOME/Pictures/Wallpapers/Solar-1.png"
touch "$TMPHOME/fallback.jpg"
cat >> "$THEMES_FILE" <<EOF

[themes.Fallback-dark]
mode = "dark"
family = "Fallback"
wallpaper = "$TMPHOME/fallback.jpg"
macos_accent = 5
EOF
unset TH_FAMILY  # force _load_theme_fields to re-run
DOTFILES_WALLPAPER_DIR="$TMPHOME/Pictures/Wallpapers" _resolve_theme_wallpapers "Fallback-dark"

test_start "resolver_falls_back_to_wallpaper_light"
assert_equals "$TMPHOME/fallback.jpg" "$WP_LIGHT"
test_start "resolver_falls_back_to_wallpaper_dark"
assert_equals "$TMPHOME/fallback.jpg" "$WP_DARK"
test_start "resolver_carries_macos_accent_from_load"
assert_equals "5" "$MACOS_ACCENT"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '%b\n' "  Tests: ${TESTS_RUN}  ${GREEN}Passed: ${TESTS_PASSED}${NC}  ${RED}Failed: ${TESTS_FAILED}${NC}"
# Machine-readable line consumed by tests/framework/test_runner.sh.
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
