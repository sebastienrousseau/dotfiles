#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for install.sh's chezmoi config helpers:
#   - ensure_chezmoi_source must never discard an existing chezmoi.toml
#   - apply_minimal_profile_overrides must select the profile in the
#     per-host config, not in the tracked defaults/.chezmoidata.toml

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$REPO_ROOT/tests/framework/assertions.sh"

_tmp=$(mktemp -d -t dotfiles-install-cfg.XXXXXX)
trap 'rm -rf "$_tmp"' EXIT

export HOME="$_tmp/home"
mkdir -p "$HOME"
# Sourcing does not run main (guarded by BASH_SOURCE == $0).
source "$REPO_ROOT/install.sh"
set +e

_reset() {
  CHEZMOI_CONFIG_DIR="$_tmp/cfg$1"
  CHEZMOI_CONFIG_FILE="$CHEZMOI_CONFIG_DIR/chezmoi.toml"
  mkdir -p "$CHEZMOI_CONFIG_DIR"
}

# Resolve a key the way chezmoi does, when chezmoi is available.
_have_chezmoi=0
command -v chezmoi >/dev/null 2>&1 && _have_chezmoi=1
_chezmoi_source_path() { chezmoi --config "$CHEZMOI_CONFIG_FILE" source-path 2>/dev/null; }
_chezmoi_profile() {
  chezmoi --config "$CHEZMOI_CONFIG_FILE" --source "$_tmp/emptysrc" \
    execute-template '{{ .profile }}' 2>/dev/null
}
mkdir -p "$_tmp/emptysrc"

# ── ensure_chezmoi_source ───────────────────────────────────────────
test_start "chezmoi_source_creates_missing_config"
_reset 1
rm -f "$CHEZMOI_CONFIG_FILE"
ensure_chezmoi_source "/src/one"
assert_equals 'sourceDir = "/src/one"' "$(cat "$CHEZMOI_CONFIG_FILE")" "fresh config holds only sourceDir"

test_start "chezmoi_source_preserves_existing_config"
_reset 2
printf '[data]\nemail = "me@example.invalid"\n\n[git]\nautoCommit = true\n' >"$CHEZMOI_CONFIG_FILE"
ensure_chezmoi_source "/src/two"
assert_file_contains "$CHEZMOI_CONFIG_FILE" 'email = "me@example.invalid"' "existing [data] kept"
test_start "chezmoi_source_preserves_other_tables"
assert_file_contains "$CHEZMOI_CONFIG_FILE" 'autoCommit = true' "existing [git] kept"
test_start "chezmoi_source_inserted_top_level"
assert_equals 'sourceDir = "/src/two"' "$(head -n 1 "$CHEZMOI_CONFIG_FILE")" \
  "sourceDir inserted before the first table"

test_start "chezmoi_source_replaces_existing_key"
_reset 3
printf 'sourceDir = "/old"\n[data]\nsourceDir = "not-top-level"\n' >"$CHEZMOI_CONFIG_FILE"
ensure_chezmoi_source "/src/three"
assert_equals "1" "$(grep -c '^sourceDir = "/src/three"$' "$CHEZMOI_CONFIG_FILE")" "top-level key replaced once"
test_start "chezmoi_source_leaves_table_keys"
assert_file_contains "$CHEZMOI_CONFIG_FILE" 'sourceDir = "not-top-level"' "keys inside tables untouched"

test_start "chezmoi_source_escapes_special_chars"
_reset 4
printf '[data]\nx = 1\n' >"$CHEZMOI_CONFIG_FILE"
odd_dir="$_tmp/a,b&c\"d"
mkdir -p "$odd_dir"
ensure_chezmoi_source "$odd_dir"
ensure_chezmoi_source "$odd_dir" # idempotent
if ((_have_chezmoi)); then
  assert_equals "$odd_dir" "$(_chezmoi_source_path)" "chezmoi reads the exact path back"
else
  assert_equals "1" "$(grep -c '^sourceDir' "$CHEZMOI_CONFIG_FILE")" "single sourceDir line"
fi

test_start "chezmoi_source_config_stays_private"
perms=$(stat -c '%a' "$CHEZMOI_CONFIG_FILE" 2>/dev/null || stat -f '%Lp' "$CHEZMOI_CONFIG_FILE")
assert_equals "600" "$perms" "rewritten config is 0600"

# ── apply_minimal_profile_overrides ─────────────────────────────────
test_start "minimal_appends_data_table"
_reset 5
printf 'sourceDir = "/src"\n' >"$CHEZMOI_CONFIG_FILE"
apply_minimal_profile_overrides
assert_file_contains "$CHEZMOI_CONFIG_FILE" 'profile = "minimal"' "profile written to [data]"
if ((_have_chezmoi)); then
  test_start "minimal_chezmoi_reads_profile_append"
  assert_equals "minimal" "$(_chezmoi_profile)" "chezmoi data reports minimal"
fi

test_start "minimal_replaces_existing_profile"
_reset 6
printf 'sourceDir = "/src"\n[data]\nprofile = "laptop"\nname = "n"\n[data.features]\nniri = true\n' >"$CHEZMOI_CONFIG_FILE"
apply_minimal_profile_overrides
apply_minimal_profile_overrides # idempotent
assert_equals "1" "$(grep -c '^profile' "$CHEZMOI_CONFIG_FILE")" "exactly one profile key"
test_start "minimal_keeps_other_data"
assert_file_contains "$CHEZMOI_CONFIG_FILE" 'niri = true' "nested data kept"

test_start "minimal_inserts_inside_data_table"
_reset 7
printf 'sourceDir = "/src"\n[data]\nname = "n"\n[git]\nautoCommit = true\n' >"$CHEZMOI_CONFIG_FILE"
apply_minimal_profile_overrides
if ((_have_chezmoi)); then
  assert_equals "minimal" "$(_chezmoi_profile)" "profile lands in [data], not [git]"
else
  assert_equals 'profile = "minimal"' "$(sed -n '4p' "$CHEZMOI_CONFIG_FILE")" "profile directly after [data] keys"
fi

test_start "minimal_never_targets_tracked_source"
if grep -q 'apply_minimal_profile_overrides "\$SOURCE_DIR' "$REPO_ROOT/install.sh"; then
  assert_exit_code 0 "false  # install.sh still edits the tracked data file"
else
  assert_exit_code 0 "true"
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
