#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Unit tests for the awk-based preview payload that renders inside the
# fzf picker. The preview must:
#   * Emit family / wallpaper / accent / bg / fg lines
#   * Render 24-bit ANSI colour swatches for the palette
#   * Correctly parse hex without a gawk-only strtonum call (must be
#     portable to mawk / busybox awk)
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT

# Minimal themes.toml with the shape the preview awk expects.
THEMES_FILE="$TMPHOME/themes.toml"
cat > "$THEMES_FILE" <<'EOF'
[themes.Solar-dark]
mode = "dark"
family = "Solar"
wallpaper = "/tmp/solar.heic"
macos_accent = 3
source = "custom"

[themes.Solar-dark.term]
bg = "#101010"
fg = "#eeeeee"
c0  = "#000000"
c1  = "#800000"
c2  = "#008000"
c3  = "#808000"
c4  = "#000080"
c5  = "#800080"
c6  = "#008080"
c7  = "#c0c0c0"
c8  = "#808080"
c9  = "#ff0000"
c10 = "#00ff00"
c11 = "#ffff00"
c12 = "#0000ff"
c13 = "#ff00ff"
c14 = "#00ffff"
c15 = "#ffffff"

[themes.Solar-dark.ui]
accent = "#2ecc71"
EOF

# The preview program is read out of scripts/theme/switch.sh, not copied
# here. A copy drifts silently in both directions: on 2026-09-19 the shipped
# program used gawk's three-argument match(), which macOS awk rejects outright,
# and this file's copy had the same bug — so the test "agreed" with the code
# while the preview was dead on macOS for every user. Reading the real program
# means a change to switch.sh is tested, not a change to a duplicate of it.
_preview_awk_program() {
  awk '
    /preview_cmd=.*awk -v F=/ { inprog = 1; next }
    inprog && $0 ~ /^\}.*"\$f"/ { print "}"; exit }
    inprog { print }
  ' "$REPO_ROOT/scripts/theme/switch.sh"
}

_render_preview() {
  local family="$1" mode="$2" f="$3" prog
  prog="$(mktemp)"
  _preview_awk_program >"$prog"
  awk -v F="$family" -v M="$mode" -f "$prog" "$f"
  rm -f "$prog"
}

# ---------------------------------------------------------------------------
# Basic field extraction
# ---------------------------------------------------------------------------

test_start "preview_shows_family_and_mode"
out="$(_render_preview Solar dark "$THEMES_FILE")"
if [[ "$out" == *"family:    Solar (dark)"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

test_start "preview_shows_wallpaper_path"
if [[ "$out" == *"/tmp/solar.heic"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

test_start "preview_shows_accent_hex_and_macos_int"
if [[ "$out" == *"#2ecc71 (macos=3)"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

test_start "preview_shows_bg_and_fg_hex"
if [[ "$out" == *"#101010"* && "$out" == *"#eeeeee"* ]]; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# ANSI escape sequences — every colour renders as \e[48;2;R;G;Bm ... \e[0m
# ---------------------------------------------------------------------------

test_start "preview_emits_24bit_ansi_swatches"
esc=$'\e'
if grep -q "$esc\[48;2;" <<<"$out"; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

test_start "preview_emits_ansi_reset_after_each_swatch"
resets=$(grep -oE "$esc\[0m" <<<"$out" | wc -l)
# 3 fixed swatches (accent, bg, fg) + 16 palette colours = 19+
if (( resets >= 19 )); then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s (%d resets)\n' "$CURRENT_TEST" "$resets"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s (%d resets, expected >= 19)\n' "$CURRENT_TEST" "$resets"
fi

# ---------------------------------------------------------------------------
# Hex parsing — c1 = #800000 should render as 48;2;128;0;0
# ---------------------------------------------------------------------------

test_start "preview_hex_parses_c1_maroon_as_128_0_0"
if grep -q "$esc\[48;2;128;0;0m" <<<"$out"; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

test_start "preview_hex_parses_c15_white_as_255_255_255"
if grep -q "$esc\[48;2;255;255;255m" <<<"$out"; then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s\n' "$CURRENT_TEST"
fi

# ---------------------------------------------------------------------------
# Palette layout — 2 rows of 8
# ---------------------------------------------------------------------------

test_start "preview_palette_has_two_rows"
# Count palette rows: lines starting with "  " followed by escape (swatch)
palette_rows=$(printf '%s\n' "$out" | grep -c "^  $esc\[48;2;")
if (( palette_rows == 2 )); then
  ((TESTS_PASSED++)) || true
  printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  \033[0;31m✗\033[0m %s (%d rows, expected 2)\n' "$CURRENT_TEST" "$palette_rows"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
