#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# What the diagnostics scripts do when there is no dotfiles source at all.
#
# version-locks.sh, conflicts.sh and aliases-manifest.sh each carry their own
# resolve_source_dir, ending in a `return 1` that no suite had reached: every
# harness runs with a HOME that has ~/.dotfiles in it, and the coverage
# sandbox goes out of its way to create one. Each case here supplies a HOME
# with nothing in it instead.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

DIAG_DIR="$REPO_ROOT/scripts/diagnostics"

WORK="$(mktemp -d -t nosrc.XXXXXX)"
cov_setup_sandbox
trap 'chmod -R u+rwx "$WORK" 2>/dev/null || true; rm -rf "$WORK"; cov_teardown_sandbox' EXIT

mkdir -p "$WORK/empty-home" "$WORK/stubs"
dot_fixture_basebin "$WORK/base"
# Stubs, so nothing here can reach the real chezmoi configuration.
dot_fixture_stub "$WORK/stubs" chezmoi 0
dot_fixture_stub "$WORK/stubs" git 0

NS_OUT=""
NS_RC=0
# ns_run <script> [args...] — run with a HOME that has no dotfiles source in
# it and no CHEZMOI_SOURCE_DIR pointing at one.
ns_run() {
  local script="$1"
  shift
  NS_RC=0
  NS_OUT="$(
    HOME="$WORK/empty-home" \
      XDG_DATA_HOME="${NS_DATA_HOME:-$WORK/empty-home/.local/share}" \
      XDG_STATE_HOME="$WORK/empty-home/.local/state" \
      PATH="$WORK/stubs:$WORK/base" \
      CHEZMOI_SOURCE_DIR="" NO_COLOR=1 \
      "${BASH:-bash}" "$script" "$@" 2>&1 </dev/null
  )" || NS_RC=$?
}

test_start "version_locks_gives_up_without_a_source_directory"
ns_run "$DIAG_DIR/version-locks.sh"
assert_not_equals "0" "$NS_RC" \
  "with no source directory anywhere, version-locks must not report success"

test_start "conflicts_gives_up_without_a_source_directory"
ns_run "$DIAG_DIR/conflicts.sh"
assert_not_equals "0" "$NS_RC" \
  "with no source directory anywhere, conflicts must not report success"

test_start "aliases_manifest_gives_up_without_a_source_directory"
ns_run "$DIAG_DIR/aliases-manifest.sh"
assert_not_equals "0" "$NS_RC" \
  "with no source directory anywhere, the manifest must not report success"

print_summary
