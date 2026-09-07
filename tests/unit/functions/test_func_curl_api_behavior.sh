#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034,SC2016
#
# Behaviour tests for the two HTTP function templates:
#
#   curltime   — timing view: help, the missing-URL guard and the curl
#                invocation itself (format string, silent mode, output
#                discarded).
#   apilatency — latency sampler: help/version, argument validation
#                (missing URL, bad scheme, non-numeric count and
#                interval), the sampling loop and the main dispatcher.
#
# `curl` and `sleep` are PATH shims, so no request ever leaves the
# machine and the loop finishes immediately.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Hand children a copy of the real stderr so their xtrace still reaches
# the coverage runner even though the probes capture output with 2>&1.
exec 21>&2
export BASH_XTRACEFD=21

FUNCS="$REPO_ROOT/defaults/.chezmoitemplates/functions"
CURLTIME="$FUNCS/curl/curltime.sh"
APILATENCY="$FUNCS/api/apilatency.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

LOG="$DOTFILES_COV_TMPDIR/http.log"
: >"$LOG"

SHIMS="$DOTFILES_COV_TMPDIR/http-shims"
mkdir -p "$SHIMS"
cat >"$SHIMS/curl" <<EOF
#!/usr/bin/env bash
printf 'curl %s\n' "\$*" >>"$LOG"
# The -w format is what curltime renders; apilatency asks for
# %{time_total} alone.
echo "0.123"
EOF
cat >"$SHIMS/sleep" <<EOF
#!/usr/bin/env bash
printf 'sleep %s\n' "\$*" >>"$LOG"
EOF
chmod +x "$SHIMS/curl" "$SHIMS/sleep"

_call() { # <function-file> <fn> [args…]
  PATH="$SHIMS:$PATH" "$BASH_BIN" -c 'source "$1"; shift; "$@"' _ "$@" 2>&1
}

# ── curltime ─────────────────────────────────────────────────────────
test_start "curltime_help"
_out="$(_call "$CURLTIME" curltime --help)"
_rc=$?
assert_equals 0 "$_rc" "--help exits 0"
assert_contains "curltime: Curl Timing Viewer" "$_out" "help banner printed"
assert_contains "curltime [url]" "$_out" "usage line printed"

test_start "curltime_requires_a_url"
_out="$(_call "$CURLTIME" curltime)"
_rc=$?
assert_equals 1 "$_rc" "no URL exits 1"
assert_contains "No URL provided" "$_out" "error explains what is missing"

test_start "curltime_asks_curl_for_the_timing_breakdown"
: >"$LOG"
_out="$(_call "$CURLTIME" curltime https://example.test)"
_rc=$?
assert_equals 0 "$_rc" "a URL exits 0"
_args="$(cat "$LOG")"
assert_contains "https://example.test" "$_args" "the URL is passed through"
assert_contains "time_namelookup" "$_args" "DNS timing requested"
assert_contains "time_total" "$_args" "total timing requested"
assert_contains "-o /dev/null" "$_args" "response body discarded"
assert_contains "--connect-timeout 10" "$_args" "connect timeout applied"

# ── apilatency ───────────────────────────────────────────────────────
test_start "apilatency_help_and_version"
_out="$(_call "$APILATENCY" apilatency --help)"
_rc=$?
assert_equals 0 "$_rc" "--help exits 0"
assert_contains "Usage: apilatency URL [COUNT] [INTERVAL]" "$_out" "usage printed"
_out="$(_call "$APILATENCY" apilatency -v)"
assert_equals 0 "$?" "-v exits 0"
assert_contains "apilatency version" "$_out" "version reported"

test_start "apilatency_requires_a_url"
_out="$(_call "$APILATENCY" apilatency)"
_rc=$?
assert_equals 1 "$_rc" "no argument exits 1"
assert_contains "Missing required URL argument" "$_out" "error explains what is missing"
assert_contains "Usage: apilatency" "$_out" "usage is printed alongside the error"

test_start "apilatency_validates_url_count_and_interval"
_out="$(_call "$APILATENCY" apilatency ftp://example.test)"
assert_equals 1 "$?" "a non-http scheme exits 1"
assert_contains "Invalid URL format" "$_out" "scheme requirement explained"

_out="$(_call "$APILATENCY" apilatency https://example.test three)"
assert_equals 1 "$?" "a non-numeric count exits 1"
assert_contains "COUNT must be a positive integer" "$_out" "count requirement explained"

_out="$(_call "$APILATENCY" apilatency https://example.test 2 soon)"
assert_equals 1 "$?" "a non-numeric interval exits 1"
assert_contains "INTERVAL must be a positive number" "$_out" "interval requirement explained"

test_start "apilatency_samples_the_endpoint_count_times"
: >"$LOG"
_out="$(_call "$APILATENCY" apilatency https://example.test 3 0)"
_rc=$?
assert_equals 0 "$_rc" "a sampling run exits 0"
assert_contains "Monitoring API latency for https://example.test" "$_out" "target echoed"
assert_contains "Total Requests: 3" "$_out" "request count echoed"
assert_contains "Time,Response_Time" "$_out" "CSV header printed"
assert_contains "0.123" "$_out" "each sample carries curl's time_total"
assert_contains "Latency monitoring completed." "$_out" "completion line printed"
assert_equals 3 "$(grep -c '^curl ' "$LOG")" "curl called once per request"
assert_equals 3 "$(grep -c '^sleep 0' "$LOG")" "the interval is honoured between requests"

test_start "apilatency_defaults_the_interval_and_accepts_fractions"
: >"$LOG"
_out="$(_call "$APILATENCY" apilatency https://example.test 1 0.5)"
assert_equals 0 "$?" "a fractional interval is accepted"
assert_file_contains "$LOG" "sleep 0.5" "the fractional interval reaches sleep"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
