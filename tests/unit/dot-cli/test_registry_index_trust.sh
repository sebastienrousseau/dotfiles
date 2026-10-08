#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# Trust in the registry index itself, before any module is looked at.
#
# The archive's sha256 is only as good as the index that pins it, and the
# index used to be accepted unsigned from the same place as the archives.
# Pinned here:
#   - an https index is used only with a valid minisign signature
#     (<url>.minisig) against the registry public key; a missing or bad
#     signature, a missing key or a missing minisign refuses it;
#   - a file:// index may skip verification only with
#     DOTFILES_REGISTRY_UNSIGNED=1, which warns; https never skips;
#   - an https index may not point a module at a file:// archive;
#   - a failed fetch falls back to a cached index only while it is younger
#     than seven days;
#   - an index whose `updated` is older than the last accepted one is
#     refused (rollback), even after the cache is cleared;
#   - control characters in registry text never reach the terminal.
#
# Offline: curl resolves https://registry.test/<p> from a sandbox directory.
# minisign is a stub that accepts exactly the signatures sign_stub writes,
# so every path runs in CI without minisign; when a real minisign is
# available (on PATH or MINISIGN_BIN), a throwaway key round-trip runs too.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

REGISTRY_SCRIPT="$REPO_ROOT/scripts/dot/commands/registry.sh"
REAL_MINISIGN="${MINISIGN_BIN:-$(command -v minisign 2>/dev/null || true)}"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
WWW="$WORK/www"
CURL_LOG="$WORK/curl.log"
mkdir -p "$WWW"
export REGISTRY_TEST_WWW="$WWW" REGISTRY_TEST_CURL_LOG="$CURL_LOG"
export NO_COLOR=1

if ! command -v jq >/dev/null 2>&1; then
  test_start "jq_available"
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: jq is required by dot registry"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 1
fi

cat >"$BIN/curl" <<'SHIM'
#!/usr/bin/env bash
out=""; url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out="${2:-}"; shift 2 ;;
    file://* | https://*) url="$1"; shift ;;
    *) shift ;;
  esac
done
printf '%s\n' "$url" >>"${REGISTRY_TEST_CURL_LOG:?}"
case "$url" in
  https://registry.test/*) src="${REGISTRY_TEST_WWW:?}/${url#https://registry.test/}" ;;
  file://*) src="${url#file://}" ;;
  *) exit 6 ;;
esac
[[ -f "$src" ]] || exit 22
if [[ -n "$out" ]]; then cp "$src" "$out"; else cat "$src"; fi
SHIM

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}
export -f sha256_of

# minisign stub: -V accepts a signature file that reads
# "stub:<sha256 of message>:<sha256 of public key>", nothing else.
cat >"$BIN/minisign" <<'SHIM'
#!/usr/bin/env bash
mode=""; msg=""; sig=""; pub=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -V) mode=verify; shift ;;
    -m) msg="$2"; shift 2 ;;
    -x) sig="$2"; shift 2 ;;
    -p) pub="$2"; shift 2 ;;
    *) shift ;;
  esac
done
[[ "$mode" == verify ]] || exit 2
[[ -z "$sig" ]] && sig="$msg.minisig"
want="stub:$(sha256_of "$msg"):$(sha256_of "$pub")"
[[ "$(cat "$sig" 2>/dev/null)" == "$want" ]]
SHIM
chmod +x "$BIN/curl" "$BIN/minisign"

PUBKEY="$WORK/registry.pub"
printf 'untrusted comment: stub key\nRWSTUBKEY\n' >"$PUBKEY"
export DOTFILES_REGISTRY_PUBKEY="$PUBKEY"

# sign_stub <file> — write <file>.minisig the stub accepts.
sign_stub() {
  printf 'stub:%s:%s' "$(sha256_of "$1")" "$(sha256_of "$PUBKEY")" >"$1.minisig"
}

# A real, plain module archive the indexes point at.
mkdir -p "$WORK/src/plain"
printf 'export PLAIN=1\n' >"$WORK/src/plain/dot_profile"
tar -czf "$WWW/plain-1.0.0.tar.gz" -C "$WORK/src" plain
PLAIN_SHA="$(sha256_of "$WWW/plain-1.0.0.tar.gz")"

