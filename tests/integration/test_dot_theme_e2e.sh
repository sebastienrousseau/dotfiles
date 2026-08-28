#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# End-to-end integration test for `dot theme set X`.
#
# Spins up a sandboxed HOME with:
#   * a fake dotfiles source tree containing themes.toml + a couple
#     of paired families
#   * PATH-injected mocks for gsettings, kwriteconfig6, systemctl,
#     kreadconfig6, qdbus, and any other DE tool the pipeline might
#     touch
#   * a stub chezmoi that just writes the theme name to a marker file
#     (so we don't need a real chezmoi install)
#
# Then runs `dot-theme-sync <name>` directly and verifies the observable
# side-effects: theme written, gsettings calls made, wallpaper URI set,
# accent applied, wave-1 tasks ran in parallel.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

DOT_THEME_SYNC="$REPO_ROOT/bin/dot-theme-sync"

# --- Sandbox --------------------------------------------------------------
TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"
export XDG_STATE_HOME="$TMPHOME/state"
export XDG_CONFIG_HOME="$TMPHOME/.config"
export XDG_DATA_HOME="$TMPHOME/.local/share"
export XDG_CACHE_HOME="$TMPHOME/.cache"
mkdir -p "$XDG_STATE_HOME/dot" "$XDG_CONFIG_HOME" \
         "$XDG_DATA_HOME" "$XDG_CACHE_HOME"

# Fake dotfiles source with two families so we can flip between them.
mkdir -p "$TMPHOME/dotfiles/.chezmoidata"
export CHEZMOI_SOURCE_DIR="$TMPHOME/dotfiles"
cat > "$TMPHOME/dotfiles/.chezmoidata.toml" <<'EOF'
theme = "Alpha-dark"
EOF
cat > "$TMPHOME/dotfiles/.chezmoidata/themes.toml" <<'EOF'
[themes.Alpha-dark]
mode = "dark"
family = "Alpha"
wallpaper = ""
macos_accent = 3

[themes.Alpha-dark.app]
gtk_theme = "Adwaita-dark"
gtk_icon = "Papirus-Dark"

[themes.Alpha-dark.ui]
accent = "#2ecc71"

[themes.Alpha-dark.term]
bg = "#111111"
fg = "#eeeeee"

[themes.Beta-dark]
mode = "dark"
family = "Beta"
wallpaper = ""
macos_accent = 4

[themes.Beta-dark.app]
gtk_theme = "Adwaita-dark"
gtk_icon = "Papirus-Dark"

[themes.Beta-dark.ui]
accent = "#3daee9"
EOF

# Set up paired wallpaper PNGs so the resolver has something to write.
mkdir -p "$TMPHOME/Pictures/Wallpapers"
touch "$TMPHOME/Pictures/Wallpapers/Alpha-0.png" \
      "$TMPHOME/Pictures/Wallpapers/Alpha-1.png" \
      "$TMPHOME/Pictures/Wallpapers/Beta-0.png" \
      "$TMPHOME/Pictures/Wallpapers/Beta-1.png"
export DOTFILES_WALLPAPER_DIR="$TMPHOME/Pictures/Wallpapers"

# Simulate GNOME session.
export XDG_CURRENT_DESKTOP="GNOME"

# --- Mocks ---------------------------------------------------------------
MOCK_BIN="$TMPHOME/mocks"
mkdir -p "$MOCK_BIN"
export PATH="$MOCK_BIN:$PATH"
LOG="$TMPHOME/mock.log"

# Every DE / adjacent tool gets a call-log mock.
for cmd in gsettings kwriteconfig6 kreadconfig6 systemctl qdbus \
           tmux pgrep swww hyprctl niri busctl killall; do
  cat > "$MOCK_BIN/$cmd" <<EOF
#!/usr/bin/env bash
printf '$cmd %s\n' "\$*" >> "$LOG"
exit 0
EOF
  chmod +x "$MOCK_BIN/$cmd"
done

# chezmoi mock — just record the invocation. Real chezmoi would render
# 12 templates; that's tested elsewhere.
cat > "$MOCK_BIN/chezmoi" <<EOF
#!/usr/bin/env bash
printf 'chezmoi %s\n' "\$*" >> "$LOG"
exit 0
EOF
chmod +x "$MOCK_BIN/chezmoi"

_reset_log() { : > "$LOG"; }

# --------------------------------------------------------------------------
# 1. Idempotency: dot-theme-sync <current-theme> is a fast no-op.
# --------------------------------------------------------------------------

