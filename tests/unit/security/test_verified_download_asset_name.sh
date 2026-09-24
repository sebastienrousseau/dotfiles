#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# download_verified_asset refuses any asset name containing a path
# separator: the name is matched against a checksum manifest and must be
# a bare file name, so a single "/" is already a traversal attempt.
# Found by mutation testing (V5: `*/*` -> `*/*/*` survived because the
# existing refusal case used `../etc/passwd`, which has two slashes).
# Pinned here, for `../x` and `a/b` (exactly one slash each):
#   - rc 2 and "Invalid release asset name" on stderr
#   - curl is never invoked (the sandbox curl is a recording stub)
#   - nothing is written to the destination
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

LIB="$REPO_ROOT/lib/dot/verified-download.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

BIN="$DOTFILES_COV_TMPDIR/bin"
DEST="$DOTFILES_COV_TMPDIR/downloaded"
ERRF="$DOTFILES_COV_TMPDIR/err.txt"
CURL_LOG="$DOTFILES_COV_TMPDIR/curl.log"

# curl spy: records argv and fails; a guard that lets a bad name through
# is observable here without any network access.
cat >"$BIN/curl" <<'STUB'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${CURL_SPY_LOG:?}"
exit 1
STUB
chmod +x "$BIN/curl"
export CURL_SPY_LOG="$CURL_LOG"

# call <fn> <args…> — run one fetcher in a subshell with the lib sourced.
call() {
  (
    source "$LIB"
    "$@"
  ) 2>"$ERRF"
  RC=$?
  return 0
}
err_has() { assert_file_contains "$ERRF" "$1" "${2:-stderr contains $1}"; }

# refuse_case <name> <asset> — one full refusal contract for <asset>.
refuse_case() {
  local name="$1" asset="$2"
  rm -f "$CURL_LOG" "$DEST"
  test_start "$name"
  call download_verified_asset https://example.com/tool.tar.gz \
    https://example.com/checksums.txt "$asset" "$DEST"
  assert_equals 2 "$RC" "rc for asset name '$asset'"
  err_has "Invalid release asset name" "error names the bad asset"
  assert_file_not_exists "$CURL_LOG" "curl is never invoked for '$asset'"
  assert_file_not_exists "$DEST" "nothing written for '$asset'"
}

refuse_case "single_slash_parent_traversal_is_refused" "../x"
refuse_case "single_slash_relative_path_is_refused" "a/b"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
