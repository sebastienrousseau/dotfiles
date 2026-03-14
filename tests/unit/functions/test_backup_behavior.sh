#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034,SC2012
# Behavioral tests for the backup function from .chezmoitemplates/functions/files/backup.sh.
# Tests timestamped archive creation, compression, retention, and error paths.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"

FUNC_FILE="$REPO_ROOT/.chezmoitemplates/functions/files/backup.sh"
if [[ ! -f "$FUNC_FILE" ]]; then
  echo "SKIP: backup.sh not found at $FUNC_FILE"
  echo "RESULTS:0:0:0"
  exit 0
fi
source "$FUNC_FILE"

# ──────────────────────────────────────────────────────────────────────────────
# 1. No arguments → non-zero exit with ERROR message
# ──────────────────────────────────────────────────────────────────────────────
test_start "backup_no_args_error"
output=$(backup 2>&1)
assert_equals "1" "$?" "no-arg backup should exit 1"
assert_contains "ERROR" "$output" "no-arg backup should print ERROR"

# ──────────────────────────────────────────────────────────────────────────────
# 2. Unknown option → non-zero exit with ERROR
# ──────────────────────────────────────────────────────────────────────────────
test_start "backup_unknown_option"
output=$(backup --no-such-option 2>&1)
assert_equals "1" "$?" "unknown option should exit 1"
assert_contains "Unknown option" "$output" "unknown option should print 'Unknown option'"

# ──────────────────────────────────────────────────────────────────────────────
# 3. Backing up a non-existent path → non-zero exit
# ──────────────────────────────────────────────────────────────────────────────
test_start "backup_nonexistent_source"
tmp_root=$(mktemp -d)
BACKUP_DIR="$tmp_root/backups"
output=$(backup "/no/such/path/xyzzy_$$" 2>&1)
assert_equals "1" "$?" "backing up non-existent path should exit 1"
rm -rf "$tmp_root"

# ──────────────────────────────────────────────────────────────────────────────
# 4. Successful backup creates the backups directory if absent
# ──────────────────────────────────────────────────────────────────────────────
test_start "backup_creates_backup_dir"
tmp_root=$(mktemp -d)
test_file="$tmp_root/sample.txt"
echo "hello" >"$test_file"
BACKUP_DIR="$tmp_root/backups"
backup "$test_file" >/dev/null 2>&1
assert_dir_exists "$BACKUP_DIR" "backup should create the backups directory"
rm -rf "$tmp_root"

