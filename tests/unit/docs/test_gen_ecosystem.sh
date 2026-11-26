#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# tools/docs/gen_ecosystem.py renders docs/ecosystem.toml into the marked
# table of docs/ECOSYSTEM.md; --check fails when that table was edited by
# hand, when the TOML changed without it, or when a home path is gone.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

GEN="$REPO_ROOT/tools/docs/gen_ecosystem.py"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/gen-ecosystem-test.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# A copy of the files the generator reads, so the test never edits the repo.
mkdir -p "$WORK/docs" "$WORK/plugins/fleet" "$WORK/bin"
cat >"$WORK/docs/ecosystem.toml" <<'EOF'
[[component]]
repo = "dot-fleet"
command = "dot fleet"
kind = "plugin"
home = ["plugins/fleet"]
wave = 1
latest_release = ""

[[component]]
repo = "dot"
command = "dot"
kind = "cli"
home = ["bin"]
wave = 4
latest_release = "0.0.1"
EOF
printf '# Ecosystem\n\nProse stays.\n\n<!-- BEGIN GENERATED: docs/ecosystem.toml -->\nold\n<!-- END GENERATED -->\n\nMore prose.\n' \
  >"$WORK/docs/ECOSYSTEM.md"

# gen ARGS...: run the generator against the copy; sets rc and out.
gen() {
  rc=0
  out="$(python3 "$GEN" --root "$WORK" "$@" 2>&1)" || rc=$?
}

test_start "stale_table_fails_check"
gen --check
assert_equals "1" "$rc" "the placeholder table is stale"
assert_contains "docs/ECOSYSTEM.md" "$out" "the stale file is named"

test_start "generate_writes_the_table"
gen
assert_equals "0" "$rc" "generation succeeds"
doc="$(cat "$WORK/docs/ECOSYSTEM.md")"
assert_contains "| \`dot-fleet\` | \`dot fleet\` | plugin | \`plugins/fleet\` | 1 | ships inside .dotfiles |" "$doc" "a row per component"
assert_contains "| \`dot\` | \`dot\` | cli | \`bin\` | final split | 0.0.1 |" "$doc" "wave 4 and a release render"
assert_contains "Prose stays." "$doc" "text outside the markers is kept"
assert_contains "More prose." "$doc" "on both sides"

test_start "fresh_table_passes_check"
gen --check
assert_equals "0" "$rc" "a regenerated table is current"

test_start "hand_edit_fails_check"
sed -i.bak 's/| 1 | ships inside .dotfiles |/| 2 | ships inside .dotfiles |/' "$WORK/docs/ECOSYSTEM.md"
gen --check
assert_equals "1" "$rc" "a hand edit to the table fails"

test_start "toml_change_without_regeneration_fails_check"
gen
sed -i.bak 's/wave = 1/wave = 2/' "$WORK/docs/ecosystem.toml"
gen --check
assert_equals "1" "$rc" "a TOML change the table does not show fails"

test_start "missing_home_fails"
sed -i.bak 's/wave = 2/wave = 1/; s|plugins/fleet|plugins/gone|' "$WORK/docs/ecosystem.toml"
gen --check
assert_equals "1" "$rc" "a home path that does not exist fails"
assert_contains "plugins/gone" "$out" "and is named"

test_start "repository_table_is_current"
rc=0
out="$(python3 "$GEN" --check 2>&1)" || rc=$?
assert_equals "0" "$rc" "docs/ECOSYSTEM.md matches docs/ecosystem.toml"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
