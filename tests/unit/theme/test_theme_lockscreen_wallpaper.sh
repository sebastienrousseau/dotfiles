#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The GNOME lock screen follows the active mode, not always the light one.
#
# org.gnome.desktop.background has picture-uri AND picture-uri-dark, so
# GNOME picks the right one itself. org.gnome.desktop.screensaver has only
# picture-uri. Both wallpaper setters passed the *light* wallpaper to it
# unconditionally, so a user in dark mode locked the screen and got the
# light image.
#
# Asserted behaviourally rather than by grepping for `${dark_wp}`: the
# scripts have no main-guard, so sourcing them runs them. Instead each
# `apply_wallpaper` is extracted and evaluated against a stub `gsettings`
# that records its arguments — the same extraction trick
# test_theme_preview_awk.sh uses for the preview awk program, and for the
# same reason, which is that a copy of the logic in the test would drift.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# A `gsettings` on PATH that logs instead of touching a real session. It
# must be a real file, not a shell function: wallpaper-sync.sh gates the
# whole gsettings block on `command -v gsettings`.
mkdir -p "$WORK/bin"
cat >"$WORK/bin/gsettings" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$GS_LOG"
STUB
chmod +x "$WORK/bin/gsettings"

# Pull one top-level function out of a script, by name.
_extract_fn() {
  awk -v fn="$1" '
    $0 ~ "^" fn "\\(\\) \\{" { inside = 1 }
    inside { print }
    inside && /^\}/ { exit }
  ' "$2"
}

# What the stub was told to set for the lock screen.
_screensaver_uri() {
  grep '^set org.gnome.desktop.screensaver picture-uri ' "$1" |
    tail -1 | awk '{print $NF}'
}

# ---------------------------------------------------------------- gnome
GNOME_FN="$(_extract_fn apply_wallpaper "$REPO_ROOT/scripts/theme/apply-gnome-theme.sh")"

test_start "apply_wallpaper was extracted from apply-gnome-theme.sh"
if [[ "$GNOME_FN" == *"screensaver picture-uri"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: got ${GNOME_FN:-<nothing>}"
fi

# catppuccin-mocha => dark, catppuccin-latte => light (the script's own
# case arms), so the theme name is what selects the mode here.
_run_gnome() {
  local theme="$1" wpdir="$WORK/gnome-wp"
  mkdir -p "$wpdir"
  : >"$wpdir/sample-light.jpg"
  : >"$wpdir/sample-dark.jpg"
  GS_LOG="$WORK/gnome-$theme.log" \
    DOTFILES_WALLPAPER_DIR="$wpdir" \
    PATH="$WORK/bin:$PATH" \
    /bin/bash -c '
      set -uo pipefail
      log() { :; }
      warn() { :; }
      success() { :; }
      '"$GNOME_FN"'
      apply_wallpaper "$1"
    ' _ "$theme" >/dev/null 2>&1
  _screensaver_uri "$WORK/gnome-$theme.log"
}

for pair in "catppuccin-mocha:dark" "catppuccin-latte:light"; do
  theme="${pair%%:*}"
  want="${pair##*:}"
  test_start "apply-gnome-theme.sh: ${theme} locks with the ${want} wallpaper"
  got="$(_run_gnome "$theme")"
  if [[ "$got" == *"sample-${want}.jpg" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: screensaver got ${got:-<nothing>}"
  fi
done

# ------------------------------------------------------------ wallpaper-sync
SYNC_FN="$(_extract_fn apply_wallpaper "$REPO_ROOT/scripts/theme/wallpaper-sync.sh")"

test_start "apply_wallpaper was extracted from wallpaper-sync.sh"
if [[ "$SYNC_FN" == *"screensaver picture-uri"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: got ${SYNC_FN:-<nothing>}"
fi

# This one takes the mode as an argument, and only the Linux arm reaches
# gsettings — hence the `uname` override.
_run_sync() {
  local mode="$1" wpdir="$WORK/sync-wp"
  mkdir -p "$wpdir"
  : >"$wpdir/sample-light.png"
  : >"$wpdir/sample-dark.png"
  GS_LOG="$WORK/sync-$mode.log" \
    PATH="$WORK/bin:$PATH" \
    /bin/bash -c '
      set -uo pipefail
      uname() { echo Linux; }
      ui_info() { :; }
      ui_err() { :; }
      ensure_linux_compatible() { printf "%s\n" "$1"; }
      macos_appearance_frame() { printf "%s\n" "$1"; }
      WALLPAPER_DIR="$2"
      THEME="sample"
      '"$SYNC_FN"'
      apply_wallpaper "$2/sample-$1.png" "$1"
    ' _ "$mode" "$wpdir" >/dev/null 2>&1
  _screensaver_uri "$WORK/sync-$mode.log"
}

for want in dark light; do
  test_start "wallpaper-sync.sh: ${want} mode locks with the ${want} wallpaper"
  got="$(_run_sync "$want")"
  if [[ "$got" == *"sample-${want}.png" ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: screensaver got ${got:-<nothing>}"
  fi
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
