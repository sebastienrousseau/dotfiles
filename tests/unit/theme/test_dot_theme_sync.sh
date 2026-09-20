#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# dot-theme-sync validation — verifies script structure and functions
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/bin/dot-theme-sync"
AUTO_AGENT="$REPO_ROOT/defaults/private_Library/LaunchAgents/com.sebastienrousseau.dot-theme-auto.plist.tmpl"
AUTO_INSTALLER="$REPO_ROOT/defaults/run_onchange_after_31-theme-auto-launchagent.sh.tmpl"
TMUX_AI="$REPO_ROOT/defaults/dot_local/bin/executable_tmux-ai"
TMUX_STATUS="$REPO_ROOT/defaults/dot_local/bin/executable_tmux-status"
TMUX_TEMPLATE="$REPO_ROOT/defaults/dot_config/tmux/tmux.conf.tmpl"
CODEX_THEME="$REPO_ROOT/defaults/dot_codex/themes/dotfiles.tmTheme.tmpl"
KITTY_TEMPLATE="$REPO_ROOT/defaults/dot_config/kitty/kitty.conf.tmpl"
GHOSTTY_TEMPLATE="$REPO_ROOT/defaults/dot_config/ghostty/config.tmpl"
ALACRITTY_TEMPLATE="$REPO_ROOT/defaults/dot_config/alacritty/alacritty.toml.tmpl"
WEZTERM_TEMPLATE="$REPO_ROOT/defaults/dot_config/wezterm/wezterm.lua.tmpl"
FOOT_TEMPLATE="$REPO_ROOT/defaults/dot_config/foot/foot.ini.tmpl"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

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

test_start "regenerates_prompt_and_terminal_palettes"
assert_file_contains "$SCRIPT_FILE" '.config/starship.toml' "theme sync must regenerate Starship"
assert_file_contains "$SCRIPT_FILE" '.config/kitty/kitty.conf' "theme sync must regenerate Kitty"
assert_file_contains "$SCRIPT_FILE" '.config/tmux/tmux.conf' "theme sync must regenerate tmux"
assert_file_contains "$SCRIPT_FILE" '.codex/themes/dotfiles.tmTheme' "theme sync must regenerate Codex"
assert_file_contains "$SCRIPT_FILE" 'run_onchange_22-iterm2-profile.sh.tmpl' \
  "targeted theme sync must regenerate the iTerm2 dynamic profile"

test_start "terminal_palettes_render_opaque"
assert_file_contains "$KITTY_TEMPLATE" 'background_opacity 1.0' "Kitty must preserve tested sRGB colors"
assert_file_contains "$GHOSTTY_TEMPLATE" 'background-opacity = 1.0' "Ghostty must preserve tested sRGB colors"
assert_file_contains "$ALACRITTY_TEMPLATE" 'opacity = 1.0' "Alacritty must preserve tested sRGB colors"
assert_file_contains "$WEZTERM_TEMPLATE" 'window_background_opacity = 1.0' "WezTerm must preserve tested sRGB colors"
assert_file_contains "$FOOT_TEMPLATE" 'alpha=1.0' "Foot must preserve tested sRGB colors"

test_start "stores_runtime_theme_in_machine_config"
assert_file_contains "$SCRIPT_FILE" "set_machine_data_value()" "must atomically manage machine-local theme data"
assert_file_contains "$SCRIPT_FILE" "set_machine_data_value theme_family" "must persist the selected family"
assert_file_contains "$SCRIPT_FILE" "set_machine_data_value theme_mode" "must persist auto/manual mode"

test_start "has_sync_ghostty_macos_config"
assert_file_contains "$SCRIPT_FILE" "sync_ghostty_macos_config()" "must mirror Ghostty config for macOS"
assert_file_contains "$SCRIPT_FILE" "Library/Application Support/com.mitchellh.ghostty/config" "must support Ghostty macOS app support config"

test_start "has_reload_ghostty"
assert_file_contains "$SCRIPT_FILE" "reload_ghostty()" "must have reload_ghostty"

test_start "has_reload_tmux"
assert_file_contains "$SCRIPT_FILE" "reload_tmux()" "must have reload_tmux"
assert_file_contains "$SCRIPT_FILE" "refresh-client" "tmux reload must redraw attached clients"

test_start "has_reload_kitty"
assert_file_contains "$SCRIPT_FILE" "reload_kitty()" "must have reload_kitty"
assert_file_contains "$SCRIPT_FILE" "/Applications/kitty\\.app/Contents/MacOS/kitty" \
  "Kitty reload should support macOS app bundle matching"

