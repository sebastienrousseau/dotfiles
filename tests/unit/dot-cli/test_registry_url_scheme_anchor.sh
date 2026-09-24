#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# The registry URL scheme check in _registry_fetch must be anchored at the
# start of the string: a URL that merely *contains* "https://" or "file://"
# somewhere after a foreign scheme must be refused before any fetch.
# Found by mutation testing (G2: dropping the `^` anchor survived because
# every existing refusal case used a URL with no https:// substring at all).
# Pinned here, for `ftp://x/https://y` and `evil://https://`:
#   - `dot registry list` fails
#   - the refusal names the https:// requirement
#   - curl is never invoked (a recording stub under a sandboxed PATH)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

REGISTRY_SCRIPT="$REPO_ROOT/scripts/dot/commands/registry.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

if ! command -v jq >/dev/null 2>&1; then
  test_start "jq_available"
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: jq is required by dot registry list"
  echo ""
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 1
fi

# curl spy: records argv and fails, so a fetch that slips past the scheme
# check is both visible and never reaches a network.
CURL_LOG="$WORK/curl.log"
cat >"$BIN/curl" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${CURL_SPY_LOG:?}"
exit 1
SHIM
chmod +x "$BIN/curl"
export CURL_SPY_LOG="$CURL_LOG"

# registry.sh runs under `set -euo pipefail`; sourcing it imports those
# options, so relax errexit for the deliberately-failing arms below.
source "$REGISTRY_SCRIPT"
set +e

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
run() {
  local rc=0
  cmd_registry "$@" </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}

# refuse_case <name> <url> — one full refusal contract for <url>.
refuse_case() {
  local name="$1" url="$2" rc
  rm -f "$CURL_LOG"
  rm -rf "$(_registry_cache_dir)"
  export DOTFILES_REGISTRY_URL="$url"

  test_start "${name}_list_fails"
  rc="$(run list)"
  assert_not_equals "0" "$rc" "list must fail for $url"

  test_start "${name}_refusal_names_https"
  assert_file_contains "$ERR" "must use https://" "the refusal explains the requirement"

  test_start "${name}_curl_never_invoked"
  assert_file_not_exists "$CURL_LOG" "no fetch is attempted for $url"
}

refuse_case "embedded_https_after_ftp_scheme" "ftp://x/https://y"
refuse_case "embedded_https_after_evil_scheme" "evil://https://"
refuse_case "embedded_file_after_ftp_scheme" "ftp://x/file:///tmp/index.json"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
