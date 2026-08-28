#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Behavioural tests for scripts/theme/switch.sh subcommand dispatch:
# accent, diff, mode (dark/light/auto), wallpaper, fit, export/import,
# and --dry-run on dot-theme-sync. Uses PATH-injected mocks so no real
# gsettings / kwriteconfig / dot-theme-sync side effects happen.
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SWITCH_SH="$REPO_ROOT/scripts/theme/switch.sh"

# --- Sandbox -----------------------------------------------------------------
TMPHOME="$(mktemp -d)"
trap 'rm -rf "$TMPHOME"' EXIT
export HOME="$TMPHOME"
export XDG_STATE_HOME="$TMPHOME/state"
mkdir -p "$XDG_STATE_HOME/dot"

# Fake dotfiles source so switch.sh's THEMES_FILE points at fixture data.
mkdir -p "$TMPHOME/dotfiles/.chezmoidata"
export CHEZMOI_SOURCE_DIR="$TMPHOME/dotfiles"
cat > "$TMPHOME/dotfiles/.chezmoidata.toml" <<'EOF'
theme = "Solar-dark"
EOF
cat > "$TMPHOME/dotfiles/.chezmoidata/themes.toml" <<'EOF'
[themes.Solar-dark]
mode = "dark"
family = "Solar"
wallpaper = "/tmp/solar.heic"
macos_accent = 3

[themes.Solar-dark.ui]
accent = "#2ecc71"

[themes.Solar-dark.term]
bg = "#101010"
fg = "#eeeeee"

[themes.Solar-light]
mode = "light"
family = "Solar"
wallpaper = "/tmp/solar.heic"
macos_accent = 3

[themes.Solar-light.ui]
accent = "#27ae60"

[themes.Solar-light.term]
bg = "#f0f0f0"
fg = "#111111"

[themes.Bauhaus-dark]
mode = "dark"
family = "Bauhaus"
wallpaper = "/tmp/bauhaus.heic"
macos_accent = 1

[themes.Bauhaus-dark.ui]
accent = "#f67400"

[themes.Bauhaus-dark.term]
bg = "#181818"
fg = "#dddddd"

[themes.Bauhaus-light]
mode = "light"
family = "Bauhaus"
wallpaper = "/tmp/bauhaus.heic"
macos_accent = 1

[themes.Bauhaus-light.ui]
accent = "#e65c00"

[themes.Bauhaus-light.term]
bg = "#f5f5f5"
fg = "#232323"
EOF

# --- PATH mocks --------------------------------------------------------------
MOCK_BIN="$TMPHOME/mocks"
mkdir -p "$MOCK_BIN"
export PATH="$MOCK_BIN:$PATH"
LOG="$TMPHOME/mock.log"

# gsettings mock — records get/set operations, echoes plausible defaults.
cat > "$MOCK_BIN/gsettings" <<EOF
#!/usr/bin/env bash
printf 'gsettings %s\n' "\$*" >> "$LOG"
case "\$1 \$2 \$3" in
  "get org.gnome.desktop.interface color-scheme") echo "'prefer-dark'" ;;
  "get org.gnome.desktop.interface accent-color") echo "'green'" ;;
  "get org.gnome.desktop.interface cursor-theme") echo "'Bibata-Modern-Classic'" ;;
  "get org.gnome.desktop.background picture-uri") echo "'file:///tmp/solar-0.png'" ;;
  "get org.gnome.desktop.background picture-uri-dark") echo "'file:///tmp/solar-1.png'" ;;
  "get org.gnome.desktop.background picture-options") echo "'zoom'" ;;
esac
exit 0
EOF
chmod +x "$MOCK_BIN/gsettings"

# kwriteconfig6 mock — logs writes.
cat > "$MOCK_BIN/kwriteconfig6" <<EOF
#!/usr/bin/env bash
printf 'kwriteconfig6 %s\n' "\$*" >> "$LOG"
exit 0
EOF
chmod +x "$MOCK_BIN/kwriteconfig6"

# kreadconfig6 mock — returns empty (no KDE state).
cat > "$MOCK_BIN/kreadconfig6" <<EOF
#!/usr/bin/env bash
printf 'kreadconfig6 %s\n' "\$*" >> "$LOG"
exit 0
EOF
chmod +x "$MOCK_BIN/kreadconfig6"

