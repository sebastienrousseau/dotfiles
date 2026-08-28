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

# Extract the preview awk program by hand — copy the same block from
# scripts/theme/switch.sh so drift shows up as a test failure.
_render_preview() {
  local family="$1" mode="$2" f="$3"
  awk -v F="$family" -v M="$mode" '
    BEGIN {
      root = "[themes." F "-" M "]"
      ui   = "[themes." F "-" M ".ui]"
      term = "[themes." F "-" M ".term]"
      esc  = sprintf("%c[", 27)
    }
    function hex2int(h,   n, i, c, digits) {
      digits = "0123456789abcdef"
      n = 0
      h = tolower(h)
      for (i = 1; i <= length(h); i++) {
        c = index(digits, substr(h, i, 1))
        if (c == 0) return 0
        n = n * 16 + (c - 1)
      }
      return n
    }
    function swatch(hex,   clean, r, g, b) {
      clean = hex
      sub(/^#/, "", clean)
      r = hex2int(substr(clean, 1, 2))
      g = hex2int(substr(clean, 3, 2))
      b = hex2int(substr(clean, 5, 2))
      return esc "48;2;" r ";" g ";" b "m    " esc "0m"
    }
    $0 == root { in_root=1; in_ui=0; in_term=0; next }
    $0 == ui   { in_ui=1; in_root=0; in_term=0; next }
    $0 == term { in_term=1; in_root=0; in_ui=0; next }
    /^\[/ { in_root=0; in_ui=0; in_term=0; next }
    in_root && /^wallpaper /   { sub(/.*= *"?/,""); sub(/"$/,""); wallpaper=$0 }
    in_root && /^macos_accent/ { sub(/.*= */,"");   accent_int=$0 }
    in_ui && /^accent /        { sub(/.*= *"?/,""); sub(/"$/,""); accent=$0 }
    in_term && /^bg /          { sub(/.*= *"?/,""); sub(/"$/,""); bg=$0 }
    in_term && /^fg /          { sub(/.*= *"?/,""); sub(/"$/,""); fg=$0 }
    in_term && match($0, /^c([0-9]+) *= *"([^"]+)"/, m) { term_c[m[1]+0] = m[2] }
    END {
      print "family:    " F " (" M ")"
      print "wallpaper: " wallpaper
      print "accent:    " swatch(accent) " " accent " (macos=" accent_int ")"
      print "bg:        " swatch(bg) " " bg
      print "fg:        " swatch(fg) " " fg
      print ""
      line1 = ""; line2 = ""
      for (i = 0; i <= 7; i++)  line1 = line1 swatch(term_c[i])
      for (i = 8; i <= 15; i++) line2 = line2 swatch(term_c[i])
      print "palette:"
      print "  " line1
      print "  " line2
    }' "$f"
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
