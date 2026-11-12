#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Regression for: d7e7c2bc (v0.2.499 baseline)
# The suite must not write into the developer's real XDG directories.
#
# A developer shell exports XDG_CACHE_HOME, XDG_DATA_HOME and friends. A
# test that sandboxed only HOME (`env HOME="$tmp/home" ... bash
# scripts/ops/chezmoi-apply.sh`) still handed those to the code under test,
# and prewarm.sh wrote its shell init caches and completions into the real
# ~/.cache and ~/.local/share: a mise-init.zsh carrying the test's PATH,
# which every new terminal then sourced, and an empty _chezmoi completion.
# CI runners export no XDG variables, so CI never saw it.
#
# The framework now drops the inherited XDG base directories when it is
# sourced, so every test resolves them from the HOME it sets, as in CI.
# Checked two ways: the variables are gone after sourcing, and the test file
# that leaked writes nothing into XDG directories set to canaries.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

CANARY="$(mktemp -d)"
trap 'rm -rf "$CANARY"' EXIT
mkdir -p "$CANARY"/{cache,data,config,state,run}
canary_env=(
  XDG_CACHE_HOME="$CANARY/cache" XDG_DATA_HOME="$CANARY/data"
  XDG_CONFIG_HOME="$CANARY/config" XDG_STATE_HOME="$CANARY/state"
  XDG_RUNTIME_DIR="$CANARY/run"
)

# Captured before this file sources the framework, which clears them.
left="$(env "${canary_env[@]}" bash -c '
  source "$1/tests/framework/assertions.sh"
  env | grep -E "^XDG_(CACHE|DATA|CONFIG|STATE)_HOME=|^XDG_RUNTIME_DIR=" | cut -d= -f1 | sort | tr "\n" " "
' _ "$REPO_ROOT")"

env "${canary_env[@]}" bash "$REPO_ROOT/tests/unit/security/test_security_fixes.sh" >/dev/null 2>&1
written="$(find "$CANARY" -type f | sed "s|^$CANARY/||" | sort | head -5 | tr '\n' ' ')"

source "$SCRIPT_DIR/../framework/assertions.sh"

test_start "framework_drops_inherited_xdg_dirs"
assert_equals "" "$left" "no XDG base directory survives sourcing assertions.sh"

test_start "security_fixes_test_leaves_host_xdg_alone"
assert_equals "" "$written" "running test_security_fixes.sh writes nothing into the inherited XDG dirs"

print_summary
