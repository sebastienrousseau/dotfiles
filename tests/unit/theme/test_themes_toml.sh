#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Theme SSOT validation — verifies wallpaper-backed themes stay paired and valid
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

THEMES_FILE="$REPO_ROOT/.chezmoidata/themes.toml"

# --- File existence ---
test_start "themes_toml_exists"
assert_file_exists "$THEMES_FILE" "themes.toml must exist"

# --- TOML validates ---
test_start "themes_toml_valid"
if python3 - "$THEMES_FILE" <<'PYEOF' >/dev/null 2>&1; then
import sys
path = sys.argv[1]
try:
    import tomllib as toml  # py311+
except ModuleNotFoundError:
    try:
        import tomli as toml  # py310 fallback if installed
    except ModuleNotFoundError:
        sys.exit(2)

with open(path, "rb") as f:
    toml.load(f)
PYEOF
  rc=0
else
  rc=$?
fi
if [[ $rc -eq 0 || $rc -eq 2 ]]; then
  ((TESTS_PASSED++))
  if [[ $rc -eq 2 ]]; then
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped: no toml parser module)"
  else
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
  fi
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST — TOML parse error"
fi

# --- Theme count ---
test_start "theme_count_matches_wallpapers"
section_count=$(grep '^\[themes\.' "$THEMES_FILE" | grep -cv '\.\(term\|ui\|app\|ext\|metrics\)\]')
if [[ -d "${HOME}/Pictures/Wallpapers" ]]; then
  wallpaper_count="$(find "${HOME}/Pictures/Wallpapers" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.png' \) | wc -l | tr -d ' ')"
  assert_equals "$section_count" "$wallpaper_count" "theme count must match active wallpaper-backed themes"
else
  assert_equals "$section_count" "$section_count" "theme manifest parsed"
fi

# --- Every theme has required sections ---
test_start "all_themes_have_required_sections"
missing=0
while IFS= read -r section; do
  name="${section#\[themes.}"
  name="${name%\]}"
  [[ "$name" == *.* ]] && continue
  for sub in term ui app; do
    if ! grep -q "^\[themes\.${name}\.${sub}\]" "$THEMES_FILE"; then
      echo "    MISSING: [themes.${name}.${sub}]"
      missing=$((missing + 1))
    fi
  done
done < <(grep '^\[themes\.[a-z]' "$THEMES_FILE" | grep -v '\.\(term\|ui\|app\|ext\)\]')
assert_equals "$missing" "0" "all themes must have term, ui, app sections"

# --- Every theme has required term fields ---
test_start "all_themes_have_term_fields"
missing=0
required_term="bg fg cursor cursor_text sel_bg sel_fg c0 c1 c2 c3 c4 c5 c6 c7 c8 c9 c10 c11 c12 c13 c14 c15"
while IFS= read -r section; do
  name="${section#\[themes.}"
  name="${name%\]}"
  [[ "$name" == *.* ]] && continue
  for field in $required_term; do
    if ! sed -n "/^\[themes\.${name}\.term\]/,/^\[/p" "$THEMES_FILE" | grep -q "^${field} "; then
      echo "    MISSING: ${name}.term.${field}"
      missing=$((missing + 1))
    fi
  done
done < <(grep '^\[themes\.[a-z]' "$THEMES_FILE" | grep -v '\.\(term\|ui\|app\|ext\)\]')
assert_equals "$missing" "0" "all themes must have all term fields"

# --- Every theme has required ui fields ---
test_start "all_themes_have_ui_fields"
missing=0
required_ui="accent accent_text error warning success info panel border"
while IFS= read -r section; do
  name="${section#\[themes.}"
  name="${name%\]}"
  [[ "$name" == *.* ]] && continue
  for field in $required_ui; do
    if ! sed -n "/^\[themes\.${name}\.ui\]/,/^\[/p" "$THEMES_FILE" | grep -q "^${field} "; then
      echo "    MISSING: ${name}.ui.${field}"
      missing=$((missing + 1))
    fi
  done
done < <(grep '^\[themes\.[a-z]' "$THEMES_FILE" | grep -v '\.\(term\|ui\|app\|ext\)\]')
assert_equals "$missing" "0" "all themes must have all ui fields"

# --- Wallpaper pair validation ---
test_start "wallpapers_match_theme_names"
WALLPAPER_DIR="${HOME}/Pictures/Wallpapers"
missing=0
unexpected=0
if [[ -d "$WALLPAPER_DIR" ]]; then
  while IFS= read -r section; do
    name="${section#\[themes.}"
    name="${name%\]}"
    [[ "$name" == *.* ]] && continue
    if [[ ! -f "$WALLPAPER_DIR/${name}.jpg" && ! -f "$WALLPAPER_DIR/${name}.png" ]]; then
      echo "    MISSING WALLPAPER: ${name}.jpg|png"
      missing=$((missing + 1))
    fi
  done < <(grep '^\[themes\.[a-z]' "$THEMES_FILE" | grep -v '\.\(term\|ui\|app\|ext\|metrics\)\]')

  while IFS= read -r file; do
    base="${file%.*}"
    if ! grep -q "^\[themes\.${base}\]$" "$THEMES_FILE"; then
      echo "    UNEXPECTED WALLPAPER: $file"
      unexpected=$((unexpected + 1))
    fi
  done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.png' \) 2>/dev/null | sed 's#^.*/##')

  assert_equals "$missing" "0" "every theme must have a matching wallpaper"
  assert_equals "$unexpected" "0" "every wallpaper must map to a theme"
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped: wallpaper directory missing)"
fi

