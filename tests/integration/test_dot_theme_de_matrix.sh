#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Cross-DE matrix integration test. Applies the same theme under each
# of the 4 detected desktops (GNOME, KDE, XFCE, wlroots) by swapping
# XDG_CURRENT_DESKTOP and verifies the right backend received the right
# calls. Complements test_theme_kde_handler.sh (which unit-tests the
# KDE handler alone) with an end-to-end sweep across all handlers.
# shellcheck disable=SC1090,SC1091,SC2034,SC2015
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

DOT_THEME_SYNC="$REPO_ROOT/bin/dot-theme-sync"

TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"
export XDG_STATE_HOME="$TMPHOME/state"
export XDG_CONFIG_HOME="$TMPHOME/.config"
export XDG_DATA_HOME="$TMPHOME/.local/share"
export XDG_CACHE_HOME="$TMPHOME/.cache"
mkdir -p "$XDG_STATE_HOME/dot" "$XDG_CONFIG_HOME" \
         "$XDG_DATA_HOME" "$XDG_CACHE_HOME"

mkdir -p "$TMPHOME/dotfiles/.chezmoidata"
export CHEZMOI_SOURCE_DIR="$TMPHOME/dotfiles"
cat > "$TMPHOME/dotfiles/.chezmoidata.toml" <<'EOF'
theme = "Matrix-dark"
EOF
cat > "$TMPHOME/dotfiles/.chezmoidata/themes.toml" <<'EOF'
[themes.Matrix-dark]
mode = "dark"
family = "Matrix"
wallpaper = ""
macos_accent = 3
[themes.Matrix-dark.app]
gtk_theme = "Adwaita-dark"
gtk_icon = "Papirus-Dark"
[themes.Matrix-dark.ui]
accent = "#2ecc71"

[themes.Neo-dark]
mode = "dark"
family = "Neo"
wallpaper = ""
macos_accent = 4
[themes.Neo-dark.app]
gtk_theme = "Adwaita-dark"
gtk_icon = "Papirus-Dark"
[themes.Neo-dark.ui]
accent = "#3daee9"
EOF

mkdir -p "$TMPHOME/Pictures/Wallpapers"
touch "$TMPHOME/Pictures/Wallpapers/Matrix-0.png" \
      "$TMPHOME/Pictures/Wallpapers/Matrix-1.png" \
      "$TMPHOME/Pictures/Wallpapers/Neo-0.png" \
      "$TMPHOME/Pictures/Wallpapers/Neo-1.png"
export DOTFILES_WALLPAPER_DIR="$TMPHOME/Pictures/Wallpapers"

MOCK_BIN="$TMPHOME/mocks"
mkdir -p "$MOCK_BIN"
export PATH="$MOCK_BIN:$PATH"
LOG="$TMPHOME/mock.log"

for cmd in gsettings kwriteconfig6 kreadconfig6 systemctl qdbus \
           plasma-apply-colorscheme plasma-apply-wallpaperimage \
           xfconf-query swww hyprctl \
           chezmoi tmux pgrep busctl killall niri; do
  cat > "$MOCK_BIN/$cmd" <<EOF
#!/usr/bin/env bash
printf '$cmd %s\n' "\$*" >> "$LOG"
exit 0
EOF
  chmod +x "$MOCK_BIN/$cmd"
done

# swww / hyprctl need a running daemon to actually fire — mock pgrep
# to say "yes it's running" so the wlroots branch does its writes.
cat > "$MOCK_BIN/pgrep" <<'EOF'
#!/usr/bin/env bash
# Report as if the requested process is running so wallpaper daemons
# and gnome-shell/plasmashell detection paths both hit.
exit 0
EOF
chmod +x "$MOCK_BIN/pgrep"

_reset_log() { : > "$LOG"; }

_apply_under_de() {
  local de_env="$1" target="$2"
  _reset_log
  # Force re-apply each time via --force so idempotent skip doesn't
  # swallow the run.
  XDG_CURRENT_DESKTOP="$de_env" DESKTOP_SESSION="" \
    "$DOT_THEME_SYNC" "$target" --force > "$TMPHOME/out" 2>&1
}