# write_index <file> <updated|""> [archive_url] [description]
write_index() {
  local out="$1" updated="$2" url="${3:-https://registry.test/plain-1.0.0.tar.gz}"
  local desc="${4:-plain fixture}"
  jq -n --arg updated "$updated" --arg url "$url" --arg sha "$PLAIN_SHA" --arg desc "$desc" '
    {version: 1}
    + (if $updated == "" then {} else {updated: $updated} end)
    + {modules: [{name: "plain", version: "1.0.0", description: $desc,
        tags: ["fixture"], archive_url: $url, sha256: $sha}]}' >"$out"
}

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
reset_state() {
  rm -rf "$(_registry_cache_dir)" "$(_registry_state_dir)" "$CURL_LOG"
  unset DOTFILES_REGISTRY_UNSIGNED
}
https_url="https://registry.test/registry.json"

# ===========================================================================
# 3.2 Signed index
# ===========================================================================
reset_state
write_index "$WWW/registry.json" "2026-05-02T00:00:00Z"
sign_stub "$WWW/registry.json"
export DOTFILES_REGISTRY_URL="$https_url"

test_start "signed_https_index_is_accepted"
rc="$(run list)"
assert_equals "0" "$rc" "a correctly signed index is listed"
assert_file_contains "$OUT" "plain" "the module is shown"
assert_file_contains "$CURL_LOG" "$https_url.minisig" "the signature is fetched next to the index"

test_start "signed_https_index_installs"
rc="$(run install plain)"
assert_equals "0" "$rc" "a module from a signed index previews"

test_start "unsigned_https_index_is_refused"
reset_state
rm -f "$WWW/registry.json.minisig"
rc="$(run list)"
assert_not_equals "0" "$rc" "an https index without a signature is refused"
assert_file_contains "$ERR" "signature missing" "the refusal says the signature is missing"
assert_file_not_exists "$(_registry_cache_file)" "the refused index is not cached"

test_start "unsigned_override_does_not_apply_to_https"
reset_state
export DOTFILES_REGISTRY_UNSIGNED=1
rc="$(run list)"
assert_not_equals "0" "$rc" "DOTFILES_REGISTRY_UNSIGNED never skips https verification"
assert_file_contains "$ERR" "signature missing" "the signature is still required"
unset DOTFILES_REGISTRY_UNSIGNED

test_start "tampered_https_index_is_refused"
reset_state
sign_stub "$WWW/registry.json"
write_index "$WWW/registry.json" "2026-05-02T00:00:00Z" "" "tampered after signing"
rc="$(run list)"
assert_not_equals "0" "$rc" "an index that does not match its signature is refused"
assert_file_contains "$ERR" "verification FAILED" "the refusal names the failed verification"
assert_file_not_exists "$(_registry_cache_file)" "the tampered index is not cached"

test_start "missing_public_key_refuses"
reset_state
write_index "$WWW/registry.json" "2026-05-02T00:00:00Z"
sign_stub "$WWW/registry.json"
rc="$(DOTFILES_REGISTRY_PUBKEY="$WORK/no-such.pub" run list)"
assert_not_equals "0" "$rc" "no public key means no trust"
assert_file_contains "$ERR" "no registry public key" "the refusal names the missing key"

test_start "default_public_key_is_the_committed_one"
assert_equals "$REPO_ROOT/security/registry.pub" "$(DOTFILES_REGISTRY_PUBKEY='' _registry_pubkey_file)" \
  "the default key is security/registry.pub in the checkout"

test_start "missing_minisign_refuses"
reset_state
NOMS_BIN="$WORK/nominisign-bin"
mkdir -p "$NOMS_BIN"
for tool in bash sh jq curl tar awk sed grep cat mkdir rm mv cp date stat wc find printf mktemp dirname tr sha256sum shasum cksum head; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$NOMS_BIN/$tool"
done
saved_path="$PATH"
PATH="$NOMS_BIN"
rc="$(run list)"
PATH="$saved_path"
assert_equals "127" "$rc" "a missing minisign is reported as unavailable (127)"
assert_file_contains "$ERR" "minisign is required" "the error names minisign"

test_start "file_index_without_signature_is_refused_by_default"
reset_state
cp "$WWW/registry.json" "$WORK/local.json"
export DOTFILES_REGISTRY_URL="file://$WORK/local.json"
rc="$(run list)"
assert_not_equals "0" "$rc" "a file:// index is not trusted silently"
assert_file_contains "$ERR" "signature missing" "the refusal says why"

test_start "file_index_with_signature_is_accepted"
reset_state
sign_stub "$WORK/local.json"
rc="$(run list)"
assert_equals "0" "$rc" "a signed file:// index is verified and used"
assert_file_not_contains_warn=0
grep -q "NOT verified" "$ERR" && assert_file_not_contains_warn=1
assert_equals "0" "$assert_file_not_contains_warn" "a verified index prints no unsigned warning"