# dot-theme-sync mock — records the arguments it was called with.
cat > "$MOCK_BIN/dot-theme-sync" <<EOF
#!/usr/bin/env bash
printf 'dot-theme-sync %s\n' "\$*" >> "$LOG"
echo "mock dot-theme-sync called with: \$*"
exit 0
EOF
chmod +x "$MOCK_BIN/dot-theme-sync"

# qdbus stub
cat > "$MOCK_BIN/qdbus" <<EOF
#!/usr/bin/env bash
printf 'qdbus %s\n' "\$*" >> "$LOG"
exit 0
EOF
chmod +x "$MOCK_BIN/qdbus"

# hostname stub (avoid actual hostname leakage into golden fixtures)
cat > "$MOCK_BIN/hostname" <<EOF
#!/usr/bin/env bash
echo "test-host"
EOF
chmod +x "$MOCK_BIN/hostname"

# Helpers used by switch.sh assume `dot theme ...` command form. We
# invoke it directly as `bash switch.sh ...`, so the top-of-file
# variable resolution still works.
_run_theme() {
  # Run in a subshell so `exit` inside switch.sh doesn't kill us.
  ( bash "$SWITCH_SH" "$@" )
}

_reset_log() { : > "$LOG"; }

# Simple substring check on already-captured output. Sidesteps
# assert_output_contains which uses eval on its second arg — that
# barfs on ANSI escape sequences and unicode markers (✗) that our
# UI helpers emit.
_contains() {
  local needle="$1" haystack="$2" msg="${3:-output should contain}"
  if [[ "$haystack" == *"$needle"* ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $msg '$needle'"
    return 0
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: expected '$needle' in output"
    printf '    Actual: %s\n' "$haystack" | head -3
    return 1
  fi
}

# ---------------------------------------------------------------------------
# accent
# ---------------------------------------------------------------------------
test_start "accent_by_name_calls_gsettings"
_reset_log
_run_theme accent blue > /dev/null 2>&1
grep -q "gsettings set org.gnome.desktop.interface accent-color blue" "$LOG"
assert_equals 0 $? "accent blue writes gsettings accent-color=blue"

test_start "accent_by_int_translates_to_gnome_name"
_reset_log
_run_theme accent 4 > /dev/null 2>&1  # 4 = blue in macos_accent scale
grep -q "gsettings set org.gnome.desktop.interface accent-color blue" "$LOG"
assert_equals 0 $? "accent 4 translates to blue"

test_start "accent_writes_kde_hex_to_kdeglobals"
_reset_log
_run_theme accent green > /dev/null 2>&1
grep -q "kwriteconfig6 --file kdeglobals --group General --key AccentColor #2ecc71" "$LOG"
assert_equals 0 $? "accent green writes KDE hex #2ecc71"

test_start "accent_rejects_invalid_name"
out="$(_run_theme accent chartreuse 2>&1)"
_contains "Usage" "$out" "invalid accent name is rejected"

# ---------------------------------------------------------------------------
# mode
# ---------------------------------------------------------------------------
test_start "mode_dark_targets_family_dark"
_reset_log
# Current theme is Solar-dark; asking for dark is a no-op.
out="$(_run_theme mode dark 2>&1)"
_contains "already in dark mode" "$out" "no-op reported"

test_start "mode_light_calls_dot_theme_sync"
_reset_log
out="$(_run_theme mode light 2>&1)"
grep -q "dot-theme-sync Solar-light" "$LOG"
assert_equals 0 $? "mode light -> dot-theme-sync Solar-light"

test_start "mode_auto_calls_sync_theme"
_reset_log
out="$(_run_theme mode auto 2>&1)"
# sync_theme uses gsettings to read color-scheme
grep -q "gsettings get org.gnome.desktop.interface color-scheme" "$LOG"
assert_equals 0 $? "mode auto -> sync_theme reads gsettings color-scheme"

test_start "mode_rejects_invalid_value"
out="$(_run_theme mode purple 2>&1)"
_contains "Usage" "$out"

# ---------------------------------------------------------------------------
# diff
# ---------------------------------------------------------------------------
test_start "diff_flags_differing_family"
out="$(_run_theme diff Solar-dark Bauhaus-dark 2>&1)"
_contains "Solar" "$out" "shows Solar side"
_contains "Bauhaus" "$out" "shows Bauhaus side"
_contains "≠" "$out" "marks differing rows"

test_start "diff_same_theme_has_no_delta_marks"
out="$(_run_theme diff Solar-dark Solar-dark 2>&1)"
if grep -q "≠" <<<"$out"; then
  ((TESTS_FAILED++)) || true
  printf '  ✗ %s (unexpected ≠ mark)\n' "$CURRENT_TEST"
else
  ((TESTS_PASSED++)) || true
  printf '  ✓ %s\n' "$CURRENT_TEST"
fi

test_start "diff_rejects_unknown_theme"
out="$(_run_theme diff Solar-dark Nonesuch-dark 2>&1)"
_contains "Unknown" "$out"

# ---------------------------------------------------------------------------
# wallpaper
# ---------------------------------------------------------------------------
test_start "wallpaper_sets_via_gsettings_on_gnome"
_reset_log
touch "$TMPHOME/dummy.png"
_run_theme wallpaper "$TMPHOME/dummy.png" > /dev/null 2>&1
grep -q "gsettings set org.gnome.desktop.background picture-uri file://$TMPHOME/dummy.png" "$LOG"
assert_equals 0 $? "wallpaper writes picture-uri"

test_start "wallpaper_also_sets_picture_uri_dark"
grep -q "gsettings set org.gnome.desktop.background picture-uri-dark file://$TMPHOME/dummy.png" "$LOG"
assert_equals 0 $? "wallpaper mirrors to picture-uri-dark"

test_start "wallpaper_rejects_missing_file"
out="$(_run_theme wallpaper /nonesuch/does-not-exist.png 2>&1)"
_contains "not found" "$out"

# ---------------------------------------------------------------------------
# fit
# ---------------------------------------------------------------------------
test_start "fit_valid_mode_writes_picture_options"
_reset_log
_run_theme fit spanned > /dev/null 2>&1
grep -q "gsettings set org.gnome.desktop.background picture-options spanned" "$LOG"
assert_equals 0 $? "fit spanned -> picture-options spanned"

test_start "fit_rejects_invalid_mode"
out="$(_run_theme fit stretched-ish 2>&1)"
_contains "Usage" "$out"

# ---------------------------------------------------------------------------
# export / import
# ---------------------------------------------------------------------------
test_start "export_emits_json_with_current_theme"
out="$(_run_theme export - 2>&1)"
_contains "\"theme\": \"Solar-dark\"" "$out"
_contains "\"version\": 1" "$out"

test_start "export_to_file_writes_json"
_run_theme export "$TMPHOME/snap.json" > /dev/null 2>&1
if [[ -f "$TMPHOME/snap.json" ]] && grep -q "Solar-dark" "$TMPHOME/snap.json"; then
  ((TESTS_PASSED++)) || true
  printf '  ✓ %s\n' "$CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '  ✗ %s\n' "$CURRENT_TEST"
fi

test_start "import_calls_dot_theme_sync_with_theme"
_reset_log
_run_theme import "$TMPHOME/snap.json" > /dev/null 2>&1
grep -q "dot-theme-sync Solar-dark" "$LOG"
assert_equals 0 $? "import invokes dot-theme-sync Solar-dark"

test_start "import_rejects_theme_not_in_themes_toml"
cat > "$TMPHOME/bad.json" <<'EOF'
{ "version": 1, "theme": "Chartreuse-dark", "fit": "" }
EOF
out="$(_run_theme import "$TMPHOME/bad.json" 2>&1)"
_contains "not in themes.toml" "$out"

test_start "import_rejects_missing_file"
out="$(_run_theme import /nonesuch.json 2>&1)"
_contains "Usage" "$out"

# ---------------------------------------------------------------------------
# --dry-run on the sync backend — testable via the mocked binary being
# skipped when --dry-run short-circuits inside dot-theme-sync. We can't
# fully exercise it here because dot-theme-sync itself is mocked; the
# multi_de test file already covers _load_theme_fields end-to-end.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '%b\n' "  Tests: ${TESTS_RUN}  ${GREEN}Passed: ${TESTS_PASSED}${NC}  ${RED}Failed: ${TESTS_FAILED}${NC}"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
