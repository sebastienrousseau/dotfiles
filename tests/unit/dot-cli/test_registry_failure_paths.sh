#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016,SC2034
# Failure and refusal paths of scripts/dot/commands/registry.sh — the arms
# test_registry_exhaustive.sh does not reach because they need a hostile or
# degraded environment: a non-HTTPS registry URL, a missing curl or jq, a
# download that fails onto a stale cache, an index that fails validation
# after being fetched, archives that are oversized, empty, or carry
# directory-traversal paths, and a config file that cannot be written.
#
# Everything runs offline: curl is a PATH-shadowed shim that resolves
# file:// by copying, and chezmoi is a recording stub.

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

test_start "script_exists"
assert_file_exists "$REGISTRY_SCRIPT" "scripts/dot/commands/registry.sh must exist"

_pass() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
}
_fail() {
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $1"
}

# curl shim: resolves file:// by copy, refuses everything else. The sandbox
# ships a curl that always succeeds with an empty body, which would make the
# index blank instead of exercising the real fetch path.
cat >"$BIN/curl" <<'SHIM'
#!/usr/bin/env bash
out=""; url=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) out="${2:-}"; shift 2 ;;
    file://*) url="$1"; shift ;;
    *) shift ;;
  esac
done
[[ -n "$url" ]] || exit 1
src="${url#file://}"
[[ -f "$src" ]] || exit 22
if [[ -n "$out" ]]; then cp "$src" "$out"; else cat "$src"; fi
exit 0
SHIM
cat >"$BIN/chezmoi" <<'SHIM'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${DOTFILES_COV_TMPDIR:?}/chezmoi.calls"
exit 0
SHIM
chmod +x "$BIN/curl" "$BIN/chezmoi"

if ! command -v jq >/dev/null 2>&1; then
  test_start "jq_available"
  _fail "jq is required to exercise the registry index paths"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 1
fi

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# ---------------------------------------------------------------------------
# Fixtures: a good archive, a traversal archive, an empty archive, and index
# documents pointing at each.
# ---------------------------------------------------------------------------
GOOD_SRC="$WORK/src/good-module"
mkdir -p "$GOOD_SRC"
printf 'export GOOD=1\n' >"$GOOD_SRC/dot_profile"
GOOD_ARCHIVE="$WORK/good-1.0.0.tar.gz"
tar -czf "$GOOD_ARCHIVE" -C "$WORK/src" good-module
GOOD_SHA="$(sha256_of "$GOOD_ARCHIVE")"

TRAVERSAL_DIR="$WORK/traversal"
mkdir -p "$TRAVERSAL_DIR/sub"
printf 'pwned\n' >"$TRAVERSAL_DIR/sub/file"
TRAVERSAL_ARCHIVE="$WORK/traversal-1.0.0.tar.gz"
# The member has to be recorded as "../sub/file". GNU tar strips a leading
# "../" ("Removing leading `../' from member names") unless -P is given, so
# without it this fixture is a perfectly safe archive on Linux and the guard
# under test is never reached. -P keeps the path verbatim on GNU tar and
# bsdtar alike.
tar -Pczf "$TRAVERSAL_ARCHIVE" -C "$TRAVERSAL_DIR/sub" ../sub/file 2>/dev/null
TRAVERSAL_SHA="$(sha256_of "$TRAVERSAL_ARCHIVE")"

EMPTY_DIR="$WORK/empty-module"
mkdir -p "$EMPTY_DIR"
EMPTY_ARCHIVE="$WORK/empty-1.0.0.tar.gz"
tar -czf "$EMPTY_ARCHIVE" -C "$WORK" empty-module
EMPTY_SHA="$(sha256_of "$EMPTY_ARCHIVE")"

# index_with <file> <name> <archive-url> <sha> — a schema-valid index.
index_with() {
  jq -n --arg name "$2" --arg url "$3" --arg sha "$4" '{
    version: 1,
    modules: [{
      name: $name, version: "1.0.0",
      description: "fixture module",
      tags: ["fixture"],
      archive_url: $url, sha256: $sha
    }]
  }' >"$1"
}

GOOD_INDEX="$WORK/good-index.json"
index_with "$GOOD_INDEX" good-module "file://$GOOD_ARCHIVE" "$GOOD_SHA"
TRAVERSAL_INDEX="$WORK/traversal-index.json"
index_with "$TRAVERSAL_INDEX" traversal-module "file://$TRAVERSAL_ARCHIVE" "$TRAVERSAL_SHA"
EMPTY_INDEX="$WORK/empty-index.json"
index_with "$EMPTY_INDEX" empty-module "file://$EMPTY_ARCHIVE" "$EMPTY_SHA"
MISMATCH_INDEX="$WORK/mismatch-index.json"
index_with "$MISMATCH_INDEX" good-module "file://$GOOD_ARCHIVE" \
  "0000000000000000000000000000000000000000000000000000000000000000"