test_start "file_index_unsigned_override_warns"
reset_state
rm -f "$WORK/local.json.minisig"
export DOTFILES_REGISTRY_UNSIGNED=1
rc="$(run list)"
assert_equals "0" "$rc" "DOTFILES_REGISTRY_UNSIGNED=1 allows a local file:// index"
assert_file_contains "$ERR" "NOT verified" "the skip is announced"
unset DOTFILES_REGISTRY_UNSIGNED

test_start "unsigned_override_must_be_exactly_1"
reset_state
export DOTFILES_REGISTRY_UNSIGNED=yes
rc="$(run list)"
assert_not_equals "0" "$rc" "only the documented value skips verification"
unset DOTFILES_REGISTRY_UNSIGNED

# ===========================================================================
# 3.3 https archives, stale cache, rollback
# ===========================================================================
test_start "https_index_cannot_point_at_a_file_archive"
reset_state
export DOTFILES_REGISTRY_URL="$https_url"
write_index "$WWW/registry.json" "2026-05-02T00:00:00Z" "file:///dev/zero"
sign_stub "$WWW/registry.json"
rc="$(run install plain)"
assert_not_equals "0" "$rc" "a remote index pointing at file:///dev/zero is refused"
assert_file_contains "$ERR" "validation" "the refusal is the index validation"
dz=0
grep -q "file:///dev/zero" "$CURL_LOG" && dz=1
assert_equals "0" "$dz" "the file:// archive is never requested"

test_start "file_index_may_point_at_a_file_archive"
reset_state
write_index "$WORK/local.json" "" "file://$WWW/plain-1.0.0.tar.gz"
export DOTFILES_REGISTRY_URL="file://$WORK/local.json" DOTFILES_REGISTRY_UNSIGNED=1
rc="$(run install plain)"
assert_equals "0" "$rc" "local development indexes keep file:// archives"
unset DOTFILES_REGISTRY_UNSIGNED

# age_file <file> <seconds ago>
age_file() {
  local when
  when=$(($(date +%s) - $2))
  touch -t "$(date -r "$when" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$when" +%Y%m%d%H%M.%S)" "$1"
}

test_start "recent_cache_serves_a_failed_fetch"
reset_state
export DOTFILES_REGISTRY_URL="$https_url"
write_index "$WWW/registry.json" "2026-05-02T00:00:00Z"
sign_stub "$WWW/registry.json"
run list >/dev/null
age_file "$(_registry_cache_file)" $((6 * 86400))
mv "$WWW/registry.json" "$WWW/registry.json.away"
rc="$(run list)"
assert_equals "0" "$rc" "a six-day-old cache is used when the fetch fails"
assert_file_contains "$ERR" "using stale cache" "the fallback is announced"

test_start "old_cache_is_refused"
age_file "$(_registry_cache_file)" $((7 * 86400 + 60))
rc="$(run list)"
assert_not_equals "0" "$rc" "a cache older than seven days is not used"
assert_file_contains "$ERR" "older than 7 days" "the refusal gives the limit"
mv "$WWW/registry.json.away" "$WWW/registry.json"

test_start "older_updated_is_refused_as_rollback"
reset_state
write_index "$WWW/registry.json" "2026-05-02T00:00:00Z"
sign_stub "$WWW/registry.json"
run list >/dev/null
rm -rf "$(_registry_cache_dir)"
write_index "$WWW/registry.json" "2026-05-01T23:59:59Z"
sign_stub "$WWW/registry.json"
rc="$(run list)"
assert_not_equals "0" "$rc" "an index older than the last accepted one is refused, cache or not"
assert_file_contains "$ERR" "rollback" "the refusal names the rollback"
assert_file_not_exists "$(_registry_cache_file)" "the rolled-back index is not cached"

test_start "same_updated_is_accepted"
write_index "$WWW/registry.json" "2026-05-02T00:00:00Z"
sign_stub "$WWW/registry.json"
rc="$(run list)"
assert_equals "0" "$rc" "re-serving the same index is fine"

test_start "newer_updated_is_accepted_and_raises_the_floor"
rm -rf "$(_registry_cache_dir)"
write_index "$WWW/registry.json" "2026-05-03T00:00:00Z"
sign_stub "$WWW/registry.json"
rc="$(run list)"
assert_equals "0" "$rc" "a newer index is accepted"
rm -rf "$(_registry_cache_dir)"
write_index "$WWW/registry.json" "2026-05-02T00:00:00Z"
sign_stub "$WWW/registry.json"
rc="$(run list)"
assert_not_equals "0" "$rc" "the previously accepted one is now a rollback"

