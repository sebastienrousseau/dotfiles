#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural contract for scripts/version-sync.sh's VERSION validation,
# found as a surviving mutant (Y1) of tools/ci/mutation-test.py: a VERSION
# argument must be a WHOLE x.y.z. Text before the number (`x1.2.3`) is
# rejected with exit 1 and the manifest is left alone (regex anchor `^`);
# companion cases pin the `$` anchor and the accepted form.
#
# Same isolation as test_version_sync_coverage.sh: the script is symlinked
# into a mktemp tree so PROJECT_ROOT resolves there, never to the checkout,
# and lib/ is a copy. Writes are enabled explicitly because a rejected
# version must be shown to write nothing.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$REPO_ROOT/tests/framework/assertions.sh"

VS_REAL="$REPO_ROOT/scripts/version-sync.sh"
WORK="$(mktemp -d -t vs-validate.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

T="$WORK/tree"
mkdir -p "$T/scripts" "$T/defaults"
cp -R "$REPO_ROOT/lib" "$T/lib"
find "$T/lib" -type f ! -name '*.sh' -exec rm -f {} +
ln -s "$VS_REAL" "$T/scripts/version-sync.sh"
# Each case starts from the same manifest so a leak from one case cannot
# masquerade as a failure of the next.
reset_manifest() { printf 'dotfiles_version = "1.0.0"\n' >"$T/defaults/.chezmoidata.toml"; }
reset_manifest
printf '{\n  "name": "fixture",\n  "version": "1.0.0"\n}\n' >"$T/package.json"
printf '# Doc\n\n**Version**: v1.0.0\n' >"$T/README.md"

OUT=""
RC=0
# vs [args...]: run the symlinked script inside the fixture tree.
vs() {
  RC=0
  OUT="$(cd "$T" && env -u DOTFILES_COV_TMPDIR NO_COLOR=1 \
    DOTFILES_ALLOW_COVERAGE_WRITES=1 "$BASH" scripts/version-sync.sh "$@" 2>&1)" || RC=$?
}

# The assert_* helpers return 1 on failure: tally every case, don't abort.
set +e

test_start "version_sync_rejects_text_before_version"
reset_manifest
vs --no-backup x1.2.3
assert_equals 1 "$RC" "junk-prefixed version exits 1"
assert_contains "Invalid version format: x1.2.3" "$OUT" "prefix rejected by name"
assert_file_contains "$T/defaults/.chezmoidata.toml" 'dotfiles_version = "1.0.0"' \
  "manifest untouched by a rejected version"

test_start "version_sync_rejects_text_after_version"
reset_manifest
vs --no-backup 1.2.3x
assert_equals 1 "$RC" "junk-suffixed version exits 1"
assert_contains "Invalid version format: 1.2.3x" "$OUT" "suffix rejected by name"
assert_file_contains "$T/defaults/.chezmoidata.toml" 'dotfiles_version = "1.0.0"' \
  "manifest untouched by a rejected version"

test_start "version_sync_accepts_whole_version"
vs --dry-run 1.2.3
assert_equals 0 "$RC" "whole x.y.z is accepted"
assert_contains "Using specified version: 1.2.3" "$OUT" "accepted version echoed"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