MISSING_ARCHIVE_INDEX="$WORK/missing-archive-index.json"
index_with "$MISSING_ARCHIVE_INDEX" good-module "file://$WORK/nope.tar.gz" "$GOOD_SHA"
# Schema-invalid: version 2 and a malformed sha256.
INVALID_INDEX="$WORK/invalid-index.json"
printf '{"version":2,"modules":[{"name":"x","version":"nope","description":"d","archive_url":"ftp://x","sha256":"short"}]}\n' \
  >"$INVALID_INDEX"

# registry.sh runs under `set -euo pipefail`; sourcing it imports those
# options into this shell, where the deliberately-failing arms below would
# abort the run. Relax errexit for the rest of the file.
source "$REGISTRY_SCRIPT"
set +e

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
# run <args…> — call cmd_registry, capturing stdout in $OUT and stderr in
# $ERR. Stderr is replayed onto fd 2 afterwards because it also carries the
# coverage runner's xtrace records, which must not be swallowed.
run() {
  local rc=0
  cmd_registry "$@" </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}
clear_cache() { rm -rf "$(_registry_cache_dir)"; }

# ===========================================================================
# Registry URL validation
# ===========================================================================
test_start "non_https_registry_url_is_refused_at_fetch"
export DOTFILES_REGISTRY_URL="http://example.com/registry.json"
clear_cache
rc="$(run list)"
assert_not_equals "0" "$rc" "an http:// registry URL must not be fetched"
assert_file_contains "$ERR" "must use https://" "the refusal explains the requirement"

test_start "set_url_rejects_non_https_schemes"
rc="$(run set-url "ftp://example.com/registry.json")"
assert_equals "1" "$rc" "ftp:// is refused"
assert_file_contains "$OUT" "must use https://" "set-url explains the requirement"

test_start "set_url_requires_an_argument"
rc="$(run set-url)"
assert_equals "1" "$rc" "set-url with no URL fails"
assert_file_contains "$OUT" "missing URL" "the error names the missing argument"

test_start "set_url_reports_a_config_it_cannot_write"
# Permission bits are not enough: root ignores them, and CI containers
# routinely run as root. Put a regular file where the config directory has to
# be, so `mkdir -p` fails for every user.
cfg_dir="$(dirname "$(_registry_config_file)")"
rm -rf "$cfg_dir"
mkdir -p "$(dirname "$cfg_dir")"
: >"$cfg_dir"
rc="$(run set-url "file://$GOOD_INDEX")"
rm -f "$cfg_dir"
assert_equals "1" "$rc" "a config path that cannot be created is an error, not a silent no-op"
assert_file_contains "$OUT" "set-url" "the failure is attributed to set-url"

# ===========================================================================
# Fetch failures and the stale-cache fallback
# ===========================================================================
test_start "missing_index_without_cache_is_an_error"
export DOTFILES_REGISTRY_URL="file://$WORK/does-not-exist.json"
clear_cache
rc="$(run list)"
assert_not_equals "0" "$rc" "an unreachable index with no cache fails"
assert_file_contains "$ERR" "could not fetch" "the error names the fetch"

test_start "stale_cache_is_used_when_the_fetch_fails"
# Prime the cache from a good index, age it past the 6h TTL, then make THAT
# URL unfetchable. Same URL throughout: the cache is keyed by URL, so the
# fallback is "the registry you asked for is unreachable, here is the copy we
# have of it" — never another registry's index.
export DOTFILES_REGISTRY_URL="file://$WORK/vanishing.json"
cp "$GOOD_INDEX" "$WORK/vanishing.json"
clear_cache
run list >/dev/null
cache_file="$(_registry_cache_file)"
assert_file_exists "$cache_file" "the index was cached"
touch -t 202001010000 "$cache_file"
rm -f "$WORK/vanishing.json"
rc="$(run list)"
assert_equals "0" "$rc" "a stale cache still serves the listing"
assert_file_contains "$ERR" "using stale cache" "the fallback is announced on stderr"
assert_file_contains "$OUT" "good-module" "the stale index contents are shown"

test_start "a_different_url_does_not_borrow_that_stale_cache"
# The cache above is still on disk and still stale. A different registry URL
# that cannot be fetched must fail rather than serve it — the whole point of
# keying the cache by URL.
export DOTFILES_REGISTRY_URL="file://$WORK/does-not-exist.json"
rc="$(run list)"
assert_not_equals "0" "$rc" "another registry's stale cache is not served"
assert_file_contains "$ERR" "could not fetch" "the unreachable URL is reported"

test_start "corrupt_cache_is_discarded_and_refetched"
export DOTFILES_REGISTRY_URL="file://$GOOD_INDEX"
clear_cache
run list >/dev/null
cache_file="$(_registry_cache_file)"
printf 'not json at all\n' >"$cache_file"
rc="$(run list)"
assert_equals "0" "$rc" "a cache that fails validation is replaced, not served"
assert_file_contains "$OUT" "good-module" "the refetched index is listed"

