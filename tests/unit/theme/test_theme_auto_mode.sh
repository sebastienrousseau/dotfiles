#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Behavioral coverage for machine-local theme state and auto-mode metadata.
# shellcheck disable=SC1090,SC1091,SC2034

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

sandbox="$(mktemp -d)"
trap 'rm -rf "$sandbox"' EXIT
export HOME="$sandbox/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export CHEZMOI_SOURCE_DIR="$sandbox/source"
mkdir -p "$CHEZMOI_SOURCE_DIR/.chezmoidata" "$XDG_CONFIG_HOME/chezmoi"

data_file="$CHEZMOI_SOURCE_DIR/.chezmoidata.toml"
cat >"$data_file" <<'TOML'
theme = "maui-dark"
theme_family = "maui"
theme_mode = "auto"
TOML
cat >"$CHEZMOI_SOURCE_DIR/.chezmoidata/themes.toml" <<'TOML'
[themes.maui-dark]
family = "maui"
mode = "dark"
[themes.maui-light]
family = "maui"
mode = "light"
TOML
cat >"$XDG_CONFIG_HOME/chezmoi/chezmoi.toml" <<'TOML'
[sourceVCS]
autoCommit = false
TOML

# Source guard prevents main() from running and exposes the state helpers.
source "$REPO_ROOT/bin/dot-theme-sync"

before="$(cksum "$data_file")"
write_theme maui-light auto

test_start "auto_theme_does_not_mutate_repo_default"
assert_equals "$before" "$(cksum "$data_file")" "runtime selection leaves tracked defaults unchanged"

test_start "auto_theme_writes_machine_local_state"
assert_file_contains "$CHEZMOI_CFG" '[data]' "machine config receives a data table"
assert_file_contains "$CHEZMOI_CFG" 'theme = "maui-light"' "resolved palette is cached"
assert_file_contains "$CHEZMOI_CFG" 'theme_family = "maui"' "family is stored independently"
assert_file_contains "$CHEZMOI_CFG" 'theme_mode = "auto"' "auto preference is retained"
assert_file_contains "$CHEZMOI_CFG" '[sourceVCS]' "unrelated config tables are preserved"

test_start "auto_theme_reads_machine_override"
assert_equals "maui-light" "$(current_theme)" "resolved machine theme wins"
assert_equals "maui" "$(current_theme_family)" "machine family is readable"
assert_equals "auto" "$(current_theme_mode)" "machine auto mode is readable"

write_theme maui-dark manual
test_start "manual_theme_disables_auto_mode"
assert_file_contains "$CHEZMOI_CFG" 'theme = "maui-dark"' "manual palette is cached"
assert_file_contains "$CHEZMOI_CFG" 'theme_mode = "dark"' "manual mode replaces auto"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
