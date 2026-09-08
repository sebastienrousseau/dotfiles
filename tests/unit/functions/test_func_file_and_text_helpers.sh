#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for the small shell-function templates that ship in
# defaults/.chezmoitemplates/functions:
#
#   files/backup.sh            timestamped tar backups with retention
#   text/snakecase.sh          rename to snake_case
#   text/lowercase.sh          rename to lowercase
#   system/hstats.sh           history statistics
#   system/freespace.sh        secure-erase free space (macOS)
#   files/showhiddenfiles.sh   Finder dotfile visibility (macOS)
#   files/remove_disk.sh       eject a disk
#   misc/dothelp.sh            search the shell config for a term
#   curl/curlheader.sh         fetch HTTP headers
#
# Each function is sourced into a subshell and driven with fixtures inside
# the sandbox. Anything that would touch real hardware or the network
# (diskutil, osascript, defaults, curl) is a PATH-shadowed recording stub.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

FUNCS="$REPO_ROOT/defaults/.chezmoitemplates/functions"
REAL_BASH="${BASH:-$(command -v bash)}"
REAL_UNAME="$(command -v uname)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

_pass() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
}
_fail() {
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $1"
}

CALLS="$WORK/calls"
: >"$CALLS"
mkstub() {
  cat >"$BIN/$1" <<EOF
#!$REAL_BASH
printf '%s %s\n' "$1" "\$*" >>"$CALLS"
${2:-:}
exit ${3:-0}
EOF
  chmod +x "$BIN/$1"
}
# When the host has ripgrep, link it into the stub PATH so dothelp takes its
# ripgrep branch (with --color=always) rather than the grep fallback; the CI
# runners differ on whether ripgrep is installed, and both paths must pass.
_rg="$(command -v rg 2>/dev/null || true)"
[[ -n "$_rg" ]] && ln -sf "$_rg" "$BIN/rg"

