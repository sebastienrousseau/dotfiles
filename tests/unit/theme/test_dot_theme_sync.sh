#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# dot-theme-sync validation — verifies script structure and functions
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SCRIPT_FILE="$REPO_ROOT/dot_local/bin/executable_dot-theme-sync"

# --- Script exists ---
test_start "dot_theme_sync_exists"
assert_file_exists "$SCRIPT_FILE" "dot-theme-sync must exist"

# --- Valid syntax ---
test_start "dot_theme_sync_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

# --- Contains required functions ---
test_start "has_write_theme"
assert_file_contains "$SCRIPT_FILE" "write_theme()" "must have write_theme function"

test_start "has_current_theme"
assert_file_contains "$SCRIPT_FILE" "current_theme()" "must have current_theme function"
assert_file_contains "$SCRIPT_FILE" "CHEZMOI_CFG" "current theme should account for chezmoi override data"

test_start "has_apply_theme_configs"
assert_file_contains "$SCRIPT_FILE" "apply_theme_configs()" "must have apply_theme_configs"

test_start "has_sync_theme_state"
assert_file_contains "$SCRIPT_FILE" "sync_theme_state()" "must have sync_theme_state"
assert_file_contains "$SCRIPT_FILE" "synced data files to chezmoi override" "must report when theme state is resynchronized"

test_start "has_sync_ghostty_macos_config"
assert_file_contains "$SCRIPT_FILE" "sync_ghostty_macos_config()" "must mirror Ghostty config for macOS"
assert_file_contains "$SCRIPT_FILE" "Library/Application Support/com.mitchellh.ghostty/config" "must support Ghostty macOS app support config"

test_start "has_reload_ghostty"
assert_file_contains "$SCRIPT_FILE" "reload_ghostty()" "must have reload_ghostty"

test_start "has_reload_tmux"
assert_file_contains "$SCRIPT_FILE" "reload_tmux()" "must have reload_tmux"

test_start "has_reload_niri"
assert_file_contains "$SCRIPT_FILE" "reload_niri()" "must have reload_niri"

test_start "has_reload_desktop"
assert_file_contains "$SCRIPT_FILE" "reload_desktop()" "must have reload_desktop"

test_start "has_reload_browsers"
assert_file_contains "$SCRIPT_FILE" "reload_browsers()" "must have reload_browsers"

test_start "desktop_supports_macos"
assert_file_contains "$SCRIPT_FILE" 'uname -s' "desktop reload should detect OS"
assert_file_contains "$SCRIPT_FILE" 'Darwin' "desktop reload should support macOS"
assert_file_contains "$SCRIPT_FILE" 'osascript' "macOS desktop reload should use osascript"
assert_file_contains "$SCRIPT_FILE" 'AppleAccentColor' "macOS desktop reload should set accent color"

test_start "browser_supports_major_apps"
assert_file_contains "$SCRIPT_FILE" 'Safari.app' "browser coordination should support Safari"
assert_file_contains "$SCRIPT_FILE" 'Google Chrome.app' "browser coordination should support Chrome"
assert_file_contains "$SCRIPT_FILE" 'Microsoft Edge.app' "browser coordination should support Edge"
assert_file_contains "$SCRIPT_FILE" '.config/firefox/user.js' "browser coordination should manage Firefox config"

test_start "has_reload_nvim"
assert_file_contains "$SCRIPT_FILE" "reload_nvim()" "must have reload_nvim"

# --- Updates chezmoi.toml ---
test_start "updates_chezmoi_toml"
assert_file_contains "$SCRIPT_FILE" "chezmoi.toml" "must update chezmoi.toml"

# --- Uses DBus for Ghostty ---
test_start "ghostty_uses_dbus"
assert_file_contains "$SCRIPT_FILE" "reload-config" "must use DBus reload-config for Ghostty"

test_start "ghostty_uses_sigusr2"
assert_file_contains "$SCRIPT_FILE" "SIGUSR2" "Ghostty reload fallback should use SIGUSR2"
assert_file_contains "$SCRIPT_FILE" "/Applications/Ghostty\\.app/Contents/MacOS/ghostty" "Ghostty reload should support macOS app bundle matching"

# --- Uses niri load-config-file ---
test_start "niri_reloads_config"
assert_file_contains "$SCRIPT_FILE" "load-config-file" "must reload niri config"

# --- DMS integration uses sed -i ---
test_start "dms_uses_sed_inplace"
assert_file_contains "$SCRIPT_FILE" "sed -i" "must use sed -i for DMS settings"

# --- DMS stock theme mapping covers all families ---
test_start "dms_mapping_complete"
for family in catppuccin dracula gruvbox nord rose-pine tokyonight kanagawa solarized everforest onedark macos-monterey macos-ventura macos-sonoma; do
  if ! grep -q "$family" "$SCRIPT_FILE"; then
    echo "    MISSING DMS mapping: $family"
    ((TESTS_FAILED++))
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST — missing $family"
    break
  fi
done
((TESTS_PASSED++))
printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"

# --- Validates theme name ---
test_start "validates_theme_name"
assert_file_contains "$SCRIPT_FILE" 'a-zA-Z0-9_-' "must validate theme name characters"

# --- Usage/help text ---
test_start "has_usage"
assert_file_contains "$SCRIPT_FILE" "usage()" "must have usage function"
assert_file_contains "$SCRIPT_FILE" "Browsers   desktop sync + Firefox content preference" "usage should mention browser coordination"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
