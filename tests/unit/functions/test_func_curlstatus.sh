#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# curlstatus prints the HTTP status code of a URL. Runs the function with a
# curl stub that records its arguments, so nothing reaches the network.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

FUNC_FILE="$REPO_ROOT/defaults/.chezmoitemplates/functions/curl/curlstatus.sh"
WORK="$(mktemp -d -t dot-curlstatus.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
cat >"$WORK/bin/curl" <<STUB
#!/usr/bin/env bash
printf '%s\n' "\$*" >"$WORK/curl.args"
printf '%s' "\${STUB_CODE:-200}"
STUB
chmod +x "$WORK/bin/curl"

# cs <args…> — run curlstatus; stdout in OUT, stderr in ERR, exit in RC.
cs() {
  RC=0
  OUT="$(PATH="$WORK/bin:$PATH" bash -c 'source "$1"; shift; curlstatus "$@"' _ "$FUNC_FILE" "$@" 2>"$WORK/err")" || RC=$?
  ERR="$(cat "$WORK/err")"
}

test_start "help_prints_usage"
cs --help
assert_equals "0" "$RC" "--help exits 0"
assert_contains "curlstatus: Curl HTTP Status Code Viewer" "$OUT" "the title"
assert_contains "curlstatus [url]" "$OUT" "the usage line"
assert_contains "alias httpcode='curlstatus'" "$OUT" "the aliases"

test_start "a_missing_url_is_an_error"
cs
assert_equals "1" "$RC" "no URL exits 1"
assert_contains "No URL provided" "$ERR" "and says why on stderr"

test_start "the_status_code_is_printed"
STUB_CODE=404 cs https://example.invalid/page
assert_equals "0" "$RC" "a fetch exits 0"
assert_contains "Fetching HTTP status code for URL: https://example.invalid/page" "$OUT" "names the URL"
assert_equals "404" "$(printf '%s\n' "$OUT" | tail -1)" "prints the code curl reported"
assert_contains '-o /dev/null -w %{http_code} https://example.invalid/page' "$(cat "$WORK/curl.args")" \
  "asks curl for the status code only"
assert_contains "--max-time 30" "$(cat "$WORK/curl.args")" "with a time limit"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
