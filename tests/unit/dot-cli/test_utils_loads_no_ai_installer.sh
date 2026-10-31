#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091,SC2016
# P2.2, edge 1: lib/dot/utils.sh, which every command module sources, does
# not load the AI installer, the AI provisioner or the toolchain updater.
# The modules that use them load them: the ai plugin (through its own
# ai-commands.sh and ai-provision.sh) and the system plugin (through
# upgrade.sh). Each case
# sources the libraries in a child bash and asks which functions exist.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

# defined LIB... -- FUNCTION...: for each function, "yes" or "no" after
# sourcing the libraries (paths relative to the repo) in order.
defined() {
  local libs=()
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    libs+=("$1")
    shift
  done
  shift
  bash -c '
    set -euo pipefail
    root="$1"; n="$2"; shift 2
    for ((i = 0; i < n; i++)); do source "$root/$1"; shift; done
    for f in "$@"; do if declare -F "$f" >/dev/null; then echo "$f yes"; else echo "$f no"; fi; done
  ' _ "$REPO_ROOT" "${#libs[@]}" "${libs[@]}" "$@" 2>&1
}

test_start "utils_sh_loads_neither_installer_nor_updater"
out="$(defined lib/dot/utils.sh -- install_claude_native ai_install_tool dot_upgrade_prepare require_source_dir)"
assert_contains "install_claude_native no" "$out" "the AI installer is not loaded"
assert_contains "ai_install_tool no" "$out" "the AI provisioner is not loaded"
assert_contains "dot_upgrade_prepare no" "$out" "the toolchain updater is not loaded"
assert_contains "require_source_dir yes" "$out" "utils.sh's own functions are"

test_start "ai_commands_loads_the_provisioner_and_installer"
out="$(defined lib/dot/utils.sh plugins/ai/libexec/ai/ai-commands.sh -- ai_install_tool install_claude_native ai_pinned_spec)"
assert_contains "ai_install_tool yes" "$out" "ai-commands.sh brings the provisioner"
assert_contains "install_claude_native yes" "$out" "which brings the installer"
assert_contains "ai_pinned_spec yes" "$out" "and the pins"

test_start "upgrade_loads_no_ai_code"
# The pin report comes from `dot ai update --check` (P2.2 edge 5b).
out="$(defined lib/dot/utils.sh lib/dot/upgrade.sh -- dot_upgrade_prepare ai_pin_bumps install_claude_native)"
assert_contains "dot_upgrade_prepare yes" "$out" "upgrade.sh defines the updater"
assert_contains "ai_pin_bumps no" "$out" "without loading the AI pins"
assert_contains "install_claude_native no" "$out" "or the AI installer"

# The plugin modules that use them still get them. Each module dispatches
# when sourced (here to its help) and may exit, so the check runs in an
# EXIT trap, writing to the saved stdout.
loaded_by() {
  bash -c 'exec 3>&1
    trap "declare -F $2 >/dev/null && echo yes >&3 || echo no >&3" EXIT
    source "$1" --help >/dev/null 2>&1' _ "$REPO_ROOT/$1" "$2"
}

test_start "the_ai_and_system_plugins_load_what_they_use"
assert_equals "yes" "$(loaded_by plugins/ai/libexec/ai.sh ai_install_tool)" "the ai plugin loads the provisioner"
assert_equals "yes" "$(loaded_by plugins/ai/libexec/ai.sh install_claude_native)" "and the installer"
assert_equals "yes" "$(loaded_by plugins/system/libexec/system.sh dot_upgrade_prepare)" "the system plugin loads the updater"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