_ok()   { ((TESTS_PASSED++)) || true; printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"; }
_fail() { ((TESTS_FAILED++)) || true; printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "${1:-}"; }

# ---------------------------------------------------------------------------
# GNOME — gsettings backend must fire
# ---------------------------------------------------------------------------

test_start "matrix_gnome_calls_gsettings_color_scheme"
_apply_under_de "GNOME" "Matrix-dark"
grep -q "gsettings set org.gnome.desktop.interface color-scheme prefer-dark" "$LOG" && _ok || _fail

test_start "matrix_gnome_writes_wallpaper_uri"
grep -q "gsettings set org.gnome.desktop.background picture-uri file://" "$LOG" && _ok || _fail

test_start "matrix_gnome_writes_accent_color_green"
grep -q "gsettings set org.gnome.desktop.interface accent-color green" "$LOG" && _ok || _fail

test_start "matrix_gnome_status_line_labels_gnome"
grep -q "Desktop.*gnome:" "$TMPHOME/out" && _ok || _fail

# ---------------------------------------------------------------------------
# KDE — plasma-apply-* + kwriteconfig6 + KWin reconfigure
# ---------------------------------------------------------------------------

test_start "matrix_kde_calls_plasma_apply_colorscheme_breeze_dark"
_apply_under_de "KDE" "Matrix-dark"
grep -q "plasma-apply-colorscheme BreezeDark" "$LOG" && _ok || _fail

test_start "matrix_kde_writes_accent_hex_to_kdeglobals"
grep -q "kwriteconfig6 --file kdeglobals --group General --key AccentColor #2ecc71" "$LOG" && _ok || _fail

test_start "matrix_kde_calls_plasma_apply_wallpaperimage"
grep -q "plasma-apply-wallpaperimage $TMPHOME/Pictures/Wallpapers/Matrix-1.png" "$LOG" && _ok || _fail

test_start "matrix_kde_calls_kwin_reconfigure"
grep -q "qdbus org.kde.KWin /KWin reconfigure" "$LOG" && _ok || _fail

test_start "matrix_kde_status_line_labels_kde"
grep -q "Desktop.*kde:" "$TMPHOME/out" && _ok || _fail

# ---------------------------------------------------------------------------
# XFCE — xfconf-query for xsettings + xfce4-desktop
# ---------------------------------------------------------------------------

test_start "matrix_xfce_calls_xfconf_query_for_gtk_theme"
_apply_under_de "XFCE" "Neo-dark"
grep -q "xfconf-query -c xsettings -p /Net/ThemeName -s Adwaita-dark" "$LOG" && _ok || _fail

test_start "matrix_xfce_calls_xfconf_query_for_icon_theme"
grep -q "xfconf-query -c xsettings -p /Net/IconThemeName -s Papirus-Dark" "$LOG" && _ok || _fail

test_start "matrix_xfce_status_line_labels_xfce"
grep -q "Desktop.*xfce:" "$TMPHOME/out" && _ok || _fail

# ---------------------------------------------------------------------------
# wlroots (Hyprland) — gsettings for color-scheme + swww for wallpaper
# ---------------------------------------------------------------------------

test_start "matrix_wlroots_hyprland_uses_gsettings_color_scheme"
_apply_under_de "Hyprland" "Neo-dark"
grep -q "gsettings set org.gnome.desktop.interface color-scheme prefer-dark" "$LOG" && _ok || _fail

test_start "matrix_wlroots_status_line_labels_hyprland"
grep -q "Desktop.*hyprland:" "$TMPHOME/out" && _ok || _fail

test_start "matrix_wlroots_calls_swww_when_daemon_present"
# pgrep is mocked to always exit 0 (daemon 'running'), so swww should fire.
grep -q "swww img $TMPHOME/Pictures/Wallpapers/Neo-1.png" "$LOG" && _ok || _fail

# ---------------------------------------------------------------------------
# Cinnamon / MATE / Budgie / Unity route through the GNOME handler
# ---------------------------------------------------------------------------

test_start "matrix_cinnamon_routes_to_gnome_family_handler"
_apply_under_de "X-Cinnamon" "Matrix-dark"
grep -q "gsettings set org.gnome.desktop.interface color-scheme" "$LOG" && _ok || _fail

test_start "matrix_cinnamon_status_line_labels_cinnamon"
grep -q "Desktop.*cinnamon:" "$TMPHOME/out" && _ok || _fail

test_start "matrix_mate_status_line_labels_mate"
_apply_under_de "MATE" "Neo-dark"
grep -q "Desktop.*mate:" "$TMPHOME/out" && _ok || _fail

test_start "matrix_budgie_gnome_hybrid_labels_budgie"
_apply_under_de "Budgie:GNOME" "Matrix-dark"
grep -q "Desktop.*budgie:" "$TMPHOME/out" && _ok || _fail

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
