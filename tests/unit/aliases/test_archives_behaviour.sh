#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# The archives alias functions (compress, extract, list_archive,
# compress_large, backup) end to end, with recording stub archivers.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

ARCHIVES="$REPO_ROOT/defaults/.chezmoitemplates/aliases/archives/archives.aliases.sh"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/pv"
for t in tar zip 7z gzip bzip2 xz zstd lz4 rar unrar unzip unzstd unxz bunzip2 gunzip; do
  printf '#!/bin/sh\necho "%s $*" >>"$CALLS"\n[ "${FAIL_TOOL:-}" = "%s" ] && exit 3\nexit 0\n' "$t" "$t" >"$WORK/bin/$t"
  chmod +x "$WORK/bin/$t"
done
printf '#!/bin/sh\necho 20260101-000000\n' >"$WORK/bin/date"
printf '#!/bin/sh\necho "pv $*" >>"$CALLS"\ncat "$1"\n' >"$WORK/pv/pv"
chmod +x "$WORK/bin/date" "$WORK/pv/pv"
N=0

# arc [PV=1] [FAIL_TOOL=x] -- <shell code>: run it in a fresh directory
# holding a.txt, b.txt and dir/; sets OUT, RC, D (the directory).
arc() {
  local path="$WORK/bin:/usr/bin:/bin" fail=""
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    case "$1" in PV=1) path="$WORK/pv:$path" ;; FAIL_TOOL=*) fail="${1#*=}" ;; esac
    shift
  done
  shift
  D="$WORK/c$((++N))"
  mkdir -p "$D/dir" && echo a >"$D/a.txt" && echo b >"$D/b.txt" && : >"$D/x.zip" && : >"$D/x.tar.gz"
  OUT="$(cd "$D" && env -i HOME="$D" PATH="$path" CALLS="$D/calls" FAIL_TOOL="$fail" ARCHIVE_LOG_FILE="$D/log" \
    bash -c 'source "$0"; eval "$1"; echo "rc=$?"; echo "pwd=$PWD"' "$ARCHIVES" "$*" 2>&1)"
}
pwd_ends() { if printf '%s\n' "$OUT" | grep -q "^pwd=.*/$1\$"; then echo yes; else echo no; fi; }
has() { if [[ "$OUT" == *"$1"* ]]; then echo yes; else echo no; fi; }
called() { if grep -qF -- "$1" "$D/calls" 2>/dev/null; then echo yes; else echo no; fi; }

test_start "extract_into_a_directory"
arc -- extract x.zip -d out
assert_equals "yes:yes:yes" "$(has 'rc=0'):$(pwd_ends out):$(called 'unzip x.zip')" "-d creates the directory, enters it, and extracts"

test_start "extract_dash_d_without_a_directory_stays_put"
arc -- extract x.zip -d
assert_equals "yes" "$(pwd_ends "c$N")" "no directory named, no cd"

test_start "extract_into_an_uncreatable_directory_fails"
arc -- ': >blocker; extract x.zip -d blocker/sub'
assert_equals "yes:no" "$(has 'rc=1'):$(called 'unzip')" "mkdir/cd failure stops before extracting"

test_start "extract_unknown_format_fails"
arc -- ': >x.unknown; extract x.unknown'
assert_equals "yes:yes" "$(has 'rc=1'):$(has 'cannot be extracted - unknown format')" "unknown extension"

test_start "extract_reports_a_failing_tool"
arc FAIL_TOOL=unzip -- extract x.zip
assert_equals "yes" "$(has 'Failed to extract x.zip')" "the tool's failure is logged"

test_start "compress_unsupported_format_with_a_default_name_fails"
arc -- compress bogus a.txt
assert_equals "yes:yes:no" "$(has 'rc=1'):$(has "Unsupported format 'bogus'"):$(has 'Compressing to')" "fails before starting"

test_start "compress_unsupported_format_with_an_explicit_name_fails"
arc -- compress bogus a.txt out.x
assert_equals "yes:yes:yes" "$(has 'rc=1'):$(has 'Compressing to out.x...'):$([[ -s "$D/log" ]] && echo yes)" "fails after announcing; logged"

test_start "compress_stream_format_rejects_several_inputs"
arc -- compress xz a.txt b.txt
assert_equals "yes:yes:no" "$(has 'rc=1'):$(has 'xz compression requires a single input file'):$(called 'xz')" "no xz run"

test_start "compress_failing_tool_fails"
arc FAIL_TOOL=tar -- compress tar a.txt
assert_equals "yes:yes" "$(has 'rc=1'):$(has 'Failed to compress to a.txt.tar')" "the tool's failure is the result"

test_start "compress_success"
arc -- compress zip a.txt
assert_equals "yes:yes" "$(has 'rc=0'):$(has 'Successfully compressed to a.txt.zip')" "zip a.txt → a.txt.zip"

test_start "compress_tgz_single_file_streams_through_pv"
arc PV=1 -- compress tgz a.txt
assert_equals "yes:yes" "$(called 'pv a.txt'):$(called 'tar -cz -f a.txt.tar.gz -C . a.txt')" "pv for one file"

test_start "compress_tgz_several_files_skip_pv"
arc PV=1 -- compress tgz a.txt b.txt
assert_equals "no:yes" "$(called 'pv '):$(called 'tar -czf a.txt.tar.gz a.txt b.txt')" "no pv for several files"

test_start "compress_tgz_without_pv"
arc -- compress tgz a.txt
assert_equals "yes" "$(called 'tar -czf a.txt.tar.gz a.txt')" "plain tar without pv"

test_start "compress_stream_through_pv"
arc PV=1 -- compress zst -l 3 a.txt
assert_equals "yes:yes" "$(called 'pv a.txt'):$(called 'zstd -3')" "pv | zstd -3"

test_start "compress_level_and_formats"
arc -- 'compress txz -l 2 a.txt; compress 7z -l 9 a.txt; compress rar a.txt; compress tbz2 dir'
assert_equals "yes:yes:yes:yes" \
  "$(called 'tar -cJf a.txt.tar.xz a.txt'):$(called '7z a -mx=9 a.txt.7z a.txt'):$(called 'rar a -m6 a.txt.rar a.txt'):$(called 'tar -cjf dir.tar.bz2 -C . dir')" \
  "levels and per-format commands"

test_start "compress_large_unsupported_format_fails"
arc -- compress_large bogus a.txt
assert_equals "yes:yes" "$(has 'rc=1'):$(has "Unsupported format 'bogus'")" "compress_large rejects it"

test_start "backup_formats"
arc -- 'backup a.txt; backup dir zip; backup a.txt tzst'
assert_equals "yes:yes:yes" \
  "$(called 'tar -czf a.txt-backup-20260101-000000.tar.gz a.txt'):$(called 'zip -r dir-backup-20260101-000000.zip dir -6'):$(called 'a.txt-backup-20260101-000000.tar.zst')" \
  "tgz by default, zip, tzst"

test_start "backup_unsupported_format_fails"
arc -- backup a.txt bogus
assert_equals "yes:yes" "$(has 'rc=1'):$(has "Unsupported backup format 'bogus'")" "no archive, an error"

test_start "backup_reports_a_failed_compress"
arc FAIL_TOOL=tar -- backup a.txt
assert_equals "no" "$(has 'Backup created')" "a failed archive is not reported as a backup"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