test_start "dropping_updated_after_one_was_accepted_is_refused"
rm -rf "$(_registry_cache_dir)"
write_index "$WWW/registry.json" ""
sign_stub "$WWW/registry.json"
rc="$(run list)"
assert_not_equals "0" "$rc" "an index without updated cannot reset the floor"

test_start "malformed_updated_fails_validation"
reset_state
write_index "$WWW/registry.json" "yesterday"
sign_stub "$WWW/registry.json"
rc="$(run list)"
assert_not_equals "0" "$rc" "updated must be an RFC 3339 UTC timestamp"
assert_file_contains "$ERR" "validation" "it is a validation failure"

# ===========================================================================
# 3.4 Control characters in registry text
# ===========================================================================
ESC=$'\e'
test_start "control_characters_are_stripped_from_output"
reset_state
jq -n --arg sha "$PLAIN_SHA" '{
  version: 1,
  updated: "2026-06-01T00:00:00Z",
  modules: [{name: "plain", version: "1.0.0",
    description: "evil \u001b]52;c;cHduZWQ=\u0007 \u009b31m ‮right-to-left",
    repo: "https://example.com/\u001b[2J",
    maintainer: "m\u001b[31m",
    tags: ["t\u001b[1m", "fixture"],
    "x\u001bkey": "v",
    archive_url: "https://registry.test/plain-1.0.0.tar.gz", sha256: $sha}]
}' >"$WWW/registry.json"
sign_stub "$WWW/registry.json"
for sub in "list" "search evil" "search fixture" "info plain"; do
  # shellcheck disable=SC2086
  rc="$(run $sub)"
  assert_equals "0" "$rc" "$sub succeeds"
  esc_count="$(grep -c "$ESC" "$OUT")"
  assert_equals "0" "$esc_count" "$sub prints no ESC byte"
done
assert_file_contains "$OUT" "?]52;c;" "the payload is shown defanged"
c1_count="$(grep -c $'\xc2\x9b' "$OUT")"
assert_equals "0" "$c1_count" "info prints no C1 CSI"
bidi_count="$(grep -c $'\xe2\x80\xae' "$OUT")"
assert_equals "0" "$bidi_count" "info prints no bidi override"

test_start "installed_listing_strips_control_characters"
rc="$(run install plain --yes)"
assert_equals "0" "$rc" "the module installs"
rc="$(run installed)"
assert_equals "0" "$rc" "installed lists it"
assert_equals "0" "$(grep -c "$ESC" "$OUT")" "installed prints no ESC byte"

# ===========================================================================
# Real minisign round-trip with a throwaway key (when available).
# ===========================================================================
if [[ -n "$REAL_MINISIGN" && -x "$REAL_MINISIGN" ]]; then
  ln -sf "$REAL_MINISIGN" "$BIN/minisign"
  KEYDIR="$WORK/throwaway-key"
  mkdir -p "$KEYDIR"
  "$REAL_MINISIGN" -G -W -f -p "$KEYDIR/test.pub" -s "$KEYDIR/test.key" >/dev/null 2>&1
  "$REAL_MINISIGN" -G -W -f -p "$KEYDIR/other.pub" -s "$KEYDIR/other.key" >/dev/null 2>&1
  export DOTFILES_REGISTRY_PUBKEY="$KEYDIR/test.pub"

  reset_state
  write_index "$WWW/registry.json" "2026-07-01T00:00:00Z"
  "$REAL_MINISIGN" -S -s "$KEYDIR/test.key" -m "$WWW/registry.json" >/dev/null 2>&1

  test_start "real_minisign_accepts_a_valid_signature"
  rc="$(run list)"
  assert_equals "0" "$rc" "a real signature from the trusted key is accepted"

  test_start "real_minisign_refuses_a_tampered_index"
  reset_state
  sed -i.bak 's/plain fixture/plain fixturE/' "$WWW/registry.json"
  rc="$(run list)"
  assert_not_equals "0" "$rc" "one changed byte breaks the signature"
  assert_file_contains "$ERR" "verification FAILED" "the failure is reported"

  test_start "real_minisign_refuses_another_key"
  reset_state
  write_index "$WWW/registry.json" "2026-07-01T00:00:00Z"
  "$REAL_MINISIGN" -S -s "$KEYDIR/other.key" -m "$WWW/registry.json" >/dev/null 2>&1
  rc="$(run list)"
  assert_not_equals "0" "$rc" "a signature from an untrusted key is refused"
else
  printf '  - skipped real-minisign round-trip: minisign not installed\n'
fi

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
