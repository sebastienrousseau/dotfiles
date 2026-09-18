#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Golden-file tests. Each canonical rendering is compared against a
# frozen fixture; when the actual output drifts, the diff shows exactly
# what changed so it's easy to decide "regen the golden" or "revert the
# change".
#
# Golden files live under tests/fixtures/theme_golden/. Regenerate with:
#   REGENERATE_GOLDEN=1 bash tests/unit/theme/test_theme_golden.sh
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FIXTURE_DIR="$REPO_ROOT/tests/fixtures/theme_golden"
THEMES_FILE="$FIXTURE_DIR/themes.toml"

# Preview renderer — same awk block as scripts/theme/switch.sh's
# fzf --preview call. Kept in sync by test_theme_preview_awk.sh; here
# we snapshot its output byte-for-byte.
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
      digits = "0123456789abcdef"; n = 0; h = tolower(h)
      for (i = 1; i <= length(h); i++) {
        c = index(digits, substr(h, i, 1))
        if (c == 0) return 0
        n = n * 16 + (c - 1)
      }
      return n
    }
    function swatch(hex,   clean, r, g, b) {
      clean = hex; sub(/^#/, "", clean)
      r = hex2int(substr(clean, 1, 2)); g = hex2int(substr(clean, 3, 2)); b = hex2int(substr(clean, 5, 2))
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

# Diff renderer — mirrors scripts/theme/switch.sh's diff subcommand.
# Simplified: emits just the mark, label, and two hex/text values, no
# ANSI swatches (those are locale-dependent in the switch.sh version).
_render_diff() {
  local a="$1" b="$2" f="$3"
  awk -v A="$a" -v B="$b" '
    function value(line,   v) { v = line; sub(/^[^=]*= *"?/, "", v); sub(/"?[[:space:]]*$/, "", v); return v }
    $0 == "[themes." A "]"      { name=A; section=""; next }
    $0 == "[themes." A ".ui]"   { name=A; section="ui"; next }
    $0 == "[themes." A ".term]" { name=A; section="term"; next }
    $0 == "[themes." B "]"      { name=B; section=""; next }
    $0 == "[themes." B ".ui]"   { name=B; section="ui"; next }
    $0 == "[themes." B ".term]" { name=B; section="term"; next }
    /^\[/ { name=""; section=""; next }
    name != "" && /=/ {
      key = $0; sub(/ *=.*/, "", key)
      slot[name "." section "." key] = value($0)
    }
    function row(label, left, right) {
      mark = (left == right ? " " : "!=")
      printf "%s  %-14s  %-24s  %-24s\n", mark, label, left, right
    }
    END {
      row("family",       slot[A "..family"],       slot[B "..family"])
      row("mode",         slot[A "..mode"],         slot[B "..mode"])
      row("macos_accent", slot[A "..macos_accent"], slot[B "..macos_accent"])
      row("ui.accent",    slot[A ".ui.accent"],     slot[B ".ui.accent"])
      row("term.bg",      slot[A ".term.bg"],       slot[B ".term.bg"])
      row("term.fg",      slot[A ".term.fg"],       slot[B ".term.fg"])
    }
  ' "$f"
}

_compare_golden() {
  local label="$1" actual="$2" golden_file="$FIXTURE_DIR/$3"
  if [[ "${REGENERATE_GOLDEN:-0}" == "1" ]]; then
    printf '%s' "$actual" > "$golden_file"
    ((TESTS_PASSED++)) || true
    printf '  \033[0;33m~\033[0m %s: golden regenerated -> %s\n' "$CURRENT_TEST" "$golden_file"
    return
  fi
  if [[ ! -f "$golden_file" ]]; then
    ((TESTS_FAILED++)) || true
    printf '  \033[0;31m✗\033[0m %s: golden fixture missing at %s\n' "$CURRENT_TEST" "$golden_file"
    printf '    Run: REGENERATE_GOLDEN=1 bash %s\n' "$(basename "${BASH_SOURCE[0]}")"
    return
  fi
  if diff -u <(printf '%s' "$actual") "$golden_file" > /dev/null 2>&1; then
    ((TESTS_PASSED++)) || true
    printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"
  else
    ((TESTS_FAILED++)) || true
    printf '  \033[0;31m✗\033[0m %s: diverges from %s\n' "$CURRENT_TEST" "$golden_file"
    diff -u "$golden_file" <(printf '%s' "$actual") 2>&1 | head -12 | sed 's/^/    /'
  fi
}

test_start "golden_preview_solar_dark"
out="$(_render_preview Solar dark "$THEMES_FILE")"
_compare_golden "preview solar-dark" "$out" "preview_solar_dark.txt"

test_start "golden_preview_firewatch_dark"
out="$(_render_preview Firewatch dark "$THEMES_FILE")"
_compare_golden "preview firewatch-dark" "$out" "preview_firewatch_dark.txt"

test_start "golden_diff_solar_vs_firewatch"
out="$(_render_diff Solar-dark Firewatch-dark "$THEMES_FILE")"
_compare_golden "diff solar-dark firewatch-dark" "$out" "diff_solar_firewatch.txt"

test_start "golden_diff_solar_vs_solar_no_deltas"
out="$(_render_diff Solar-dark Solar-dark "$THEMES_FILE")"
_compare_golden "diff solar-dark solar-dark" "$out" "diff_solar_solar.txt"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
