#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# AI CLI appearance adapters must preserve user config while selecting the
# wallpaper-aware terminal theme.
# shellcheck disable=SC1090,SC1091
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ADAPTER="$REPO_ROOT/scripts/theme/sync-ai-cli-themes.py"
THEMES="$REPO_ROOT/defaults/.chezmoidata/themes.toml"
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT

mkdir -p \
  "$SANDBOX/.codex/themes" \
  "$SANDBOX/.claude" \
  "$SANDBOX/.gemini/antigravity-cli" \
  "$SANDBOX/.config/opencode"
printf '%s\n' 'model = "test"' '[tui.model_availability_nux]' '"gpt-test" = 1' >"$SANDBOX/.codex/config.toml"
printf '%s\n' '<plist></plist>' >"$SANDBOX/.codex/themes/dotfiles.tmTheme"
printf '%s\n' '{"permissions":{"defaultMode":"auto"}}' >"$SANDBOX/.claude/settings.json"
printf '%s\n' '{"security":{"auth":{"selectedType":"test"}}}' >"$SANDBOX/.gemini/settings.json"
printf '%s\n' '{"enableTerminalSandbox":true}' >"$SANDBOX/.gemini/antigravity-cli/settings.json"

test_start "ai_theme_adapter_exists"
assert_file_exists "$ADAPTER" "AI CLI theme adapter must exist"

test_start "ai_theme_adapter_updates_light_mode"
output="$(python3 "$ADAPTER" --theme maui-light --themes-file "$THEMES" --home "$SANDBOX")"
assert_equals "codex,claude,gemini,agy,opencode" "$output" \
  "every installed provider adapter must run"

test_start "ai_theme_adapter_preserves_existing_config"
assert_file_contains "$SANDBOX/.claude/settings.json" '"permissions"' "Claude permissions survive"
assert_file_contains "$SANDBOX/.gemini/settings.json" '"security"' "Gemini authentication survives"
assert_file_contains "$SANDBOX/.gemini/antigravity-cli/settings.json" '"enableTerminalSandbox"' \
  "Antigravity sandbox setting survives"

test_start "ai_theme_adapter_selects_provider_modes"
assert_file_contains "$SANDBOX/.codex/config.toml" 'theme = "dotfiles"' "Codex selects custom theme"
assert_file_contains "$SANDBOX/.gemini/settings.json" '"theme": "ANSI Light"' \
  "Gemini uses the light ANSI palette"
assert_file_contains "$SANDBOX/.gemini/antigravity-cli/settings.json" '"colorScheme": "terminal"' \
  "Antigravity inherits wallpaper colours"
assert_file_contains "$SANDBOX/.config/opencode/cli.json" '"name": "system"' \
  "OpenCode inherits the terminal palette"
assert_file_contains "$SANDBOX/.config/opencode/cli.json" '"mode": "light"' \
  "OpenCode receives the active mode"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
