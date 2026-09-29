#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Behavioural tests for scripts/theme/aaa.py, the WCAG AAA (7:1) text pass
# shared by the wallpaper generator and the committed catalog.
# shellcheck disable=SC1090,SC1091,SC2034

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

AAA="$REPO_ROOT/scripts/theme/aaa.py"
AUDIT="$REPO_ROOT/scripts/theme/audit-palettes.py"
WORK="$(mktemp -d -t dot-theme-aaa.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# py <code>: run Python with aaa importable, printing whatever the code prints.
py() {
  PYTHONPATH="$REPO_ROOT/scripts/theme" python3 -c "import aaa
$1"
}

# A dark and a light theme whose text colours sit at the old AA-era floors:
# c8 at 2.5:1, dark ANSI red at 4.5:1, muted/surface text at 4.5:1, a light
# c7 at 4.5:1 — every one of them below AAA.
cat >"$WORK/cat.toml" <<'TOML'
# comment kept verbatim
[themes.probe-dark]
mode = "dark"

[themes.probe-dark.term]
bg = "#151c2c"
fg = "#f4f5fb"
cursor = "#90b0fe"
cursor_text = "#151c2c"
sel_bg = "#323c55"
sel_fg = "#c0c4d0"
c0  = "#373e50"
c1  = "#e0584a"
c2  = "#31db60"
c3  = "#dea571"
c4  = "#90b0fe"
c5  = "#de93ff"
c6  = "#00dff2"
c7  = "#b8b9bb"
c8  = "#575d70"
c9  = "#ff9e8c"
c10 = "#59f87a"
c11 = "#ffc68f"
c12 = "#b5ccff"
c13 = "#efb8ff"
c14 = "#7ff4ff"
c15 = "#f4f5fb"

[themes.probe-dark.ui]
accent = "#90b0fe"
panel = "#1f2738"
border = "#2b3446"
text_muted = "#8089a0"
accent_on_surface = "#7f9ae0"
secondary_on_surface = "#c080e0"
tertiary_on_surface = "#40c0a0"

[themes.probe-light]
mode = "light"

[themes.probe-light.term]
bg = "#ecf3fc"
fg = "#101418"
cursor = "#1e4fb0"
cursor_text = "#aac0e8"
sel_bg = "#c8d3e2"
sel_fg = "#40464e"
c0  = "#2b2c2d"
c1  = "#9f1239"
c2  = "#005f19"
c3  = "#6b3f00"
c4  = "#1e3a8a"
c5  = "#6b21a8"
c6  = "#0e5a6a"
c7  = "#6c6d6e"
c8  = "#515254"
c9  = "#a8163f"
c10 = "#00600e"
c11 = "#744400"
c12 = "#233f94"
c13 = "#7424b4"
c14 = "#0f6070"
c15 = "#969697"

[themes.probe-light.ui]
accent = "#1e4fb0"
panel = "#dfe6ef"
border = "#cdd5df"
text_muted = "#5d646c"
accent_on_surface = "#3f68c0"
secondary_on_surface = "#8a4aa0"
tertiary_on_surface = "#307a60"
TOML

test_start "aaa_leaves_passing_colours_untouched"
got="$(py 'print(aaa.legible("#ffffff", ["#000000"]), aaa.legible("#000000", ["#ffffff"]))')"
assert_equals "#ffffff #000000" "$got" "already-AAA colours are returned verbatim"

test_start "aaa_lifts_failing_text_to_7_to_1"
got="$(py '
for fg, bg in (("#575d70", "#151c2c"), ("#6c6d6e", "#ecf3fc"), ("#e0584a", "#151c2c")):
    out = aaa.legible(fg, [bg])
    print(round(aaa.contrast(aaa.hex_rgb(fg), aaa.hex_rgb(bg)), 2) < 7,
          aaa.contrast(aaa.hex_rgb(out), aaa.hex_rgb(bg)) >= 7)')"
assert_equals $'True True\nTrue True\nTrue True' "$got" "each sub-AAA input comes out at 7:1 or better"

test_start "aaa_keeps_the_hue"
got="$(py '
import math
def hue(h):
    _, a, b = aaa._lab(aaa.hex_rgb(h)); return math.degrees(math.atan2(b, a)) % 360
before, after = "#e0584a", aaa.legible("#e0584a", ["#151c2c"])
print(after != before, abs(hue(after) - hue(before)) < 12)')"
assert_equals "True True" "$got" "a dark-mode red is lightened, not turned into another hue"

test_start "aaa_meets_every_surface_at_once"
got="$(py '
s = ["#ecf3fc", "#dfe6ef", "#cdd5df"]
out = aaa.legible("#3f68c0", s)
print(min(aaa.contrast(aaa.hex_rgb(out), aaa.hex_rgb(x)) for x in s) >= 7)')"
assert_equals "True" "$got" "surface text clears bg, panel and border together"

test_start "aaa_check_mode_reports_pending_changes"
rc=0
out="$(python3 "$AAA" "$WORK/cat.toml")" || rc=$?
assert_equals "1" "$rc" "check mode fails while a colour is below AAA"
assert_contains "would change" "$out"

