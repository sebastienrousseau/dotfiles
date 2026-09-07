#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Branch coverage for scripts/qa/scorecard-snapshot.sh: missing
# target, jq absent, Scorecard API unreachable, first-run injection
# after "## Live score", in-place refresh between the markers, and
# --check in sync / stale. `curl` is a shim returning a canned payload
# (or failing), so nothing leaves the machine.
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

SCRIPT_FILE="$REPO_ROOT/scripts/qa/scorecard-snapshot.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

if ! command -v jq >/dev/null 2>&1; then
  echo "jq not available — skipping scorecard branch tests"
  echo "RESULTS:0:0:0"
  exit 0
fi

# curl shim: canned Scorecard payload, or failure when CURL_SHIM_FAIL=1.
_curlbin="$DOTFILES_COV_TMPDIR/curlbin"
mkdir -p "$_curlbin"
cat >"$_curlbin/curl" <<'SHIM'
#!/usr/bin/env bash
[[ "${CURL_SHIM_FAIL:-0}" == "1" ]] && exit 22
printf '%s\n' '{"score":7.5,"date":"2026-09-01","checks":[{"name":"Token-Permissions","score":10,"reason":"top level | ok"},{"name":"Binary-Artifacts","score":4,"reason":"binaries present"}]}'
SHIM
chmod +x "$_curlbin/curl"
export PATH="$_curlbin:$PATH"

_fixture() { # <name> → root with a fresh SCORECARD.md
  local root="$DOTFILES_COV_TMPDIR/fx-$1"
  mkdir -p "$root/docs/security"
  printf '# Scorecard\n\nIntro paragraph.\n\n## Live score\n\n## Findings\n\nNarrative stays.\n' >"$root/docs/security/SCORECARD.md"
  printf '%s\n' "$root"
}

_snap() { # <root> [args]
  local root="$1"
  shift
  REPO_ROOT="$root" "$BASH_BIN" "$SCRIPT_FILE" "$@" 2>&1
}

test_start "missing_target_exits_2"
_root="$DOTFILES_COV_TMPDIR/fx-notarget"
mkdir -p "$_root"
_out="$(_snap "$_root")"
_rc=$?
assert_equals 2 "$_rc" "missing SCORECARD.md exits 2"
assert_contains "target not found: docs/security/SCORECARD.md" "$_out" "target path named"

test_start "missing_jq_exits_2"
_root="$(_fixture nojq)"
_nojq="$DOTFILES_COV_TMPDIR/nojq"
mkdir -p "$_nojq"
ln -sf "$(command -v dirname)" "$_nojq/dirname"
_out="$(REPO_ROOT="$_root" PATH="$_nojq" "$BASH_BIN" "$SCRIPT_FILE" 2>&1)"
_rc=$?
assert_equals 2 "$_rc" "no jq exits 2"
assert_contains "jq required" "$_out" "jq requirement printed"

test_start "api_unreachable_exits_2"
_root="$(_fixture nocurl)"
_out="$(CURL_SHIM_FAIL=1 _snap "$_root")"
_rc=$?
assert_equals 2 "$_rc" "curl failure exits 2"
assert_contains "Scorecard API unreachable" "$_out" "API failure printed"

test_start "first_run_injects_block_after_live_score_heading"
_root="$(_fixture first)"
_out="$(_snap "$_root")"
_rc=$?
assert_equals 0 "$_rc" "first write exits 0"
assert_contains "Refreshed docs/security/SCORECARD.md (aggregate: 7.5 as of 2026-09-01)" "$_out" "refresh summary printed"
_md="$_root/docs/security/SCORECARD.md"
assert_file_contains "$_md" "<!-- BEGIN scorecard-snapshot" "begin marker written"
assert_file_contains "$_md" "Aggregate score **7.5 / 10** at 2026-09-01." "aggregate line written"
assert_file_contains "$_md" "| Binary-Artifacts | 4 | binaries present |" "checks sorted and tabled"
assert_file_contains "$_md" "Narrative stays." "narrative preserved"
_order="$(awk '/^## Live score$/{print "live"} /BEGIN scorecard-snapshot/{print "begin"} /^## Findings$/{print "findings"}' "$_md" | tr '\n' ' ')"
assert_equals "live begin findings " "$_order" "block sits between the two headings"

test_start "check_in_sync_exits_0_and_refresh_replaces_block_in_place"
_out="$(_snap "$_root" --check)"
_rc=$?
assert_equals 0 "$_rc" "in-sync check exits 0"
assert_contains "snapshot is in sync (aggregate: 7.5)" "$_out" "in-sync message printed"
_out="$(_snap "$_root")"
assert_equals 0 $? "second refresh exits 0"
assert_equals 1 "$(/usr/bin/grep -c 'BEGIN scorecard-snapshot' "$_md")" "markers not duplicated on refresh"

test_start "check_stale_exits_1_with_diff"
sed -i.bak 's/Aggregate score \*\*7\.5/Aggregate score **1.0/' "$_md"
rm -f "$_md.bak"
_out="$(_snap "$_root" --check)"
_rc=$?
assert_equals 1 "$_rc" "stale check exits 1"
assert_contains "snapshot is stale (live score: 7.5)" "$_out" "stale message printed"
assert_contains "-Aggregate score **1.0" "$_out" "unified diff shows the stale line"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
