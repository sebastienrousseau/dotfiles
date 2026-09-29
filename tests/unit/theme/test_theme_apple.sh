#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Behavioural tests for scripts/theme/apple.py: Apple system colours resolved
# to WCAG AAA, the palette pass, and the committed tmux session table.
# shellcheck disable=SC1090,SC1091,SC2034

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

APPLE="$REPO_ROOT/scripts/theme/apple.py"
WORK="$(mktemp -d -t dot-theme-apple.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
CATALOG="$REPO_ROOT/defaults/.chezmoidata/themes.toml"

py() {
  PYTHONPATH="$REPO_ROOT/scripts/theme" python3 -c "import aaa, apple
$1"
}

test_start "apple_values_match_the_hig_table"
# Spot values from the HIG system colour table (June 9 2025): Default light,
# Default dark, Increased contrast light, Increased contrast dark.
got="$(py 'print(apple.SYSTEM["red"], apple.SYSTEM["blue"], apple.SYSTEM["brown"])')"
assert_equals "('#ff383c', '#ff4245', '#e9152d', '#ff6165') ('#0088ff', '#0091ff', '#1e6ef4', '#5cb8ff') ('#ac7f5e', '#b78a66', '#956d51', '#dba679')" "$got"

test_start "apple_text_prefers_default_then_increased_contrast"
got="$(py '
print(apple.text("green", True, ["#1c1c1e"]))   # Default dark reaches 7:1
print(apple.text("blue", True, ["#1c1c1e"]))    # Default 5.26, IC 7.90
')"
assert_equals $'#30d158\n#5cb8ff' "$got" "exact Apple values whenever they reach 7:1"

test_start "apple_text_adjusts_only_when_apple_values_cannot_reach_aaa"
got="$(py '
out = apple.text("blue", False, ["#ffffff"])
print(out not in apple.SYSTEM["blue"], aaa.contrast(aaa.hex_rgb(out), aaa.hex_rgb("#ffffff")) >= 7)
')"
assert_equals "True True" "$got" "light-mode blue is deepened to 7:1"

test_start "apple_block_picks_a_7_to_1_label"
got="$(py '
for dark in (True, False):
    for name in apple.SYSTEM:
        b, lab = apple.block(name, dark)
        assert aaa.contrast(aaa.hex_rgb(b), aaa.hex_rgb(lab)) >= 7, (name, dark, b, lab)
print(apple.block("orange", False))
')"
assert_equals "('#ff8d28', '#000000')" "$got" "every block reads at 7:1; light orange is Apple exact with black"

test_start "apple_sessions_are_distinct_and_aaa"
got="$(py '
for dark in (True, False):
    s = apple.sessions(dark)
    assert len({b for b, _ in s}) == 12, s
    assert all(aaa.contrast(aaa.hex_rgb(b), aaa.hex_rgb(l)) >= 7 for b, l in s)
print("ok")
')"
assert_equals "ok" "$got" "12 distinct session blocks per mode, each AAA"

test_start "apple_large_text_sessions_are_exact_default_values"
got="$(py '
for dark in (True, False):
    s = apple.sessions(dark, apple.LARGE_TEXT_RATIO)
    exact = [apple.variants(n, dark)[0] for n in apple.SYSTEM]
    assert [b for b, _ in s] == exact, s
    assert all(aaa.contrast(aaa.hex_rgb(b), aaa.hex_rgb(l)) >= 4.5 for b, l in s)
print("ok")
')"
assert_equals "ok" "$got" "all 12 blocks are Apple Default, labels at WCAG AAA large-text 4.5:1"

test_start "apple_session_table_follows_font_size"
# Bar labels at 18pt or more are large text: exact Apple values; smaller
# fonts fall back to the 7:1 table.
if command -v chezmoi >/dev/null 2>&1; then
  for size in 20 12; do
    chezmoi execute-template --source "$REPO_ROOT/defaults" \
      --override-data "{\"theme\":\"maui-dark\",\"terminal_font_size\":$size}" \
      <"$REPO_ROOT/defaults/dot_config/tmux/tmux.conf.tmpl" >"$WORK/tmux-$size.conf"
  done
  assert_file_contains "$WORK/tmux-20.conf" "apply-colours '#ff4245/#000000'"
  assert_file_contains "$WORK/tmux-12.conf" "apply-colours '#ff6165/#000000'"
else
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST (skipped: chezmoi unavailable)"
fi

test_start "apple_session_table_is_committed_and_current"
assert_exit_code 0 "python3 '$APPLE' >/dev/null"

test_start "apple_catalog_uses_apple_status_colours"
got="$(
  PYTHONPATH="$REPO_ROOT/scripts/theme" python3 - "$CATALOG" <<'PY'
import sys, tomllib, apple
t = tomllib.load(open(sys.argv[1], "rb"))["themes"]
print(t["maui-dark"]["ui"]["error"], t["maui-dark"]["ui"]["success"], t["maui-dark"]["ui"]["status_text"])
PY
)"
assert_equals "#ff8ac4 #30d158 #000000" "$got" "dark status blocks are Apple pink and green with black labels"

test_start "apple_pass_is_idempotent"
got="$(
  PYTHONPATH="$REPO_ROOT/scripts/theme" python3 - "$CATALOG" <<'PY'
import sys, tomllib, aaa, apple
t = tomllib.load(open(sys.argv[1], "rb"))["themes"]
once = aaa.enforce(apple.apply(t["altai-light"]))
print(aaa.enforce(apple.apply(once)) == once)
PY
)"
assert_equals "True" "$got" "a resolved palette maps to itself"

test_start "apple_generator_emits_a_complete_aaa_theme"
# The generator's TOML writer once used a fixed key list and silently dropped
# the derived roles; the emitted block must pass the audit on its own.
python3 - "$REPO_ROOT/scripts/theme" >"$WORK/gen.toml" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("et", sys.argv[1] + "/extract-theme.py")
et = importlib.util.module_from_spec(spec)
spec.loader.exec_module(et)
clusters = [((22.0, 18.0, 20.0), 500), ((55.0, 45.0, 50.0), 300), ((60.0, -20.0, -40.0), 200), ((70.0, -40.0, 30.0), 100)]
for dark in (True, False):
    theme = et.generate_theme(clusters, "gen-" + ("dark" if dark else "light"), dark)
    print(et.theme_to_toml(theme) + "\n")
PY
assert_exit_code 0 "python3 '$REPO_ROOT/scripts/theme/audit-palettes.py' '$WORK/gen.toml' >/dev/null"
assert_file_contains "$WORK/gen.toml" "on_secondary_container = "
assert_file_contains "$WORK/gen.toml" "status_text = "

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
