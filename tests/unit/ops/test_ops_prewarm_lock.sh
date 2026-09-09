#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The concurrency guard in scripts/ops/prewarm.sh.
#
# prewarm refuses to run twice at once, and it has two ways of deciding that:
# flock where it exists, and a lock directory where it does not. macOS ships
# no flock, so the flock arm had never run anywhere the suite runs; a stub
# supplies it, and by refusing the lock it drives the "already running" exit
# as well.
#
# The lock lives under XDG_RUNTIME_DIR when that is set, so every case points
# it at a directory this suite owns. A machine-global lock path would make
# concurrent runs of the suite flake against each other.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

PREWARM="$REPO_ROOT/scripts/ops/prewarm.sh"

WORK="$(mktemp -d -t prewarm.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

mkdir -p "$WORK/stubs" "$WORK/run" "$WORK/home"
dot_fixture_basebin "$WORK/base"

PW_OUT=""
PW_RC=0
pw_run() {
  PW_RC=0
  PW_OUT="$(
    HOME="$WORK/home" PATH="$WORK/stubs:$WORK/base" NO_COLOR=1 \
      XDG_RUNTIME_DIR="$WORK/run" XDG_CACHE_HOME="$WORK/home/.cache" \
      "${BASH:-bash}" "$PREWARM" 2>&1 </dev/null
  )" || PW_RC=$?
}

# ── 1. flock present, and the lock is already held ─────────────────────────
test_start "prewarm_stands_down_when_flock_reports_a_holder"
printf '#!/bin/sh\nexit 1\n' >"$WORK/stubs/flock"
chmod +x "$WORK/stubs/flock"
pw_run
assert_equals "0" "$PW_RC" "a second instance should stand down cleanly, not fail"
assert_contains "Already running" "$PW_OUT" "and say why it did nothing"

# ── 2. flock present and the lock is free ──────────────────────────────────
test_start "prewarm_proceeds_when_flock_grants_the_lock"
printf '#!/bin/sh\nexit 0\n' >"$WORK/stubs/flock"
chmod +x "$WORK/stubs/flock"
pw_run
assert_equals "0" "$PW_RC" "an uncontended run should exit 0"
assert_false "[[ \"\$PW_OUT\" == *'Already running'* ]]" \
  "an uncontended run should not claim another instance is active"

# ── 3. No flock: the portable lock-directory fallback ──────────────────────
test_start "prewarm_falls_back_to_a_lock_directory"
rm -f "$WORK/stubs/flock"
mkdir -p "$WORK/run/dotfiles-prewarm.lock.d"
pw_run
assert_equals "0" "$PW_RC" "a held lock directory should stand down cleanly"
assert_contains "Already running" "$PW_OUT" "and say why it did nothing"
rmdir "$WORK/run/dotfiles-prewarm.lock.d"

print_summary
