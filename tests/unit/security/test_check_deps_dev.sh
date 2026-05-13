#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for scripts/ci/check-deps-dev.sh — the deps.dev Insights
# API supply-chain validator.
#
# The script's network calls (curl → api.deps.dev) are shimmed to
# return canned fixtures so the test is hermetic and fast.
#
# Regression for: GH-877
# Why: drift in the API-response parser would silently hide advisories
# the scan is supposed to surface — worse than no scan at all.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

SCRIPT="$REPO_ROOT/scripts/ci/check-deps-dev.sh"

# -----------------------------------------------------------------------------
# Structural
# -----------------------------------------------------------------------------

test_start "script_exists"
assert_file_exists "$SCRIPT" "deps.dev checker should exist"

test_start "script_uses_pipefail"
assert_file_contains "$SCRIPT" "set -uo pipefail" "checker must enforce strict mode"

test_start "script_supports_threshold"
assert_file_contains "$SCRIPT" "DEPS_DEV_SEVERITY_THRESHOLD" \
  "checker must read a configurable severity threshold"

test_start "script_supports_exceptions"
assert_file_contains "$SCRIPT" "is_excepted" \
  "checker must check the exceptions file"

test_start "script_supports_sarif_output"
# Use plain fixed-string match (assert_file_contains uses grep -F).
assert_file_contains "$SCRIPT" "SARIF_OUT" \
  "checker must accept SARIF output env var"

# -----------------------------------------------------------------------------
# Behavioural: shim the deps.dev API with canned fixtures.
# -----------------------------------------------------------------------------

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Build a fake repo with one npm dep so the scanner has something to query.
fake_repo="$tmp/fake-repo"
mkdir -p "$fake_repo/.github/workflows" "$fake_repo/docs/security"
cat > "$fake_repo/package.json" <<'JSON'
{
  "name": "fixture",
  "version": "0.0.0",
  "dependencies": {
    "examplepkg": "1.2.3"
  }
}
JSON

# Mock deps.dev server backed by a directory of fixture files.
mirror="$tmp/mirror"
mkdir -p "$mirror"

# Fixture 1: version response with one advisory key.
cat > "$mirror/version_with_advisory.json" <<'JSON'
{
  "versionKey": {"system": "NPM", "name": "examplepkg", "version": "1.2.3"},
  "advisoryKeys": [{"id": "GHSA-xxxx-yyyy-zzzz"}]
}
JSON

# Fixture 2: advisory response with severity HIGH.
cat > "$mirror/advisory_high.json" <<'JSON'
{
  "advisoryKey": {"id": "GHSA-xxxx-yyyy-zzzz"},
  "severity": [{"type": "HIGH", "score": "7.5"}]
}
JSON

# Fixture 3: version response with no advisories.
cat > "$mirror/version_clean.json" <<'JSON'
{
  "versionKey": {"system": "NPM", "name": "examplepkg", "version": "1.2.3"},
  "advisoryKeys": []
}
JSON

# curl shim — routes API paths to the right fixture based on URL shape.
curl_shim="$tmp/curl"
cat > "$curl_shim" <<EOF
#!/usr/bin/env bash
# Capture the URL (last arg by convention).
url=""
for a in "\$@"; do url="\$a"; done
case "\$url" in
  *advisories*) cat "$mirror/\${FIXTURE_ADVISORY:-advisory_high.json}" ;;
  *versions*)   cat "$mirror/\${FIXTURE_VERSION:-version_with_advisory.json}" ;;
  *)            echo "{}" ;;
esac
EOF
chmod +x "$curl_shim"

# 1. Negative test: with an advisory at HIGH severity, scanner must exit non-zero.
test_start "scanner_flags_high_advisory"
set +e
PATH="$tmp:$PATH" \
  REPO_ROOT="$fake_repo" \
  FIXTURE_VERSION="version_with_advisory.json" \
  FIXTURE_ADVISORY="advisory_high.json" \
  bash "$SCRIPT" >"$tmp/out_high.log" 2>&1
rc=$?
set -e
if [[ $rc -ne 0 ]] && grep -q "HIGH" "$tmp/out_high.log"; then
  assert_exit_code 0 "true"
else
  echo "Expected non-zero exit + HIGH in output. rc=$rc, log:" >&2
  cat "$tmp/out_high.log" >&2
  assert_exit_code 0 "false"
fi

# 2. Positive test: with no advisories, scanner exits 0.
test_start "scanner_passes_clean_deps"
set +e
PATH="$tmp:$PATH" \
  REPO_ROOT="$fake_repo" \
  FIXTURE_VERSION="version_clean.json" \
  bash "$SCRIPT" >"$tmp/out_clean.log" 2>&1
rc=$?
set -e
if [[ $rc -eq 0 ]] && grep -qi "clean" "$tmp/out_clean.log"; then
  assert_exit_code 0 "true"
else
  echo "Expected exit 0 + 'clean' in output. rc=$rc, log:" >&2
  cat "$tmp/out_clean.log" >&2
  assert_exit_code 0 "false"
fi

# 3. Exception test: with an exception entry for `NPM:examplepkg`,
#    even a HIGH advisory must NOT fail the scan.
cat > "$fake_repo/docs/security/DEPS_DEV_EXCEPTIONS.md" <<'EOF'
# deps.dev exceptions

`NPM:examplepkg` (expires 2099-12-31): test fixture — keep this entry in place for the unit test.
EOF

test_start "scanner_honors_exception"
set +e
PATH="$tmp:$PATH" \
  REPO_ROOT="$fake_repo" \
  FIXTURE_VERSION="version_with_advisory.json" \
  FIXTURE_ADVISORY="advisory_high.json" \
  bash "$SCRIPT" >"$tmp/out_excepted.log" 2>&1
rc=$?
set -e
if [[ $rc -eq 0 ]] && grep -q "excepted" "$tmp/out_excepted.log"; then
  assert_exit_code 0 "true"
else
  echo "Expected exit 0 + 'excepted' in output. rc=$rc, log:" >&2
  cat "$tmp/out_excepted.log" >&2
  assert_exit_code 0 "false"
fi

# 4. SARIF output: when DEPS_DEV_SARIF_OUT is set, the script must
#    produce a parseable SARIF file on findings.
rm -f "$fake_repo/docs/security/DEPS_DEV_EXCEPTIONS.md"
test_start "scanner_emits_sarif_on_findings"
set +e
PATH="$tmp:$PATH" \
  REPO_ROOT="$fake_repo" \
  FIXTURE_VERSION="version_with_advisory.json" \
  FIXTURE_ADVISORY="advisory_high.json" \
  DEPS_DEV_SARIF_OUT="$tmp/result.sarif" \
  bash "$SCRIPT" >"$tmp/out_sarif.log" 2>&1
rc=$?
set -e
if [[ -s "$tmp/result.sarif" ]] && \
   python3 -c "import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if d.get('version')=='2.1.0' else 1)" \
     "$tmp/result.sarif" 2>/dev/null; then
  assert_exit_code 0 "true"
else
  echo "Expected SARIF file with version 2.1.0. rc=$rc" >&2
  [[ -f "$tmp/result.sarif" ]] && cat "$tmp/result.sarif" >&2
  assert_exit_code 0 "false"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