# ──────────────────────────────────────────────────────────────────────────────
# 5. Successful backup produces a timestamped .tar archive
# ──────────────────────────────────────────────────────────────────────────────
test_start "backup_creates_timestamped_archive"
tmp_root=$(mktemp -d)
test_file="$tmp_root/data.txt"
echo "content" >"$test_file"
BACKUP_DIR="$tmp_root/backups"
backup "$test_file" >/dev/null 2>&1
# The archive name must match backup_YYYYMMDD_HHMMSS.tar (or .tar.gz)
archive_count=$(ls "$BACKUP_DIR"/backup_*.tar* 2>/dev/null | wc -l | tr -d ' ')
assert_true "[[ $archive_count -ge 1 ]]" "at least one timestamped archive should be created"
# Verify timestamp format in filename
latest=$(ls "$BACKUP_DIR"/backup_*.tar* 2>/dev/null | head -n1)
basename_f="$(basename "$latest")"
if [[ "$basename_f" =~ ^backup_[0-9]{8}_[0-9]{6}\.tar(\.gz)?$ ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: archive filename matches timestamp format"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: archive filename should match backup_YYYYMMDD_HHMMSS.tar"
  printf '%b\n' "    Actual filename: '$basename_f'"
fi
rm -rf "$tmp_root"

# ──────────────────────────────────────────────────────────────────────────────
# 6. Archive is a valid tar file (can be listed)
# ──────────────────────────────────────────────────────────────────────────────
test_start "backup_archive_is_valid_tar"
tmp_root=$(mktemp -d)
test_file="$tmp_root/verify.txt"
echo "verify content" >"$test_file"
BACKUP_DIR="$tmp_root/backups"
backup "$test_file" >/dev/null 2>&1
latest=$(ls "$BACKUP_DIR"/backup_*.tar 2>/dev/null | head -n1)
if [[ -n "$latest" ]] && tar tf "$latest" >/dev/null 2>&1; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: archive is a valid tar file"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: archive should be a readable tar file"
fi
rm -rf "$tmp_root"

# ──────────────────────────────────────────────────────────────────────────────
# 7. Small file with --max-size 1K gets compressed to .tar.gz
# ──────────────────────────────────────────────────────────────────────────────
test_start "backup_compression_when_exceeds_maxsize"
tmp_root=$(mktemp -d)
test_file="$tmp_root/big.txt"
# Write 2 KB of data so it exceeds 1 KB limit
dd if=/dev/urandom bs=1024 count=2 2>/dev/null | base64 >"$test_file"
BACKUP_DIR="$tmp_root/backups"
backup --max-size 1K "$test_file" >/dev/null 2>&1
gz_count=$(ls "$BACKUP_DIR"/backup_*.tar.gz 2>/dev/null | wc -l | tr -d ' ')
assert_true "[[ $gz_count -ge 1 ]]" "archive exceeding max-size should be compressed to .tar.gz"
rm -rf "$tmp_root"

# ──────────────────────────────────────────────────────────────────────────────
# 8. Retention: after creating N+1 backups with --keep N, only N remain
# ──────────────────────────────────────────────────────────────────────────────
test_start "backup_retention_keep_2"
tmp_root=$(mktemp -d)
test_file="$tmp_root/retain.txt"
echo "retain" >"$test_file"
BACKUP_DIR="$tmp_root/backups"
# Create 4 backups with keep=2 (each must be a distinct second for mtime sort)
for i in 1 2 3 4; do
  # Brief sleep not needed when timestamps differ by creation order; however
  # 'find ... sort -r' is mtime-based so add a small gap.
  backup --keep 2 "$test_file" >/dev/null 2>&1
  sleep 1 2>/dev/null || true
done
remaining=$(ls "$BACKUP_DIR"/backup_*.tar* 2>/dev/null | wc -l | tr -d ' ')
assert_true "[[ $remaining -le 2 ]]" "with --keep 2, at most 2 backups should remain (got $remaining)"
rm -rf "$tmp_root"

# ──────────────────────────────────────────────────────────────────────────────
# 9. Multiple source files in one invocation
# ──────────────────────────────────────────────────────────────────────────────
test_start "backup_multiple_sources"
tmp_root=$(mktemp -d)
file_a="$tmp_root/a.txt"
file_b="$tmp_root/b.txt"
echo "a" >"$file_a"
echo "b" >"$file_b"
BACKUP_DIR="$tmp_root/backups"
output=$(backup "$file_a" "$file_b" 2>&1)
assert_equals "0" "$?" "backup of multiple files should succeed"
assert_contains "completed" "$output" "should print completion message"
rm -rf "$tmp_root"

# ──────────────────────────────────────────────────────────────────────────────
# 10. Backup of a directory succeeds and archive contains directory contents
# ──────────────────────────────────────────────────────────────────────────────
test_start "backup_directory_source"
tmp_root=$(mktemp -d)
src_dir="$tmp_root/mydir"
mkdir -p "$src_dir"
echo "file1" >"$src_dir/f1.txt"
echo "file2" >"$src_dir/f2.txt"
BACKUP_DIR="$tmp_root/backups"
backup "$src_dir" >/dev/null 2>&1
rc=$?
assert_equals "0" "$rc" "backup of a directory should exit 0"
latest=$(ls "$BACKUP_DIR"/backup_*.tar* 2>/dev/null | head -n1)
if [[ -n "$latest" ]]; then
  if tar tf "$latest" 2>/dev/null | grep -q "f1.txt"; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: archive contains directory contents"
  else
    ((TESTS_FAILED++)) || true
    printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: archive should contain directory contents"
  fi
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: no archive file found after backing up directory"
fi
rm -rf "$tmp_root"

mock_cleanup

echo ""
echo "backup behavioral tests completed."
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