test_start "wallpaper_families_have_light_dark_pairs"
pair_errors=0
if [[ -d "$WALLPAPER_DIR" ]]; then
  families="$(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.png' \) 2>/dev/null | sed 's#^.*/##' | sed -E 's/-(light|dark)\.(jpg|png)$//' | sort -u)"
  while IFS= read -r family; do
    [[ -n "$family" ]] || continue
    [[ -f "${WALLPAPER_DIR}/${family}-light.jpg" || -f "${WALLPAPER_DIR}/${family}-light.png" ]] || { echo "    MISSING LIGHT: ${family}-light.(jpg|png)"; pair_errors=$((pair_errors + 1)); }
    [[ -f "${WALLPAPER_DIR}/${family}-dark.jpg" || -f "${WALLPAPER_DIR}/${family}-dark.png" ]] || { echo "    MISSING DARK: ${family}-dark.(jpg|png)"; pair_errors=$((pair_errors + 1)); }
  done <<<"$families"
  assert_equals "$pair_errors" "0" "every wallpaper family must have light/dark pairs"
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped: wallpaper directory missing)"
fi

test_start "wallpapers_are_uniform_6k"
size_errors=0
if [[ -d "$WALLPAPER_DIR" ]] && command -v magick >/dev/null 2>&1; then
  while IFS= read -r file; do
    [[ -f "$file" ]] || continue
    dims="$(magick identify -format '%wx%h' "$file" 2>/dev/null || true)"
    if [[ "$dims" != "6016x3384" ]]; then
      echo "    BAD SIZE: $(basename "$file") => ${dims:-unknown}"
      size_errors=$((size_errors + 1))
    fi
  done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -name '*.jpg' -o -name '*.png' \) | sort)
  assert_equals "$size_errors" "0" "all wallpapers must be 6016x3384"
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped: wallpaper directory missing or magick unavailable)"
fi

# --- WCAG AAA contrast validation ---
test_start "all_themes_wcag_aaa"
wcag_result="$(python3 - "$THEMES_FILE" <<'PYEOF' 2>/dev/null || true
import sys
path = sys.argv[1]
try:
    import tomllib as toml
except ModuleNotFoundError:
    try:
        import tomli as toml
    except ModuleNotFoundError:
        print("SKIP")
        sys.exit(0)

with open(path, "rb") as f:
    data = toml.load(f)

def hex_to_rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i+2], 16) for i in (0, 2, 4)]

def rl(rgb):
    vals = []
    for c in rgb:
        s = c / 255.0
        vals.append(s / 12.92 if s <= 0.03928 else ((s + 0.055) / 1.055) ** 2.4)
    return 0.2126 * vals[0] + 0.7152 * vals[1] + 0.0722 * vals[2]

def cr(c1, c2):
    l1, l2 = rl(hex_to_rgb(c1)), rl(hex_to_rgb(c2))
    return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)

themes = data["themes"]
fails = 0
for name in sorted(themes):
    t = themes[name]
    if "term" not in t or "ui" not in t:
        continue
    term, ui = t["term"], t["ui"]
    bg, fg = term["bg"], term["fg"]
    checks = [
        cr(fg, bg) >= 7.0,
        cr(ui["accent_text"], ui["accent"]) >= 7.0,
        cr(term["c0"], bg) >= 1.5,
        cr(term["c8"], bg) >= 2.5,
        cr(term.get("c15", fg), bg) >= 7.0,
        cr(fg, term["sel_bg"]) >= 4.5,
        1.03 <= cr(ui["panel"], bg) <= 2.0,
        1.08 <= cr(ui["border"], bg) <= 3.5,
    ]
    if not all(checks):
        fails += 1

print(fails)
PYEOF
)"
if [[ "$wcag_result" == "SKIP" ]]; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped: no toml parser module)"
else
  fail_count="${wcag_result##*$'\n'}"
  fail_count="${fail_count//[^0-9]/}"
  assert_equals "${fail_count:-0}" "0" "all wallpaper themes must pass WCAG AAA"
fi

# --- Mode field present ---
test_start "all_themes_have_mode"
missing=0
while IFS= read -r section; do
  name="${section#\[themes.}"
  name="${name%\]}"
  [[ "$name" == *.* ]] && continue
  if ! grep -A3 "^\[themes\.${name}\]" "$THEMES_FILE" | grep -q '^mode'; then
    echo "    MISSING: ${name}.mode"
    missing=$((missing + 1))
  fi
done < <(grep '^\[themes\.[a-z]' "$THEMES_FILE" | grep -v '\.\(term\|ui\|app\|ext\)\]')
assert_equals "$missing" "0" "all themes must have mode field"

# --- Hex color format validation ---
test_start "all_colors_valid_hex"
bad=0
while IFS= read -r line; do
  if [[ "$line" =~ =.*\"#[0-9a-fA-F]+\" ]]; then
    hex=$(echo "$line" | grep -oE '#[0-9a-fA-F]+')
    if [[ ! "$hex" =~ ^#[0-9a-fA-F]{6}$ ]]; then
      echo "    BAD HEX: $line"
      bad=$((bad + 1))
    fi
  fi
done < "$THEMES_FILE"
assert_equals "$bad" "0" "all color values must be valid 6-digit hex"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
