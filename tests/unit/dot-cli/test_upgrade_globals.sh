#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# `dot system update` (plugins/system/libexec/system/upgrade.sh) runs what the old `update`
# script and functions ran. The language-globals phase (npm, cargo, pipx)
# runs only with --globals; the app-store phase (mas, flatpak, snap) runs
# with the consented system phase. Each runs the managers that are
# installed, skips the others, and fails when one fails. Fakes record calls.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-globals.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
for tool in npm cargo cargo-install-update pipx mas flatpak sudo; do
  printf '#!/bin/sh\necho "%s $*" >>"%s/calls"\nexit "${FAIL_%s:-0}"\n' \
    "$tool" "$WORK" "$(printf '%s' "$tool" | tr -c 'a-z\n' '_')" >"$WORK/bin/$tool"
  chmod +x "$WORK/bin/$tool"
done

# upgrade WORDS...: source the upgrade library with its prompts stubbed and
# run WORDS in that shell; _upgrade_step records the phase ids it is given.
# has_command sees only the fakes, so a runner's own /usr/bin/snap or npm
# never counts as installed.
upgrade() {
  FAKES="$WORK/bin" PATH="$WORK/bin:/usr/bin:/bin" bash -c '
    set -euo pipefail
    source "$1/plugins/system/libexec/system/upgrade.sh"
    has_command() { [[ -x "$FAKES/$1" ]]; }
    dot_apply_yes_flag() { :; }
    dot_ensure_mise() { :; }
    _dot_upgrade_consent_system() { :; }
    dot_upgrade_system_pm() { return 1; }
    ui_step() { :; }
    _upgrade_step() { echo "step $1"; }
    shift
    eval "$*"' _ "$REPO_ROOT" "$@"
}

test_start "globals_only_when_asked"
assert_equals "1" "$(upgrade 'dot_upgrade_prepare --yes --globals; echo $DOT_UPGRADE_GLOBALS')" "--globals asks for the phase"
assert_equals "0" "$(upgrade 'dot_upgrade_prepare --yes; echo $DOT_UPGRADE_GLOBALS')" "it is off by default"
assert_contains "step globals" "$(upgrade 'DOT_UPGRADE_GLOBALS=1 dot_upgrade_toolchain_steps')" "the phase runs when asked"
assert_output_not_contains "step globals" "upgrade 'DOT_UPGRADE_GLOBALS=0 dot_upgrade_toolchain_steps'" "and not otherwise"

test_start "globals_runs_each_installed_manager"
: >"$WORK/calls"
rc=0
upgrade _dot_upgrade_globals >/dev/null 2>&1 || rc=$?
assert_equals "0" "$rc" "every manager succeeded"
assert_equals "npm update -g --audit=false|cargo install-update -a|pipx upgrade-all" \
  "$(paste -sd '|' "$WORK/calls")" "npm, cargo and pipx each ran"

test_start "globals_skips_missing_and_fails_on_a_failure"
rm "$WORK/bin/cargo-install-update"
: >"$WORK/calls"
rc=0
FAIL_npm=3 upgrade _dot_upgrade_globals >/dev/null 2>&1 || rc=$?
assert_equals "1" "$rc" "a failing manager fails the phase"
assert_equals "npm update -g --audit=false|pipx upgrade-all" "$(paste -sd '|' "$WORK/calls")" \
  "the others still run, and a missing one is skipped"

test_start "apps_follow_the_system_phase"
: >"$WORK/calls"
assert_equals "step system|step apps" \
  "$(upgrade 'DOT_UPGRADE_SYSTEM=brew dot_upgrade_toolchain_steps' | grep -v mise | paste -sd '|' -)" \
  "the app stores run after consented system packages"
assert_output_not_contains "step apps" "upgrade 'DOT_UPGRADE_SYSTEM= dot_upgrade_toolchain_steps'" \
  "and not without that consent"
assert_equals "mas flatpak" "$(upgrade _dot_upgrade_app_managers)" "the installed stores are named"

test_start "apps_run_each_store_and_fail_on_a_failure"
cp "$WORK/bin/sudo" "$WORK/bin/snap"
rc=0
upgrade _dot_upgrade_apps >/dev/null 2>&1 || rc=$?
assert_equals "0" "$rc" "every store succeeding passes the phase"
: >"$WORK/calls"
rc=0
FAIL_flatpak=1 upgrade _dot_upgrade_apps >/dev/null 2>&1 || rc=$?
assert_equals "1" "$rc" "a failing store fails the phase"
assert_equals "mas upgrade|flatpak update -y --noninteractive|sudo -n snap refresh" \
  "$(paste -sd '|' "$WORK/calls")" "every store still runs, snap through sudo"
rm "$WORK/bin/mas" "$WORK/bin/flatpak" "$WORK/bin/snap"
assert_equals "" "$(upgrade _dot_upgrade_app_managers)" "no store, no phase"
assert_output_not_contains "step apps" "upgrade 'DOT_UPGRADE_SYSTEM=brew dot_upgrade_toolchain_steps'" \
  "the phase is skipped with no store installed"

test_start "zypper_is_a_system_manager"
printf '#!/bin/sh\necho "zypper $*" >>"%s/calls"\n' "$WORK" >"$WORK/bin/zypper"
chmod +x "$WORK/bin/zypper"
# The real lookup (upgrade() stubs it), with only the fakes on PATH.
assert_equals "zypper" \
  "$(upgrade "_DOT_UPGRADE_LOADED=; source '$REPO_ROOT/plugins/system/libexec/system/upgrade.sh'; PATH='$WORK/bin'; dot_upgrade_system_pm")" \
  "found when it is the only one"
: >"$WORK/calls"
upgrade '_dot_upgrade_system zypper' >/dev/null 2>&1
assert_equals "sudo -n zypper --non-interactive refresh|sudo -n zypper --non-interactive update" \
  "$(paste -sd '|' "$WORK/calls")" "refreshed, then updated, without a prompt"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
