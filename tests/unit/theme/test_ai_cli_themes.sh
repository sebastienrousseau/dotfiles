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
SANDBOX="$(mktemp -d)"
trap 'rm -rf "$SANDBOX"' EXIT
# The adapter reads the palette.v1 contract, never the theme manifest.
LIGHT="$SANDBOX/light.env"
DARK="$SANDBOX/dark.env"
printf 'DOT_PALETTE=palette.v1\nTHEME=maui-light\nMODE=light\n' >"$LIGHT"
printf 'DOT_PALETTE=palette.v1\nTHEME=maui-dark\nMODE=dark\n' >"$DARK"

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
output="$(python3 "$ADAPTER" --palette "$LIGHT" --home "$SANDBOX")"
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

printf '%s\n' '{not-json' >"$SANDBOX/.gemini/settings.json"
invalid_before="$(shasum -a 256 "$SANDBOX/.gemini/settings.json" | awk '{print $1}')"
result_json="$(python3 "$ADAPTER" --palette "$DARK" \
  --home "$SANDBOX" --json)"

test_start "ai_theme_adapter_emits_typed_results"
assert_output_contains '1.0|dark|invalid_config' \
  "printf '%s' '$result_json' | python3 -c 'import json,sys; d=json.load(sys.stdin); g=next(p for p in d[\"providers\"] if p[\"provider\"] == \"gemini\"); print(d[\"schema_version\"], d[\"mode\"], g[\"status\"], sep=\"|\")'"

test_start "ai_theme_adapter_preserves_malformed_json"
assert_equals "$invalid_before" \
  "$(shasum -a 256 "$SANDBOX/.gemini/settings.json" | awk '{print $1}')" \
  "malformed provider config must remain byte-identical"

printf '%s\n' 'not = [valid' >"$SANDBOX/.codex/config.toml"
codex_before="$(shasum -a 256 "$SANDBOX/.codex/config.toml" | awk '{print $1}')"
result_json="$(python3 "$ADAPTER" --palette "$DARK" \
  --home "$SANDBOX" --json)"

test_start "ai_theme_adapter_preserves_malformed_toml"
assert_equals "$codex_before" \
  "$(shasum -a 256 "$SANDBOX/.codex/config.toml" | awk '{print $1}')" \
  "malformed Codex config must remain byte-identical"

policy="$SANDBOX/features.toml"
cat >"$policy" <<'TOML'
[features]
ai_theme_sync = false
TOML
claude_before="$(shasum -a 256 "$SANDBOX/.claude/settings.json" | awk '{print $1}')"
result_json="$(python3 "$ADAPTER" --palette "$DARK" \
  --home "$SANDBOX" --defaults-config "$policy" --json)"

test_start "ai_theme_adapter_honours_global_opt_out"
assert_output_contains 'disabled' \
  "printf '%s' '$result_json' | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(p[\"status\"] for p in d[\"providers\"] if p[\"provider\"] == \"claude\"))'"

test_start "ai_theme_adapter_opt_out_performs_no_write"
assert_equals "$claude_before" \
  "$(shasum -a 256 "$SANDBOX/.claude/settings.json" | awk '{print $1}')"

cat >"$policy" <<'TOML'
[features]
ai_theme_sync = true

[features.ai_theme_providers]
gemini = false
TOML
result_json="$(python3 "$ADAPTER" --palette "$DARK" \
  --home "$SANDBOX" --defaults-config "$policy" --json)"

test_start "ai_theme_adapter_honours_provider_opt_out"
assert_output_contains 'disabled' \
  "printf '%s' '$result_json' | python3 -c 'import json,sys; d=json.load(sys.stdin); print(next(p[\"status\"] for p in d[\"providers\"] if p[\"provider\"] == \"gemini\"))'"

cas_file="$SANDBOX/cas-provider.json"
printf '%s\n' '{"owner":"original"}' >"$cas_file"
cat >"$SANDBOX/test-cas.py" <<'PY'
import pathlib
import runpy
import sys

module = runpy.run_path(sys.argv[1])
target = pathlib.Path(sys.argv[2])
expected = module["content_hash"](target)
target.write_text('{"owner":"concurrent"}\n', encoding="utf-8")
try:
    module["atomic_text"](target, '{"owner":"dot"}\n', expected_hash=expected)
except module["ConcurrentModificationError"]:
    pass
else:
    raise SystemExit("compare-before-commit accepted stale input")
if target.read_text(encoding="utf-8") != '{"owner":"concurrent"}\n':
    raise SystemExit("concurrent content was overwritten")
PY

test_start "ai_theme_adapter_rejects_concurrent_modification"
assert_exit_code 0 "python3 '$SANDBOX/test-cas.py' '$ADAPTER' '$cas_file'"

test_start "ai_theme_result_schema_is_committed"
assert_file_exists "$REPO_ROOT/schemas/ai-theme-result.schema.json"

test_start "ai_theme_adapter_refuses_a_file_that_is_not_a_palette"
printf 'theme = "maui-dark"\n' >"$SANDBOX/not-a-palette.toml"
rc=0
err="$(python3 "$ADAPTER" --palette "$SANDBOX/not-a-palette.toml" --home "$SANDBOX" 2>&1)" || rc=$?
assert_equals "2" "$rc" "a file without DOT_PALETTE=palette.v1 is a usage error"
assert_contains "is not a palette.v1 file" "$err" "and says why"

test_start "ai_theme_adapter_refuses_a_palette_without_a_theme"
printf 'DOT_PALETTE=palette.v1\nMODE=dark\n' >"$SANDBOX/nameless.env"
rc=0
err="$(python3 "$ADAPTER" --palette "$SANDBOX/nameless.env" --home "$SANDBOX" 2>&1)" || rc=$?
assert_equals "2" "$rc" "a palette that names no theme is refused"
assert_contains "THEME must name a theme" "$err" "and says why"

test_start "ai_theme_adapter_refuses_an_unknown_mode"
printf 'DOT_PALETTE=palette.v1\nTHEME=maui-dark\nMODE=sepia\n' >"$SANDBOX/sepia.env"
rc=0
err="$(python3 "$ADAPTER" --palette "$SANDBOX/sepia.env" --home "$SANDBOX" 2>&1)" || rc=$?
assert_equals "2" "$rc" "a mode other than dark or light is refused"
assert_contains "MODE must be dark or light" "$err" "and named"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