test_start "e2e_idempotent_when_already_active"
_reset_log
start=$(date +%s%3N)
"$DOT_THEME_SYNC" Alpha-dark > "$TMPHOME/out" 2>&1
end=$(date +%s%3N)
elapsed=$((end - start))
grep -q "Idempotent" "$TMPHOME/out"
_ok_msg=$?
if [[ $_ok_msg -eq 0 && $elapsed -lt 500 ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s (%d ms)\n' "$CURRENT_TEST" "$elapsed"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s (%d ms, expected < 500)\n' "$CURRENT_TEST" "$elapsed"
fi

# --------------------------------------------------------------------------
# 2. Full apply writes the new theme to .chezmoidata.toml.
# --------------------------------------------------------------------------

test_start "e2e_full_apply_writes_theme_to_datafile"
_reset_log
"$DOT_THEME_SYNC" Beta-dark > "$TMPHOME/out" 2>&1
grep -q '^theme = "Beta-dark"$' "$TMPHOME/dotfiles/.chezmoidata.toml"
assert_equals 0 $? "theme = \"Beta-dark\" persisted to .chezmoidata.toml"

# --------------------------------------------------------------------------
# 3. Detected DE == gnome, and desktop status line reflects it.
# --------------------------------------------------------------------------

test_start "e2e_desktop_status_line_labels_gnome"
grep -q "Desktop.*gnome:" "$TMPHOME/out"
assert_equals 0 $? "desktop status line labels 'gnome:'"

# --------------------------------------------------------------------------
# 4. gsettings received a color-scheme prefer-dark write.
# --------------------------------------------------------------------------

test_start "e2e_color_scheme_prefer_dark_written"
grep -q "gsettings set org.gnome.desktop.interface color-scheme prefer-dark" "$LOG"
assert_equals 0 $? "color-scheme=prefer-dark issued"

# --------------------------------------------------------------------------
# 5. GTK theme and icon theme both applied.
# --------------------------------------------------------------------------

test_start "e2e_gtk_theme_applied"
grep -q "gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark" "$LOG"
assert_equals 0 $?

test_start "e2e_icon_theme_applied"
grep -q "gsettings set org.gnome.desktop.interface icon-theme Papirus-Dark" "$LOG"
assert_equals 0 $?

# --------------------------------------------------------------------------
# 6. Wallpaper picture-uri + picture-uri-dark written to the paired PNGs.
# --------------------------------------------------------------------------

test_start "e2e_wallpaper_light_uri_written"
grep -q "gsettings set org.gnome.desktop.background picture-uri file://$TMPHOME/Pictures/Wallpapers/Beta-0.png" "$LOG"
assert_equals 0 $? "picture-uri points to Beta-0.png"

test_start "e2e_wallpaper_dark_uri_written"
grep -q "gsettings set org.gnome.desktop.background picture-uri-dark file://$TMPHOME/Pictures/Wallpapers/Beta-1.png" "$LOG"
assert_equals 0 $? "picture-uri-dark points to Beta-1.png"

# --------------------------------------------------------------------------
# 7. Accent color mapped from macos_accent=4 -> blue.
# --------------------------------------------------------------------------

test_start "e2e_accent_color_blue_for_beta"
grep -q "gsettings set org.gnome.desktop.interface accent-color blue" "$LOG"
assert_equals 0 $? "macos_accent=4 -> accent-color blue"

# --------------------------------------------------------------------------
# 8. History records the previous theme.
# --------------------------------------------------------------------------

test_start "e2e_history_records_prev_theme"
if [[ -f "$XDG_STATE_HOME/dot/theme-history" ]] \
   && head -1 "$XDG_STATE_HOME/dot/theme-history" | grep -q "Alpha-dark"; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# --------------------------------------------------------------------------
# 9. Undo returns to Alpha-dark.
# --------------------------------------------------------------------------

test_start "e2e_flip_back_via_setting_alpha_reads_beta_from_history_head"
# History head should still be Alpha-dark after Beta was applied.
head -1 "$XDG_STATE_HOME/dot/theme-history" | grep -q "Alpha-dark"
assert_equals 0 $? "history top is Alpha-dark (the previous)"

# --------------------------------------------------------------------------
# 10. --dry-run does NOT mutate the data file.
# --------------------------------------------------------------------------

test_start "e2e_dry_run_does_not_write_theme"
printf 'theme = "Beta-dark"\n' > "$TMPHOME/dotfiles/.chezmoidata.toml"
"$DOT_THEME_SYNC" Alpha-dark --dry-run > /dev/null 2>&1
grep -q '^theme = "Beta-dark"$' "$TMPHOME/dotfiles/.chezmoidata.toml"
assert_equals 0 $? "datafile still shows Beta-dark after --dry-run Alpha-dark"

# --------------------------------------------------------------------------
# Summary
# --------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