mkstub diskutil
mkstub osascript
mkstub defaults
mkstub curl 'printf "HTTP/1.1 200 OK\nContent-Type: text/plain\n"'
cat >"$BIN/uname" <<EOF
#!$REAL_BASH
if [[ -n "\${FAKE_UNAME:-}" && "\${1:-}" == "-s" ]]; then echo "\$FAKE_UNAME"; exit 0; fi
exec "$REAL_UNAME" "\$@"
EOF
chmod +x "$BIN/uname"

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
# dothelp asks ripgrep for `--color=always`, so on a host that has ripgrep
# the matched term arrives wrapped in SGR escapes and a literal substring
# spanning it never matches. Compare against an escape-stripped copy.
plain_out() {
  sed $'s/\033\[[0-9;]*m//g' "$OUT" >"$OUT.plain"
  printf '%s' "$OUT.plain"
}
# call <function-file> <snippet> — source the template and run the snippet in
# a child shell. Stdout is captured in $OUT, stderr in $ERR and replayed so
# the coverage runner keeps its xtrace records. Echoes the exit status.
call() {
  local file="$1" snippet="$2" rc=0
  PATH="$BIN:/usr/bin:/bin" "$REAL_BASH" -c "
    set +e
    source '$FUNCS/$file'
    $snippet
  " </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}

# ===========================================================================
# files/backup.sh
# ===========================================================================
test_start "backup_requires_a_target"
rc="$(call files/backup.sh 'cd "'"$WORK"'"; backup')"
assert_equals "1" "$rc" "backup with no path fails"
assert_file_contains "$ERR" "at least one file or directory" "the error asks for a target"

test_start "backup_rejects_an_unknown_option"
rc="$(call files/backup.sh 'cd "'"$WORK"'"; backup --nope file')"
assert_equals "1" "$rc" "an unknown option fails"
assert_file_contains "$ERR" "Unknown option: --nope" "the error names the option"

test_start "backup_creates_an_uncompressed_archive_below_the_limit"
BK="$WORK/backup-basic"
mkdir -p "$BK/data"
printf 'hello\n' >"$BK/data/file.txt"
rc="$(call files/backup.sh 'cd "'"$BK"'"; backup data')"
assert_equals "0" "$rc" "backup exits 0"
assert_file_contains "$OUT" "Created backup archive" "the archive is announced"
assert_file_contains "$OUT" "No compression required" "a small archive is left uncompressed"
if compgen -G "$BK/backups/backup_*.tar" >/dev/null; then _pass; else _fail "no .tar archive was written"; fi

test_start "backup_compresses_when_over_the_max_size"
BK2="$WORK/backup-compress"
mkdir -p "$BK2/data"
printf 'padding-for-size\n' >"$BK2/data/file.txt"
rc="$(call files/backup.sh 'cd "'"$BK2"'"; backup --max-size 1 data')"
assert_equals "0" "$rc" "backup with a 1-byte limit exits 0"
assert_file_contains "$OUT" "Compressed to" "the archive is gzipped"
if compgen -G "$BK2/backups/backup_*.tar.gz" >/dev/null; then _pass; else _fail "no .tar.gz archive was written"; fi

test_start "backup_understands_size_units"
BK3="$WORK/backup-units"
mkdir -p "$BK3/data"
: >"$BK3/data/f"
# A tar archive of even an empty file is ~10 KB, so a 1K limit compresses.
call files/backup.sh 'cd "'"$BK3"'"; backup --max-size 1K data' >/dev/null
assert_file_contains "$OUT" "Compressed to" "a kilobyte limit is honoured"
call files/backup.sh 'cd "'"$BK3"'"; backup --max-size 1M data' >/dev/null
assert_file_contains "$OUT" "No compression required" "a megabyte limit is honoured"

test_start "backup_enforces_retention"
BK4="$WORK/backup-keep"
mkdir -p "$BK4/backups" "$BK4/data"
: >"$BK4/data/f"
for i in 1 2 3; do : >"$BK4/backups/backup_2020010${i}_000000.tar"; done
rc="$(call files/backup.sh 'cd "'"$BK4"'"; backup --keep 2 data')"
assert_equals "0" "$rc" "backup with retention exits 0"
assert_file_contains "$OUT" "Removed old backup" "older archives are pruned"
count="$(find "$BK4/backups" -name 'backup_*' | wc -l | tr -d ' ')"
assert_equals "2" "$count" "only --keep archives remain"

# ===========================================================================
# text/snakecase.sh and text/lowercase.sh
# ===========================================================================
test_start "snakecase_requires_an_argument"
rc="$(call text/snakecase.sh 'snakecase')"
assert_equals "1" "$rc" "snakecase with no path fails"
assert_file_contains "$ERR" "at least one file or directory" "the error asks for a target"

test_start "snakecase_renames_and_reports"
SC="$WORK/snake"
mkdir -p "$SC"
: >"$SC/My File Name.TXT"
: >"$SC/already_ok.txt"
rc="$(call text/snakecase.sh 'snakecase "'"$SC"'/My File Name.TXT" "'"$SC"'/already_ok.txt" "'"$SC"'/missing.txt"')"
assert_equals "0" "$rc" "snakecase exits 0 even when one path is missing"
assert_file_exists "$SC/my_file_name.txt" "the name is lowercased and underscored"
assert_file_contains "$OUT" "already in snake_case" "an already-converted name is skipped"
assert_file_contains "$ERR" "does not exist" "a missing path is reported"

test_start "lowercase_requires_an_argument"
rc="$(call text/lowercase.sh 'lowercase')"
assert_equals "1" "$rc" "lowercase with no path fails"

test_start "lowercase_renames_and_reports"
LC="$WORK/lower"
mkdir -p "$LC"
: >"$LC/MiXeD.TXT"
: >"$LC/plain.txt"
rc="$(call text/lowercase.sh 'lowercase "'"$LC"'/MiXeD.TXT" "'"$LC"'/plain.txt" "'"$LC"'/missing.txt"')"
assert_equals "0" "$rc" "lowercase exits 0 even when one path is missing"
assert_file_exists "$LC/mixed.txt" "the name is lowercased"
assert_file_contains "$OUT" "already in lowercase" "an already-lowercase name is skipped"
assert_file_contains "$ERR" "does not exist" "a missing path is reported"

# ===========================================================================
# system/hstats.sh
# ===========================================================================
test_start "hstats_help_explains_usage"
rc="$(call system/hstats.sh 'hstats --help')"
assert_equals "0" "$rc" "--help exits 0"
assert_file_contains "$OUT" "History Statistics Viewer" "the help header is printed"

test_start "hstats_summarises_history"
rc="$(call system/hstats.sh 'history() { printf "  1  git status\n  2  git status\n  3  ls\n"; }; SHELL=/bin/bash hstats')"
assert_equals "0" "$rc" "hstats exits 0"
assert_file_contains "$OUT" "Commonly Used Commands" "the banner is printed"
assert_file_contains "$OUT" "git" "the most-used command is counted"

test_start "hstats_uses_fc_on_zsh"
rc="$(call system/hstats.sh 'fc() { printf "  1  vim a\n  2  vim b\n"; }; SHELL=/bin/zsh hstats')"
assert_equals "0" "$rc" "the zsh branch exits 0"
assert_file_contains "$OUT" "vim" "history comes from fc on zsh"

# ===========================================================================
# system/freespace.sh
# ===========================================================================
test_start "freespace_help_lists_disks"
rc="$(call system/freespace.sh 'freespace --help')"
assert_equals "0" "$rc" "--help exits 0"
assert_file_contains "$OUT" "Free Disk Space Cleaner" "the help header is printed"
assert_file_contains "$OUT" "Available Disks" "attached disks are listed"

test_start "freespace_requires_a_disk"
rc="$(call system/freespace.sh 'freespace ""')"
assert_equals "1" "$rc" "no disk argument fails"
assert_file_contains "$OUT" "No disk provided" "the error asks for a disk"

test_start "freespace_erases_the_named_disk"
: >"$CALLS"
rc="$(call system/freespace.sh 'freespace /dev/disk9')"
assert_equals "0" "$rc" "freespace exits 0"
assert_file_contains "$OUT" "Cleaning purgeable files" "the operation is announced"
assert_file_contains "$CALLS" "diskutil secureErase freespace 0 /dev/disk9" "diskutil is driven with the right arguments"

# ===========================================================================
# files/showhiddenfiles.sh and files/remove_disk.sh
# ===========================================================================
test_start "showhiddenfiles_is_macos_only"
rc="$(call files/showhiddenfiles.sh 'FAKE_UNAME=Linux; export FAKE_UNAME; showhiddenfiles')"
assert_equals "1" "$rc" "a non-macOS host is refused"
assert_file_contains "$ERR" "macOS only" "the refusal explains why"

test_start "showhiddenfiles_toggles_finder_on_macos"
: >"$CALLS"
rc="$(call files/showhiddenfiles.sh 'FAKE_UNAME=Darwin; export FAKE_UNAME; showhiddenfiles')"
assert_equals "0" "$rc" "the macOS path exits 0"
assert_file_contains "$CALLS" "defaults write com.apple.Finder AppleShowAllFiles YES" "the Finder default is written"
assert_file_contains "$CALLS" "osascript" "Finder is restarted"

test_start "remove_disk_ejects_the_named_volume"
: >"$CALLS"
rc="$(call files/remove_disk.sh 'remove_disk /dev/disk9')"
assert_equals "0" "$rc" "remove_disk exits 0"
assert_file_contains "$CALLS" "diskutil eject /dev/disk9" "diskutil is asked to eject the disk"

# ===========================================================================
# misc/dothelp.sh
# ===========================================================================
test_start "dothelp_requires_a_search_term"
rc="$(call misc/dothelp.sh 'dothelp')"
assert_equals "1" "$rc" "no search term fails"
assert_file_contains "$OUT" "Usage: dothelp" "usage is printed"

test_start "dothelp_searches_the_shell_config"
mkdir -p "$HOME/.config/shell"
printf "alias gs='git status'\n" >"$HOME/.config/shell/aliases.sh"
rc="$(call misc/dothelp.sh 'dothelp git')"
assert_equals "0" "$rc" "a matching search exits 0"
assert_file_contains "$(plain_out)" "git status" "the matching line is shown"

test_start "dothelp_falls_back_to_grep_without_ripgrep"
# A PATH without rg must still search, via grep.
NORG="$WORK/norg-bin"
mkdir -p "$NORG"
for tool in bash grep cat printf; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$NORG/$tool"
done
rc=0
PATH="$NORG" HOME="$HOME" "$REAL_BASH" -c "
  set +e
  source '$FUNCS/misc/dothelp.sh'
  dothelp git
" >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "0" "$rc" "the grep fallback exits 0"
assert_file_contains "$(plain_out)" "git status" "grep finds the same line"

# ===========================================================================
# curl/curlheader.sh
# ===========================================================================
test_start "curlheader_help_explains_usage"
rc="$(call curl/curlheader.sh 'curlheader --help')"
assert_equals "0" "$rc" "--help exits 0"
assert_file_contains "$OUT" "Curl Header Viewer" "the help header is printed"

test_start "curlheader_fetches_all_headers"
: >"$CALLS"
rc="$(call curl/curlheader.sh 'curlheader https://example.com ""')"
assert_equals "0" "$rc" "fetching all headers exits 0"
assert_file_contains "$OUT" "Fetching all headers" "the operation is announced"
assert_file_contains "$CALLS" "https://example.com" "curl is pointed at the URL"

test_start "curlheader_filters_a_named_header"
: >"$CALLS"
rc="$(call curl/curlheader.sh 'curlheader Content-Type https://example.com')"
assert_equals "0" "$rc" "filtering exits 0"
assert_file_contains "$OUT" "Fetching 'Content-Type' header" "the filtered header is announced"
assert_file_contains "$OUT" "Content-Type: text/plain" "only the matching header is shown"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
