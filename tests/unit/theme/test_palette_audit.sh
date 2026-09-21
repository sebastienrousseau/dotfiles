#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Contract tests for the deterministic terminal palette quality audit.
# shellcheck disable=SC1090,SC1091,SC2034

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

AUDIT="$REPO_ROOT/scripts/theme/audit-palettes.py"
CATALOG="$REPO_ROOT/defaults/.chezmoidata/themes.toml"
WORK="$(mktemp -d -t dot-palette-audit.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

test_start "palette_audit_exists"
assert_file_exists "$AUDIT"

test_start "palette_audit_is_executable"
assert_exit_code 0 "test -x '$AUDIT'"

human="$WORK/audit.txt"
catalog_rc=0
python3 "$AUDIT" "$CATALOG" >"$human" || catalog_rc=$?

test_start "palette_catalog_satisfies_quality_contract"
assert_equals "0" "$catalog_rc"

test_start "palette_catalog_reports_all_themes"
assert_file_contains "$human" "228/228 themes passed"

first="$WORK/first.json"
second="$WORK/second.json"
python3 "$AUDIT" "$CATALOG" --json >"$first"
python3 "$AUDIT" "$CATALOG" --json >"$second"

test_start "palette_audit_json_is_deterministic"
assert_exit_code 0 "cmp -s '$first' '$second'"

test_start "palette_audit_json_contract_is_versioned"
assert_output_contains '1.0|228|228|0|0' \
  "python3 -c 'import json; d=json.load(open(\"$first\")); s=d[\"summary\"]; print(d[\"schema_version\"], s[\"themes\"], s[\"passed\"], s[\"failed\"], s[\"failures\"], sep=\"|\")'"

test_start "palette_audit_enforces_contract_minima"
assert_exit_code 0 "python3 -c '
import json
d=json.load(open(\"$first\"))
m=[r[\"metrics\"] for r in d[\"results\"]]
assert min(x[\"text_contrast\"] for x in m) >= 7
assert min(x[\"status_text_contrast\"] for x in m) >= 7
assert min(x[\"focus_contrast\"] for x in m) >= 3
assert min(x[\"ansi_truecolor_contrast\"] for x in m) >= 4.5
assert min(x[\"ansi_256_contrast\"] for x in m) >= 4.5
assert min(x[\"support_delta_e\"] for x in m) >= 18
assert min(x[\"semantic_cvd_delta_e\"] for x in m) >= 8
'"

broken="$WORK/broken.toml"
cat >"$broken" <<'TOML'
[themes.broken-dark]
mode = "dark"

[themes.broken-dark.term]
bg = "#101010"
fg = "#111111"
cursor = "#101010"
sel_bg = "#101010"
sel_fg = "#111111"
c1 = "#111111"
c2 = "#111111"
c3 = "#111111"
c4 = "#111111"
c5 = "#111111"
c6 = "#111111"
c9 = "#111111"
c10 = "#111111"
c11 = "#111111"
c12 = "#111111"
c13 = "#111111"
c14 = "#111111"

[themes.broken-dark.ui]
accent = "#101010"
accent_text = "#111111"
secondary = "#101010"
tertiary = "#101010"
text_muted = "#111111"
accent_on_surface = "#111111"
secondary_on_surface = "#111111"
tertiary_on_surface = "#111111"
error = "#101010"
warning = "#101010"
success = "#101010"
info = "#101010"
panel = "#101010"
border = "#101010"
TOML

broken_output="$WORK/broken.txt"
broken_rc=0
python3 "$AUDIT" "$broken" >"$broken_output" || broken_rc=$?

test_start "palette_audit_rejects_broken_palette"
assert_equals "1" "$broken_rc"

test_start "palette_audit_names_actionable_failures"
assert_file_contains "$broken_output" "text_contrast"
assert_file_contains "$broken_output" "semantic_cvd_delta_e"

test_start "palette_audit_schema_is_committed"
assert_file_exists "$REPO_ROOT/schemas/palette-audit.schema.json"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
