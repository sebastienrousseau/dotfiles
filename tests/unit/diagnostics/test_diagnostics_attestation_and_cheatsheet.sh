#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Dependency and destination handling in two diagnostics scripts.
#
# workstation-attestation.sh needs jq, honours DOTFILES_FLEET_STORE from the
# environment, and creates the parent of an explicit --write path. None of
# those had run: jq is installed everywhere the suite runs, the environment
# variable was never set, and --write was never passed.
#
# aliases-cheatsheet.sh refuses to run without the alias manifest, which the
# checkout always has — so the refusal is staged with a fixture source tree
# that carries the cheatsheet but not the manifest.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

ATTEST="$REPO_ROOT/scripts/diagnostics/workstation-attestation.sh"
CHEATSHEET_REL="scripts/diagnostics/aliases-cheatsheet.sh"

WORK="$(mktemp -d -t attest.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

mkdir -p "$WORK/home"
# Two tool directories that differ in exactly one entry: jq.
dot_fixture_basebin "$WORK/nojq" hostname sw_vers
dot_fixture_basebin "$WORK/base" jq hostname sw_vers

# ── 1. jq is a hard dependency ─────────────────────────────────────────────
test_start "attestation_requires_jq"
AT_RC=0
AT_OUT="$(
  HOME="$WORK/home" PATH="$WORK/nojq" NO_COLOR=1 \
    "${BASH:-bash}" "$ATTEST" --json 2>&1 </dev/null
)" || AT_RC=$?
assert_equals "1" "$AT_RC" "no jq at all should exit 1"
assert_contains "jq is required" "$AT_OUT" "the failure should name the dependency"

# ── 2. --write creates the destination's parent ────────────────────────────
test_start "attestation_creates_the_write_destination"
AT_RC=0
AT_OUT="$(
  HOME="$WORK/home" NO_COLOR=1 \
    XDG_STATE_HOME="$WORK/home/.local/state" \
    "${BASH:-bash}" "$ATTEST" --json \
    --write "$WORK/out/nested/attestation.json" 2>&1 </dev/null
)" || AT_RC=$?
assert_equals "0" "$AT_RC" "writing to a nested path should exit 0"
assert_dir_exists "$WORK/out/nested" \
  "the parent directory of --write should be created"

# ── 3. The fleet store can come from the environment ───────────────────────
test_start "attestation_reads_the_fleet_store_from_the_environment"
AT_RC=0
AT_OUT="$(
  HOME="$WORK/home" NO_COLOR=1 \
    XDG_STATE_HOME="$WORK/home/.local/state" \
    DOTFILES_FLEET_STORE="$WORK/fleet" \
    "${BASH:-bash}" "$ATTEST" --json 2>&1 </dev/null
)" || AT_RC=$?
assert_equals "0" "$AT_RC" "an environment-supplied fleet store should exit 0"

# ── 4. The cheatsheet refuses to run without its manifest ──────────────────
#
# Not removed on exit: the aggregator resolves the symlink after the whole
# sweep has run, and a deleted fixture would resolve to nothing.
FX="${TMPDIR:-/tmp}"
FX="${FX%/}/dot-cov-fixtures/cheatsheet-no-manifest"
rm -rf "$FX"
mkdir -p "$FX/scripts/diagnostics"
ln -s "$REPO_ROOT/lib" "$FX/lib"
ln -s "$REPO_ROOT/$CHEATSHEET_REL" "$FX/$CHEATSHEET_REL"

test_start "cheatsheet_requires_the_alias_manifest"
CS_RC=0
CS_OUT="$(
  cd "$FX" && NO_COLOR=1 "${BASH:-bash}" "$CHEATSHEET_REL" 2>&1 </dev/null
)" || CS_RC=$?
assert_equals "1" "$CS_RC" "a missing manifest should exit 1"
assert_contains "Alias manifest not found" "$CS_OUT" \
  "the failure should name what is missing"

print_summary