test_start "aaa_write_makes_the_catalog_pass_the_audit"
audit_before=0
python3 "$AUDIT" "$WORK/cat.toml" >/dev/null || audit_before=$?
python3 "$AAA" --write "$WORK/cat.toml" >/dev/null
audit_rc=0
python3 "$AUDIT" "$WORK/cat.toml" >"$WORK/audit.txt" || audit_rc=$?
# The fixture omits the status/support roles, so only the contrast checks
# this pass owns are asserted.
fails="$(grep -cE 'FAIL .*(ansi_truecolor|structural_text|cursor_text|selection|surface_text|muted_text)_contrast' "$WORK/audit.txt" || true)"
assert_equals "1:0" "$audit_before:$fails" "the fixture failed the audit, and no text-contrast failure remains after --write"

test_start "aaa_write_is_idempotent"
cp "$WORK/cat.toml" "$WORK/once.toml"
python3 "$AAA" --write "$WORK/cat.toml" >/dev/null
assert_exit_code 0 "cmp -s '$WORK/once.toml' '$WORK/cat.toml'"
assert_exit_code 0 "python3 '$AAA' '$WORK/cat.toml' >/dev/null"

test_start "aaa_write_preserves_layout"
assert_file_contains "$WORK/cat.toml" "# comment kept verbatim"
assert_file_contains "$WORK/cat.toml" 'bg = "#151c2c"'
assert_equals "$(grep -c '' "$WORK/once.toml")" "$(grep -cE '' "$WORK/cat.toml")" "line count unchanged"
assert_exit_code 0 "grep -qE '^c8  = \"#[0-9a-f]{6}\"$' '$WORK/cat.toml'"

test_start "aaa_keeps_the_neutral_ramp"
got="$(
  PYTHONPATH="$REPO_ROOT/scripts/theme" python3 - "$WORK/cat.toml" <<'PY'
import sys, tomllib, aaa
for name, t in tomllib.load(open(sys.argv[1], "rb"))["themes"].items():
    L = lambda k: aaa.luminance(aaa.hex_rgb(t["term"][k]))
    print(name, L("c0") < L("c8") < L("c7") <= L("c15"))
PY
)"
assert_equals $'probe-dark True\nprobe-light True' "$got" "c0 < c8 < c7 <= c15 in both modes"

test_start "aaa_exempts_background_tone_slots"
assert_file_contains "$WORK/cat.toml" 'c0  = "#373e50"'
assert_file_contains "$WORK/cat.toml" 'c15 = "#969697"'

# The tmux clock block: derived from ui.secondary when a theme lacks it.
# Built on the full probe palettes above, plus a secondary hue per mode.
sed -e '/^\[themes\.probe-dark\.ui\]$/a\
secondary = "#61b9f2"' -e '/^\[themes\.probe-light\.ui\]$/a\
secondary = "#7f2ea7"' "$WORK/cat.toml" >"$WORK/cont.toml"

test_start "aaa_derives_the_clock_container_in_both_modes"
got="$(
  PYTHONPATH="$REPO_ROOT/scripts/theme" python3 - "$WORK/cont.toml" <<'PY'
import math, sys, tomllib, aaa
def hue(h):
    _, a, b = aaa._lab(aaa.hex_rgb(h)); return math.degrees(math.atan2(b, a)) % 360
for name, t in tomllib.load(open(sys.argv[1], "rb"))["themes"].items():
    ui = aaa.enforce(t)["ui"]
    box, text = aaa.hex_rgb(ui["secondary_container"]), aaa.hex_rgb(ui["on_secondary_container"])
    tint = aaa.luminance(box) < 0.05 if t["mode"] == "dark" else aaa.luminance(box) > 0.75
    same_hue = min(abs(hue(ui["secondary_container"]) - hue(ui["secondary"])) % 360,
                   360 - abs(hue(ui["secondary_container"]) - hue(ui["secondary"])) % 360) < 25
    print(t["mode"], tint, aaa.contrast(text, box) >= 7, same_hue)
PY
)"
assert_equals $'dark True True True\nlight True True True' "$got" \
  "a deep tint (dark) or pale tint (light) of the secondary hue, with 7:1 text"

test_start "aaa_write_inserts_derived_roles_into_their_table"
python3 "$AAA" --write "$WORK/cont.toml" >/dev/null
got="$(awk '/^\[/{s=$0} /secondary_container/{print s}' "$WORK/cont.toml" | sort | uniq -c | awk '{print $1, $2}')"
assert_equals $'2 [themes.probe-dark.ui]\n2 [themes.probe-light.ui]' "$got" "both keys land in each theme's ui table"
assert_exit_code 0 "python3 -c 'import tomllib; tomllib.load(open(\"$WORK/cont.toml\",\"rb\"))'"
cp "$WORK/cont.toml" "$WORK/cont-once.toml"
python3 "$AAA" --write "$WORK/cont.toml" >/dev/null
assert_exit_code 0 "cmp -s '$WORK/cont-once.toml' '$WORK/cont.toml'"

test_start "aaa_committed_catalogs_are_already_aaa"
assert_exit_code 0 "python3 '$AAA' >/dev/null"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
