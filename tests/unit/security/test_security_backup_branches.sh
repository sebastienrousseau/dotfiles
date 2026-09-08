#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Branch coverage for scripts/security/backup.sh: the success path
# archives a small sandbox source tree, and the failure path uses a
# `tar` shim that exits non-zero so the partial archive is removed.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Route child xtrace to the runner's trace stream even when a probe
# captures 2>&1 (fd 19: fd 9 is taken by lock handling elsewhere).
exec 21>&2
export BASH_XTRACEFD=21

SCRIPT_FILE="$REPO_ROOT/scripts/security/backup.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

_src="$DOTFILES_COV_TMPDIR/src"
_dest="$DOTFILES_COV_TMPDIR/dest"
mkdir -p "$_src/sub"
echo "hello" >"$_src/sub/file.txt"

test_start "backup_writes_timestamped_archive"
_out="$(DOTFILES_BACKUP_SRC="$_src" DOTFILES_BACKUP_DIR="$_dest" "$BASH_BIN" "$SCRIPT_FILE" 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "backup exits 0"
assert_contains "Backup written" "$_out" "success line printed"
_archive="$(find "$_dest" -name 'dotfiles-backup-*.tgz' | head -1)"
assert_not_empty "$_archive" "archive file created"
assert_contains "sub/file.txt" "$(tar -tzf "$_archive" 2>/dev/null)" "archive lists the source file"

test_start "backup_failure_removes_partial_archive"
_shim="$DOTFILES_COV_TMPDIR/failtar"
mkdir -p "$_shim"
cat >"$_shim/tar" <<'SHIM'
#!/usr/bin/env bash
# Simulate tar dying after creating a partial archive.
while [[ $# -gt 0 ]]; do
  case "$1" in
    -czf) echo partial >"$2"; shift 2 ;;
    *) shift ;;
  esac
done
exit 1
SHIM
chmod +x "$_shim/tar"
_dest2="$DOTFILES_COV_TMPDIR/dest2"
_out="$(PATH="$_shim:$PATH" DOTFILES_BACKUP_SRC="$_src" DOTFILES_BACKUP_DIR="$_dest2" "$BASH_BIN" "$SCRIPT_FILE" 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "failed backup exits 1"
assert_contains "Backup failed" "$_out" "failure reported"
assert_equals "" "$(find "$_dest2" -name 'dotfiles-backup-*.tgz')" "partial archive removed"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