test_start "starship_uses_wallpaper_palette"
STARSHIP_TEMPLATE="$REPO_ROOT/defaults/dot_config/starship.toml.tmpl"
assert_file_contains "$STARSHIP_TEMPLATE" 'palette = "wallpaper"' \
  "Starship must use the wallpaper-derived palette"
assert_file_contains "$STARSHIP_TEMPLATE" '$t.term.c4' \
  "Starship blue must come from the active theme"

test_start "tmux_has_minimal_ai_aware_status"
assert_file_exists "$TMUX_AI" "AI-aware tmux helper must exist"
assert_file_exists "$TMUX_STATUS" "multi-session tmux helper must exist"
assert_file_contains "$TMUX_STATUS" 'blend_colour' \
  "session names must select stable, distinct wallpaper-derived colours"
assert_file_contains "$TMUX_STATUS" 'used+="$colour|"' \
  "active sessions must avoid colour collisions"
assert_file_contains "$TMUX_TEMPLATE" 'AI CLI cockpit' "prefix+A must expose the AI launcher"
assert_file_contains "$TMUX_TEMPLATE" 'set -g focus-events on' "tmux must receive terminal focus events"
assert_file_contains "$TMUX_TEMPLATE" '@dot_session_colour' "session names must use their own colour"
assert_file_contains "$TMUX_TEMPLATE" 'client_prefix' "session name must react to prefix state"
assert_file_contains "$TMUX_TEMPLATE" '#{?client_prefix, , }#S' \
  "session name must be the primary left-side identity"
assert_file_contains "$TMUX_TEMPLATE" 'status-justify left' \
  "minimal status must place session and windows in one compact group"
assert_file_contains "$TMUX_TEMPLATE" 'window_zoomed_flag' "window list must show zoom state"
assert_file_contains "$TMUX_TEMPLATE" '#I:#W#F' "window list must retain native state flags"
assert_file_contains "$TMUX_TEMPLATE" 'tmux-status system' \
  "wide clients must show one lightweight cross-platform system sample"
assert_file_contains "$TMUX_TEMPLATE" '@dot_status_show_system' \
  "system monitoring must remain user-configurable"
assert_file_contains "$TMUX_TEMPLATE" '@dot_status_padded' \
  "status height must remain user-configurable"
assert_file_contains "$TMUX_TEMPLATE" 'status-format[1]' \
  "padded status must add a neutral breathing row"
assert_file_contains "$TMUX_TEMPLATE" 'e|>=:#{client_width},120' \
  "system monitoring must disappear on narrow clients"
assert_file_contains "$TMUX_TEMPLATE" 'set-environment -g COLORFGBG' \
  "tmux panes must inherit a reliable light/dark appearance signal"
assert_equals "Code/project" "$(bash "$TMUX_STATUS" short-path /Users/seb/Code/project)" \
  "working directory context must stay compact"
assert_equals "AI:CODEX" "$(bash "$TMUX_AI" status codex 0)" \
  "Codex sessions receive an explicit provider badge"
assert_equals "AI:CLAUDE" "$(bash "$TMUX_AI" status claude 0)" \
  "Claude sessions receive an explicit provider badge"
assert_file_exists "$CODEX_THEME" "Codex must receive a wallpaper-derived syntax theme"
assert_file_contains "$SCRIPT_FILE" 'sync_ai_cli_themes' \
  "theme sync must coordinate installed AI provider CLIs"

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

test_start "macos_auto_theme_agent"
assert_file_exists "$AUTO_AGENT" "macOS auto-theme LaunchAgent must exist"
assert_file_contains "$AUTO_AGENT" "WatchPaths" "agent must react to macOS preference changes"
assert_file_contains "$AUTO_AGENT" "--if-auto" "agent must respect manual mode"
assert_file_contains "$AUTO_AGENT" "/opt/homebrew/bin" "agent must expose Homebrew tools under launchd"
assert_file_exists "$AUTO_INSTALLER" "chezmoi must reload the agent when it changes"
assert_file_contains "$AUTO_INSTALLER" "launchctl bootstrap" "installer must bootstrap the LaunchAgent"

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

# --- macOS accent reads from themes.toml (wallpaper-driven) ---
test_start "macos_accent_from_themes_toml"
if grep -q 'macos_accent' "$SCRIPT_FILE"; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST — missing macos_accent lookup"
fi

# --- Validates theme name ---
test_start "validates_theme_name"
assert_file_contains "$SCRIPT_FILE" 'a-zA-Z0-9_-' "must validate theme name characters"

# --- Usage/help text ---
test_start "has_usage"
assert_file_contains "$SCRIPT_FILE" "usage()" "must have usage function"
assert_file_contains "$SCRIPT_FILE" "Browsers   desktop sync + Firefox content preference" "usage should mention browser coordination"

# Slice 2: drive real line coverage of the script under test
cov_exercise_script "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
