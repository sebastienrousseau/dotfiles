#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# install/migrate/rollback-v0_2_503.sh is retired: with or without a
# migration snapshot it must stop, touch nothing, and name the manual
# recovery, instead of the old "snapshot missing 'current ver:'" dead end
# or a silent success.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ROLLBACK="${ROLLBACK:-$REPO_ROOT/install/migrate/rollback-v0_2_503.sh}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
# chezmoi and git stubs record any call: the retired script makes none.
for t in chezmoi git; do
  printf '#!/bin/sh\necho "%s $*" >>"$CALLS"\n' "$t" >"$WORK/bin/$t"
  chmod +x "$WORK/bin/$t"
done

# rollback <home>: run the script in a sandbox HOME; sets OUT, RC, CALLS.
rollback() {
  CALLS="$1/calls"
  : >"$CALLS"
  OUT="$(env -i ${BASH_ENV:+BASH_ENV="$BASH_ENV"} ${PS4:+PS4="$PS4"} \
    HOME="$1" PATH="$WORK/bin:/usr/bin:/bin" CALLS="$CALLS" \
    bash "$ROLLBACK" 2>&1)"
  RC=$?
}

test_start "rollback_with_a_snapshot_names_the_manual_recovery"
H="$WORK/snap"
mkdir -p "$H/.local/state/dotfiles/v0_2_503-migration"
printf 'target ver:     0.2.503\n' >"$H/.local/state/dotfiles/v0_2_503-migration/snapshot-20260101T000000Z.log"
rollback "$H"
assert_equals "1" "$RC" "it fails"
assert_contains "no longer supported" "$OUT" "says it is retired"
assert_contains "git checkout v0.2.502" "$OUT" "names the manual recovery"
assert_contains "install/migrate/README.md" "$OUT" "points at the README"
assert_equals "" "$(cat "$CALLS")" "runs neither chezmoi nor git"
assert_file_exists "$H/.local/state/dotfiles/v0_2_503-migration/snapshot-20260101T000000Z.log" "leaves the snapshot alone"

test_start "rollback_without_a_snapshot_still_names_the_manual_recovery"
H="$WORK/none"
mkdir -p "$H"
rollback "$H"
assert_equals "1" "$RC" "it fails rather than claiming success"
assert_contains "git checkout v0.2.502" "$OUT" "names the manual recovery"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
