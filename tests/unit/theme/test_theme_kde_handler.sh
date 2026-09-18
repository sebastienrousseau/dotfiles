#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Behavioural tests for _apply_kde_desktop in bin/dot-theme-sync using
# PATH-injected mocks. The GNOME box this runs on has no KDE session,
# so we simulate one by:
#   1. Sourcing dot-theme-sync (source guard prevents main() from firing)
#   2. Populating the TH_* globals _apply_kde_desktop reads
#   3. Injecting mock kwriteconfig6 / plasma-apply-* / qdbus that log
#      their calls to a file
#   4. Calling _apply_kde_desktop and asserting the call log matches
#      what a real Plasma session would receive.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/bin/dot-theme-sync"

TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"
mkdir -p "$TMPHOME/dotfiles/.chezmoidata" "$TMPHOME/Pictures/Wallpapers"
export CHEZMOI_SOURCE_DIR="$TMPHOME/dotfiles"
touch "$TMPHOME/dotfiles/.chezmoidata.toml"
cat > "$TMPHOME/dotfiles/.chezmoidata/themes.toml" <<'EOF'
[themes.Solar-dark]
mode = "dark"
family = "Solar"
wallpaper = "/tmp/solar.heic"
macos_accent = 3
EOF

# PATH-injected mocks. Each mock logs its call to $LOG and exits 0.
MOCK_BIN="$TMPHOME/mocks"
mkdir -p "$MOCK_BIN"
export PATH="$MOCK_BIN:$PATH"
LOG="$TMPHOME/kde.log"

for cmd in kwriteconfig6 plasma-apply-colorscheme plasma-apply-wallpaperimage qdbus gsettings; do
  cat > "$MOCK_BIN/$cmd" <<EOF
#!/usr/bin/env bash
printf '$cmd %s\n' "\$*" >> "$LOG"
exit 0
EOF
  chmod +x "$MOCK_BIN/$cmd"
done

# Source dot-theme-sync so its helpers are callable.
source "$SCRIPT_FILE"

# Populate the wallpaper-resolver globals the way reload_desktop would.
touch "$TMPHOME/Pictures/Wallpapers/Solar-0.png" "$TMPHOME/Pictures/Wallpapers/Solar-1.png"
export DOTFILES_WALLPAPER_DIR="$TMPHOME/Pictures/Wallpapers"
_load_theme_fields "Solar-dark"
_resolve_theme_wallpapers "Solar-dark"

_reset_log() { : > "$LOG"; }

# ---------------------------------------------------------------------------
# Colour scheme routing
# ---------------------------------------------------------------------------

test_start "kde_dark_calls_plasma_apply_breeze_dark"
_reset_log
CHANGED=0
_apply_kde_desktop "dark" "Adwaita-dark" "Papirus-Dark"
grep -q "plasma-apply-colorscheme BreezeDark" "$LOG"
assert_equals 0 $? "dark mode -> plasma-apply-colorscheme BreezeDark"

test_start "kde_light_calls_plasma_apply_breeze_light"
_reset_log
_apply_kde_desktop "light" "Adwaita" "Papirus"
grep -q "plasma-apply-colorscheme BreezeLight" "$LOG"
assert_equals 0 $? "light mode -> plasma-apply-colorscheme BreezeLight"

# ---------------------------------------------------------------------------
# Accent colour (Plasma 6.2+ writes kdeglobals [General] AccentColor)
# ---------------------------------------------------------------------------

test_start "kde_accent_writes_green_hex_when_macos_accent_3"
_reset_log
TH_MACOS_ACCENT=3
_load_theme_fields "Solar-dark"; _resolve_theme_wallpapers "Solar-dark"
_apply_kde_desktop "dark" "Adwaita-dark" "Papirus-Dark"
grep -q 'kwriteconfig6 --file kdeglobals --group General --key AccentColor #2ecc71' "$LOG"
assert_equals 0 $? "macos_accent=3 -> #2ecc71"

# ---------------------------------------------------------------------------
# Icon theme in kdeglobals [Icons] Theme
# ---------------------------------------------------------------------------

test_start "kde_writes_icon_theme_to_kdeglobals_icons"
_reset_log
_apply_kde_desktop "dark" "Adwaita-dark" "Papirus-Dark"
grep -q "kwriteconfig6 --file kdeglobals --group Icons --key Theme Papirus-Dark" "$LOG"
assert_equals 0 $? "gtk_icon -> kdeglobals Icons Theme"

# ---------------------------------------------------------------------------
# Cursor + fonts
# ---------------------------------------------------------------------------

test_start "kde_writes_cursor_theme_from_mode"
mkdir -p "$TMPHOME/.local/share/icons/Bibata-Modern-Classic"
_reset_log
_apply_kde_desktop "dark" "Adwaita-dark" "Papirus-Dark"
grep -q "kwriteconfig6 --file kdeglobals --group General --key XCursorTheme Bibata-Modern-Classic" "$LOG"
assert_equals 0 $? "dark mode -> XCursorTheme Bibata-Modern-Classic"

test_start "kde_writes_fonts_when_TH_font_set"
export TH_MONO_FONT="Fira Code 12"
export TH_UI_FONT="Inter 11"
_reset_log
_apply_kde_desktop "dark" "Adwaita-dark" "Papirus-Dark"
grep -q "kwriteconfig6 --file kdeglobals --group General --key font Inter 11" "$LOG"
_font_ui=$?
grep -q "kwriteconfig6 --file kdeglobals --group General --key fixed Fira Code 12" "$LOG"
_font_mono=$?
assert_equals 0 $((_font_ui + _font_mono)) "both UI and mono fonts written"
unset TH_MONO_FONT TH_UI_FONT

# ---------------------------------------------------------------------------
# Wallpaper
# ---------------------------------------------------------------------------

test_start "kde_dark_wallpaper_calls_plasma_apply_wallpaperimage_with_dark_variant"
_reset_log
_apply_kde_desktop "dark" "Adwaita-dark" "Papirus-Dark"
grep -q "plasma-apply-wallpaperimage $TMPHOME/Pictures/Wallpapers/Solar-1.png" "$LOG"
assert_equals 0 $? "dark mode -> Solar-1.png via plasma-apply-wallpaperimage"

test_start "kde_light_wallpaper_uses_light_variant"
_reset_log
_apply_kde_desktop "light" "Adwaita" "Papirus"
grep -q "plasma-apply-wallpaperimage $TMPHOME/Pictures/Wallpapers/Solar-0.png" "$LOG"
assert_equals 0 $? "light mode -> Solar-0.png"

# ---------------------------------------------------------------------------
# KWin reconfigure fires so scheme+accent take effect without logout
# ---------------------------------------------------------------------------

test_start "kde_calls_kwin_reconfigure_at_the_end"
_reset_log
_apply_kde_desktop "dark" "Adwaita-dark" "Papirus-Dark"
grep -q "qdbus org.kde.KWin /KWin reconfigure" "$LOG"
assert_equals 0 $? "KWin reconfigure is invoked"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '%b\n' "  Tests: ${TESTS_RUN}  ${GREEN}Passed: ${TESTS_PASSED}${NC}  ${RED}Failed: ${TESTS_FAILED}${NC}"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
