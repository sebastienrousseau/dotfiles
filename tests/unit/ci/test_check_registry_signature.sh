#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# tools/ci/check-registry.sh verifies docs/registry.json.minisig against
# security/registry.pub once they exist:
#   - neither committed yet: the check passes and says it skipped;
#   - only one of them: fails (they are committed together);
#   - both: minisign must be present and the signature must verify.
# The key and signature paths are overridden to sandbox files; minisign is a
# stub, or the real binary (on PATH or MINISIGN_BIN) for a throwaway-key
# round-trip.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CHECK="$REPO_ROOT/tools/ci/check-registry.sh"
INDEX="$REPO_ROOT/docs/registry.json"
REAL_MINISIGN="${MINISIGN_BIN:-$(command -v minisign 2>/dev/null || true)}"

if ! command -v jq >/dev/null 2>&1; then
  test_start "jq_available"
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: jq is required by check-registry.sh"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 1
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/check-registry.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
BIN="$WORK/bin"
mkdir -p "$BIN"
OUT="$WORK/out"

# minisign stub: verifies when the signature file reads "good".
cat >"$BIN/minisign" <<'SHIM'
#!/usr/bin/env bash
sig=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -x) sig="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ "$(cat "$sig")" == good ]]
SHIM
chmod +x "$BIN/minisign"

# check <pubkey> <signature> [PATH] — run the CI check; prints its rc.
check() {
  local rc=0
  REGISTRY_PUBKEY="$1" REGISTRY_SIGNATURE="$2" PATH="${3:-$BIN:$PATH}" \
    bash "$CHECK" >"$OUT" 2>&1 || rc=$?
  printf '%s' "$rc"
}

PUB="$WORK/registry.pub"
SIG="$WORK/registry.json.minisig"

test_start "unsigned_repo_skips_the_signature_check"
rc="$(check "$WORK/none.pub" "$WORK/none.minisig")"
assert_equals "0" "$rc" "no key and no signature yet keeps CI green"
assert_file_contains "$OUT" "signature check skipped" "the skip is printed"
assert_file_contains "$OUT" "valid v1 index" "the index is still validated"

test_start "key_without_signature_fails"
printf 'untrusted comment: k\nRWK\n' >"$PUB"
rc="$(check "$PUB" "$WORK/none.minisig")"
assert_equals "1" "$rc" "a committed key requires a signature"
assert_file_contains "$OUT" "must be committed together" "the error says why"

test_start "signature_without_key_fails"
printf 'good' >"$SIG"
rc="$(check "$WORK/none.pub" "$SIG")"
assert_equals "1" "$rc" "a signature without the key is refused too"

test_start "valid_signature_passes"
rc="$(check "$PUB" "$SIG")"
assert_equals "0" "$rc" "a signature that verifies passes"
assert_file_contains "$OUT" "signature verified" "the verification is reported"

test_start "bad_signature_fails"
printf 'bad' >"$SIG"
rc="$(check "$PUB" "$SIG")"
assert_equals "1" "$rc" "a signature that does not verify fails CI"
assert_file_contains "$OUT" "re-sign" "the fix is named"

test_start "missing_minisign_fails"
NOMS="$WORK/nominisign"
mkdir -p "$NOMS"
for tool in bash jq diff sort cat dirname; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$NOMS/$tool"
done
printf 'good' >"$SIG"
rc="$(check "$PUB" "$SIG" "$NOMS")"
assert_equals "127" "$rc" "the check cannot pass without minisign"
assert_file_contains "$OUT" "minisign is required" "the error names minisign"

if [[ -n "$REAL_MINISIGN" && -x "$REAL_MINISIGN" ]]; then
  ln -sf "$REAL_MINISIGN" "$BIN/minisign"
  "$REAL_MINISIGN" -G -W -f -p "$WORK/t.pub" -s "$WORK/t.key" >/dev/null 2>&1
  "$REAL_MINISIGN" -S -s "$WORK/t.key" -m "$INDEX" -x "$WORK/t.minisig" >/dev/null 2>&1

  test_start "real_minisign_verifies_the_committed_index"
  rc="$(check "$WORK/t.pub" "$WORK/t.minisig")"
  assert_equals "0" "$rc" "a throwaway-key signature of docs/registry.json verifies"

  test_start "real_minisign_rejects_another_key"
  "$REAL_MINISIGN" -G -W -f -p "$WORK/o.pub" -s "$WORK/o.key" >/dev/null 2>&1
  rc="$(check "$WORK/o.pub" "$WORK/t.minisig")"
  assert_equals "1" "$rc" "the wrong key fails"
else
  printf '  - skipped real-minisign round-trip: minisign not installed\n'
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
