#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for lib/dot/verified-download.sh — the checksum-pinned
# fetchers used by the installer. `curl` is a sandbox stub that serves files
# from a fixture directory, so every guard (non-HTTPS URL, unpinned URL,
# transport failure, size limits, checksum mismatch, non-script payload) is
# exercised without a single network call.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

LIB="$REPO_ROOT/lib/dot/verified-download.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

BIN="$DOTFILES_COV_TMPDIR/bin"
FIX="$DOTFILES_COV_TMPDIR/served"
DEST="$DOTFILES_COV_TMPDIR/downloaded"
ERRF="$DOTFILES_COV_TMPDIR/err.txt"
mkdir -p "$FIX"

# curl stub: serve $CURL_ROOT/<basename of URL>, or fail with $CURL_RC.
cat >"$BIN/curl" <<'STUB'
#!/usr/bin/env bash
out=""
url=""
while (($#)); do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    -*) shift ;;
    *)
      url="$1"
      shift
      ;;
  esac
done
[[ "${CURL_RC:-0}" -ne 0 ]] && exit "${CURL_RC}"
src="$CURL_ROOT/$(basename "$url")"
[[ -f "$src" ]] || exit 22
cat "$src" >"$out"
exit 0
STUB
chmod +x "$BIN/curl"
export CURL_ROOT="$FIX"

sha_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# call <fn> <args…> — run one fetcher in a subshell with the lib sourced.
call() {
  (
    source "$LIB"
    "$@"
  ) 2>"$ERRF"
  RC=$?
  [[ "${DOTFILES_COV_ECHO_STDERR:-0}" == "1" ]] && cat "$ERRF" >&2
  return 0
}
err_has() { assert_file_contains "$ERRF" "$1" "${2:-stderr contains $1}"; }

printf '#!/usr/bin/env bash\necho installed\n' >"$FIX/install.sh"
GOOD_SHA="$(sha_of "$FIX/install.sh")"
MANIFEST="$DOTFILES_COV_TMPDIR/remote-installers.sha256"
printf '%s  https://example.com/install.sh\n' "$GOOD_SHA" >"$MANIFEST"
export DOTFILES_INSTALLER_MANIFEST="$MANIFEST"

test_start "library_exists_and_parses"
assert_file_exists "$LIB" "verified-download.sh must exist"
assert_true "bash -n '$LIB'" "valid bash syntax"

# ── download_verified_script ────────────────────────────────────────────
test_start "a_pinned_installer_is_downloaded_and_verified"
rm -f "$DEST"
call download_verified_script https://example.com/install.sh "$DEST"
assert_equals 0 "$RC" "rc"
assert_file_exists "$DEST" "payload written"
assert_file_contains "$DEST" "echo installed" "payload content"

test_start "a_non_https_url_is_refused_before_any_fetch"
rm -f "$DEST"
call download_verified_script http://example.com/install.sh "$DEST"
assert_equals 2 "$RC" "rc"
err_has "Refusing non-HTTPS installer URL" "error"
assert_file_not_exists "$DEST" "nothing downloaded"

test_start "an_unreadable_manifest_is_refused"
call env DOTFILES_INSTALLER_MANIFEST="$DOTFILES_COV_TMPDIR/absent.sha256" \
  bash -c 'source "$0"; download_verified_script https://example.com/install.sh "$1"' \
  "$LIB" "$DEST"
assert_equals 2 "$RC" "rc"
err_has "checksum manifest not readable" "error"

test_start "the_default_manifest_path_is_the_repo_copy"
(
  unset DOTFILES_INSTALLER_MANIFEST
  call download_verified_script https://example.com/never-pinned.sh "$DEST"
  assert_equals 2 "$RC" "rc"
  err_has "not checksum-pinned" "falls back to the tracked manifest"
)

test_start "an_unpinned_url_is_refused"
call download_verified_script https://example.com/other.sh "$DEST"
assert_equals 2 "$RC" "rc"
err_has "not checksum-pinned" "error"

test_start "a_transport_failure_removes_the_partial_file"
printf 'partial' >"$DEST"
CURL_RC=7 call download_verified_script https://example.com/install.sh "$DEST"
assert_equals 1 "$RC" "rc"
assert_file_not_exists "$DEST" "partial file cleaned up"

test_start "an_empty_payload_is_rejected"
: >"$FIX/empty.sh"
printf '%s  https://example.com/empty.sh\n' "$(sha_of "$FIX/empty.sh")" >>"$MANIFEST"
call download_verified_script https://example.com/empty.sh "$DEST"
assert_equals 1 "$RC" "rc"
err_has "size outside allowed range" "error"
assert_file_not_exists "$DEST" "cleaned up"

test_start "an_oversized_payload_is_rejected"
call download_verified_script https://example.com/install.sh "$DEST" 4
assert_equals 1 "$RC" "rc"
err_has "size outside allowed range" "error names the limit breach"

test_start "a_checksum_mismatch_is_rejected"
printf '#!/usr/bin/env bash\necho tampered\n' >"$FIX/tampered.sh"
printf '%s  https://example.com/tampered.sh\n' "$GOOD_SHA" >>"$MANIFEST"
call download_verified_script https://example.com/tampered.sh "$DEST"
assert_equals 1 "$RC" "rc"
err_has "checksum mismatch" "error"
assert_file_not_exists "$DEST" "cleaned up"

test_start "a_verified_payload_that_is_not_a_script_is_rejected"
printf 'plain text, no shebang\n' >"$FIX/notscript.sh"
printf '%s  https://example.com/notscript.sh\n' "$(sha_of "$FIX/notscript.sh")" >>"$MANIFEST"
call download_verified_script https://example.com/notscript.sh "$DEST"
assert_equals 1 "$RC" "rc"
err_has "not an executable script" "error"

# ── download_verified_asset ─────────────────────────────────────────────
printf 'binary-release-payload\n' >"$FIX/tool.tar.gz"
ASSET_SHA="$(sha_of "$FIX/tool.tar.gz")"
printf '%s  tool.tar.gz\n' "$ASSET_SHA" >"$FIX/checksums.txt"

test_start "a_release_asset_is_downloaded_and_verified"
rm -f "$DEST"
call download_verified_asset https://example.com/tool.tar.gz \
  https://example.com/checksums.txt tool.tar.gz "$DEST"
assert_equals 0 "$RC" "rc"
assert_file_contains "$DEST" "binary-release-payload" "payload written"

test_start "starred_checksum_names_are_accepted"
printf '%s *tool.tar.gz\n' "$ASSET_SHA" >"$FIX/checksums.txt"
rm -f "$DEST"
call download_verified_asset https://example.com/tool.tar.gz \
  https://example.com/checksums.txt tool.tar.gz "$DEST"
assert_equals 0 "$RC" "rc"
assert_file_exists "$DEST" "payload written"

test_start "non_https_asset_urls_are_refused"
call download_verified_asset http://example.com/tool.tar.gz \
  https://example.com/checksums.txt tool.tar.gz "$DEST"
assert_equals 2 "$RC" "rc"
err_has "Refusing non-HTTPS release asset URL" "error"

test_start "an_asset_name_with_a_path_separator_is_refused"
call download_verified_asset https://example.com/tool.tar.gz \
  https://example.com/checksums.txt ../etc/passwd "$DEST"
assert_equals 2 "$RC" "rc"
err_has "Invalid release asset name" "error"

test_start "an_empty_asset_name_is_refused"
call download_verified_asset https://example.com/tool.tar.gz \
  https://example.com/checksums.txt "" "$DEST"
assert_equals 2 "$RC" "rc"
err_has "Invalid release asset name" "error"

test_start "a_failing_checksum_fetch_is_reported"
CURL_RC=7 call download_verified_asset https://example.com/tool.tar.gz \
  https://example.com/checksums.txt tool.tar.gz "$DEST"
assert_equals 1 "$RC" "rc"

test_start "an_asset_absent_from_the_manifest_is_refused"
printf '%s  other.tar.gz\n' "$ASSET_SHA" >"$FIX/checksums.txt"
call download_verified_asset https://example.com/tool.tar.gz \
  https://example.com/checksums.txt tool.tar.gz "$DEST"
assert_equals 1 "$RC" "rc"
err_has "absent or ambiguous in checksum manifest" "error"

test_start "an_asset_checksum_mismatch_is_refused"
printf '%s  tool.tar.gz\n' "$GOOD_SHA" >"$FIX/checksums.txt"
call download_verified_asset https://example.com/tool.tar.gz \
  https://example.com/checksums.txt tool.tar.gz "$DEST"
assert_equals 1 "$RC" "rc"
err_has "Release asset checksum mismatch" "error"
assert_file_not_exists "$DEST" "cleaned up"

test_start "an_oversized_asset_is_refused"
printf '%s  tool.tar.gz\n' "$ASSET_SHA" >"$FIX/checksums.txt"
call download_verified_asset https://example.com/tool.tar.gz \
  https://example.com/checksums.txt tool.tar.gz "$DEST" 4
assert_equals 1 "$RC" "rc"
err_has "Release asset size outside allowed range" "error"

test_start "an_oversized_checksum_manifest_is_refused"
# The manifest guard trips at 2 MiB.
dd if=/dev/zero bs=1024 count=2100 2>/dev/null | tr '\0' 'x' >"$FIX/checksums.txt"
call download_verified_asset https://example.com/tool.tar.gz \
  https://example.com/checksums.txt tool.tar.gz "$DEST"
assert_equals 1 "$RC" "rc"
err_has "exceeds the 2 MiB safety limit" "error"

test_start "a_missing_sha256_tool_is_reported"
NOSHA="$DOTFILES_COV_TMPDIR/nosha"
mkdir -p "$NOSHA"
ln -sf "$(command -v bash)" "$NOSHA/bash"
for c in awk cat printf rm wc tr head grep mktemp dirname basename cut sed; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$NOSHA/$c"
done
ln -sf "$BIN/curl" "$NOSHA/curl"
printf '%s  https://example.com/install.sh\n' "$GOOD_SHA" >"$MANIFEST"
PATH="$NOSHA" call download_verified_script https://example.com/install.sh "$DEST"
assert_equals 1 "$RC" "rc"
err_has "SHA-256 verifier not found" "error"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