test_start "index_failing_schema_validation_is_rejected"
export DOTFILES_REGISTRY_URL="file://$INVALID_INDEX"
clear_cache
rc="$(run list)"
assert_not_equals "0" "$rc" "an index that fails the schema is refused"
assert_file_contains "$ERR" "validation" "the error mentions validation"

# ===========================================================================
# Install refusals
# ===========================================================================
export DOTFILES_REGISTRY_URL="file://$GOOD_INDEX"
clear_cache

test_start "install_rejects_an_invalid_module_name"
rc="$(run install "../../etc/passwd")"
assert_equals "1" "$rc" "a traversal-shaped module name is refused"
assert_file_contains "$OUT" "invalid module name" "the refusal names the problem"

test_start "install_reports_a_download_failure"
export DOTFILES_REGISTRY_URL="file://$MISSING_ARCHIVE_INDEX"
clear_cache
rc="$(run install good-module)"
assert_equals "1" "$rc" "a missing archive fails the install"
assert_file_contains "$OUT" "could not download" "the error names the download"

test_start "install_refuses_a_checksum_mismatch"
export DOTFILES_REGISTRY_URL="file://$MISMATCH_INDEX"
clear_cache
rc="$(run install good-module)"
assert_equals "1" "$rc" "a mismatched SHA-256 stops the install"
assert_file_contains "$OUT" "SHA-256 mismatch" "the error names the mismatch"

test_start "the_traversal_fixture_really_contains_a_traversal_path"
# Guards the guard: if tar ever normalises the member away, the refusal test
# below would pass against a harmless archive.
assert_output_matches "\\.\\./sub/file" "tar -tzf '$TRAVERSAL_ARCHIVE'"

test_start "install_refuses_an_archive_with_traversal_paths"
export DOTFILES_REGISTRY_URL="file://$TRAVERSAL_INDEX"
clear_cache
rc="$(run install traversal-module)"
assert_equals "1" "$rc" "a ../ member stops the install"
assert_file_contains "$OUT" "unsafe path" "the error names the unsafe member"

test_start "install_refuses_an_empty_module"
export DOTFILES_REGISTRY_URL="file://$EMPTY_INDEX"
clear_cache
rc="$(run install empty-module)"
assert_equals "1" "$rc" "an archive with no files is refused"
assert_file_contains "$OUT" "empty" "the error says the module is empty"

test_start "install_refuses_an_oversized_archive"
# The 50 MiB guard is checked from the downloaded file's size, so a sparse
# file of that size is enough — no 50 MiB of real data is written.
BIG_ARCHIVE="$WORK/big-1.0.0.tar.gz"
: >"$BIG_ARCHIVE"
if command -v mkfile >/dev/null 2>&1; then
  mkfile -n 51m "$BIG_ARCHIVE" 2>/dev/null
else
  dd if=/dev/zero of="$BIG_ARCHIVE" bs=1 count=0 seek=53477376 2>/dev/null
fi
BIG_SHA="$(sha256_of "$BIG_ARCHIVE")"
BIG_INDEX="$WORK/big-index.json"
index_with "$BIG_INDEX" big-module "file://$BIG_ARCHIVE" "$BIG_SHA"
export DOTFILES_REGISTRY_URL="file://$BIG_INDEX"
clear_cache
rc="$(run install big-module)"
assert_equals "1" "$rc" "an archive over the size limit is refused"
assert_file_contains "$OUT" "50 MiB" "the error quotes the limit"
rm -f "$BIG_ARCHIVE"

# ===========================================================================
# installed / jq / curl availability
# ===========================================================================
test_start "installed_reports_an_empty_module_store"
rm -rf "$(_registry_data_dir)"
rc="$(run installed)"
assert_equals "0" "$rc" "an empty module store is not an error"
assert_file_contains "$OUT" "no modules installed" "the empty store is reported"

test_start "registry_needs_jq"
# Shadow jq with a directory that does not contain it.
NOJQ_BIN="$WORK/nojq-bin"
mkdir -p "$NOJQ_BIN"
for tool in bash sh curl tar awk sed grep cat mkdir rm mv date stat wc find printf; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$NOJQ_BIN/$tool"
done
saved_path="$PATH"
PATH="$NOJQ_BIN"
rc="$(run list)"
PATH="$saved_path"
assert_equals "127" "$rc" "a missing jq is reported as unavailable (127)"
assert_file_contains "$OUT" "jq is required" "the error names jq"

test_start "registry_needs_curl"
NOCURL_BIN="$WORK/nocurl-bin"
mkdir -p "$NOCURL_BIN"
for tool in bash sh jq tar awk sed grep cat mkdir rm mv date stat wc find printf; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$NOCURL_BIN/$tool"
done
export DOTFILES_REGISTRY_URL="file://$GOOD_INDEX"
clear_cache
saved_path="$PATH"
PATH="$NOCURL_BIN"
rc="$(run list)"
PATH="$saved_path"
assert_equals "127" "$rc" "a missing curl is reported as unavailable (127)"
assert_file_contains "$ERR" "curl not installed" "the error names curl"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
