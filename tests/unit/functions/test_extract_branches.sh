#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034,SC2016
# Behavioural coverage for functions/files/extract.sh: every archive
# suffix dispatches to its extractor. Real tar/gzip/bzip2 archives are
# built inside the sandbox; extractors that are not guaranteed on a CI
# host (unzip, unrar, uncompress, 7z) are PATH-shadowed shims.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Keep bash xtrace flowing to the coverage runner's trace stream even
# when a probe below captures 2>&1.
exec 21>&2
export BASH_XTRACEFD=21

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/files/extract.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

shim_dir="$DOTFILES_COV_TMPDIR/extract-shims"
mkdir -p "$shim_dir"
for tool in unzip unrar uncompress 7z; do
  cat >"$shim_dir/$tool" <<EOF
#!/usr/bin/env bash
echo "shim-$tool \$*"
EOF
  chmod +x "$shim_dir/$tool"
done
export PATH="$shim_dir:$PATH"

# run_extract <workdir> <archive> — source the function file in a child
# bash inside <workdir> and call extract on <archive>.
run_extract() {
  (cd "$1" && bash -c 'source "$1"; shift; extract "$@"' _ "$FUNC_FILE" "$2")
}

work="$DOTFILES_COV_TMPDIR/archives"
mkdir -p "$work"
echo "payload" >"$work/hello.txt"
(
  cd "$work" || exit 1
  tar cjf a.tar.bz2 hello.txt
  tar czf a.tar.gz hello.txt
  tar cjf a.tbz2 hello.txt
  tar czf a.tgz hello.txt
  tar cf a.tar hello.txt
  cp hello.txt b.txt && bzip2 b.txt
  cp hello.txt c.txt && gzip c.txt
  : >a.zip
  : >a.rar
  : >a.Z
  : >a.7z
  : >a.unknown
)

for archive in a.tar.bz2 a.tar.gz a.tbz2 a.tgz a.tar; do
  test_start "extract_${archive//./_}_via_tar"
  case_dir="$DOTFILES_COV_TMPDIR/case-$archive"
  mkdir -p "$case_dir"
  cp "$work/$archive" "$case_dir/"
  out="$(run_extract "$case_dir" "$archive" 2>&1)"
  rc=$?
  assert_equals 0 "$rc" "extract $archive exits 0"
  assert_contains "[INFO] Extracting '$archive'" "$out" "reports the archive"
  assert_file_exists "$case_dir/hello.txt" "member extracted from $archive"
done

test_start "extract_bz2_via_bunzip2"
case_dir="$DOTFILES_COV_TMPDIR/case-bz2"
mkdir -p "$case_dir"
cp "$work/b.txt.bz2" "$case_dir/"
out="$(run_extract "$case_dir" b.txt.bz2 2>&1)"
assert_equals 0 "$?" "bunzip2 path exits 0"
assert_file_exists "$case_dir/b.txt" "bz2 payload restored"

test_start "extract_gz_via_gunzip"
case_dir="$DOTFILES_COV_TMPDIR/case-gz"
mkdir -p "$case_dir"
cp "$work/c.txt.gz" "$case_dir/"
out="$(run_extract "$case_dir" c.txt.gz 2>&1)"
assert_equals 0 "$?" "gunzip path exits 0"
assert_file_exists "$case_dir/c.txt" "gz payload restored"

for pair in "a.zip:unzip" "a.rar:unrar" "a.Z:uncompress" "a.7z:7z"; do
  archive="${pair%%:*}"
  tool="${pair##*:}"
  test_start "extract_${archive//./_}_dispatches_to_${tool}"
  out="$(run_extract "$work" "$archive" 2>&1)"
  rc=$?
  assert_equals 0 "$rc" "$tool shim path exits 0"
  assert_contains "shim-$tool" "$out" "$archive is handed to $tool"
done

test_start "extract_unknown_suffix_rejected"
out="$(run_extract "$work" a.unknown 2>&1)"
rc=$?
assert_equals 1 "$rc" "unknown suffix exits 1"
assert_contains "cannot be extracted" "$out" "explains the rejection"

test_start "extract_missing_file_rejected"
out="$(run_extract "$work" nope.tar.gz 2>&1)"
rc=$?
assert_equals 1 "$rc" "missing file exits 1"
assert_contains "is not a valid file" "$out" "explains the rejection"

test_start "extract_requires_exactly_one_argument"
out="$(bash -c 'source "$1"; extract a b' _ "$FUNC_FILE" 2>&1)"
rc=$?
assert_equals 1 "$rc" "two arguments exit 1"
assert_contains "Please provide one argument" "$out" "usage error printed"

test_start "extract_help"
out="$(bash -c 'source "$1"; extract --help' _ "$FUNC_FILE" 2>&1)"
rc=$?
assert_equals 0 "$rc" "--help exits 0"
assert_contains "extract: Archive Extractor" "$out" "help banner printed"

test_start "extract_guard_keeps_existing_definition"
out="$(bash -c 'extract() { echo "pre-existing $*"; }; source "$1"; extract x' _ "$FUNC_FILE" 2>&1)"
assert_contains "pre-existing x" "$out" "declare -f guard skips redefinition"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
