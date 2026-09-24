#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC2034
# End-to-end coverage for scripts/dot/commands/registry.sh in one fast,
# self-contained sandbox: every subcommand, the cache-key hasher fallbacks,
# cache invalidation and stale-cache reuse, the install pipeline (preview,
# apply, and each refusal), and the set-url write failures. curl resolves
# file:// by copying, chezmoi records its calls; no network, and every
# write lands in the mktemp HOME/XDG tree.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$REPO_ROOT/tests/framework/assertions.sh"

REGISTRY_SCRIPT="$REPO_ROOT/scripts/dot/commands/registry.sh"
REAL_BASH="${BASH:-$(command -v bash)}"

if ! command -v jq >/dev/null 2>&1; then
  test_start "jq_available"
  echo "  jq not installed — skipping registry coverage"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/registry-cov.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
export HOME="$WORK/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share" XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME" "$XDG_DATA_HOME" "$XDG_STATE_HOME"
unset DOTFILES_REGISTRY_URL
export DOTFILES_NO_TUI=1 NO_COLOR=1

BIN="$WORK/bin"
mkdir -p "$BIN"
CALLS="$WORK/calls"
: >"$CALLS"
cat >"$BIN/curl" <<EOF
#!$REAL_BASH
out=""; url=""
while [[ \$# -gt 0 ]]; do
  case "\$1" in
    -o) out="\$2"; shift 2 ;;
    file://* | https://local.test/*) url="\$1"; shift ;;
    *) shift ;;
  esac
done
src="\${url#file://}"
src="\${src#https://local.test}"
[[ -n "\$url" && -f "\$src" ]] || exit 22
cp "\$src" "\$out"
EOF
cat >"$BIN/chezmoi" <<EOF
#!$REAL_BASH
printf 'chezmoi %s\n' "\$*" >>"$CALLS"
EOF
chmod +x "$BIN"/*
export PATH="$BIN:$PATH"

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

# Fixtures ------------------------------------------------------------------
F="$WORK/fx"
mkdir -p "$F/src/good" "$F/multi/a" "$F/multi/b" "$F/empty/emptymod" "$F/lnk/mod"
printf 'export GOOD=1\n' >"$F/src/good/dot_profile"
tar -czf "$F/good.tgz" -C "$F/src" good
printf 'a\n' >"$F/multi/a/x"
printf 'b\n' >"$F/multi/b/y"
tar -czf "$F/multi.tgz" -C "$F/multi" a b
tar -czf "$F/empty.tgz" -C "$F/empty" emptymod
printf 't\n' >"$F/lnk/mod/target"
ln -s target "$F/lnk/mod/link"
tar -czf "$F/link.tgz" -C "$F/lnk" mod
mkdir -p "$F/abs"
printf 'x\n' >"$F/abs/f"
tar -Pczf "$F/abs.tgz" "$F/abs/f" 2>/dev/null

# index <file> <name> <archive> [sha] — schema-valid single-module index.
index() {
  local sha="${4:-$(sha256_of "$3")}"
  jq -n --arg n "$2" --arg u "file://$3" --arg s "$sha" '{version:1, modules:[
    {name:$n, version:"1.2.3", description:"fixture \($n)", tags:["Fixture","demo"],
     archive_url:$u, sha256:$s}]}' >"$1"
}
index "$F/good.json" good "$F/good.tgz"
index "$F/multi.json" multi "$F/multi.tgz"
index "$F/empty.json" emptymod "$F/empty.tgz"
index "$F/link.json" linkmod "$F/link.tgz"
index "$F/abs.json" absmod "$F/abs.tgz"
index "$F/bad-sha.json" good "$F/good.tgz" "$(printf '%064d' 0)"
index "$F/no-archive.json" good "$F/missing.tgz" "$(printf '%064d' 0)"
printf '{"version":1,"modules":[]}\n' >"$F/none.json"
printf '{"version":2,"modules":"nope"}\n' >"$F/invalid.json"

# shellcheck source=../../../scripts/dot/commands/registry.sh
source "$REGISTRY_SCRIPT"
set +e

OUT="$WORK/out"
run() {
  local rc=0
  cmd_registry "$@" </dev/null >"$OUT" 2>&1 || rc=$?
  printf '%s' "$rc"
}
use() {
  export DOTFILES_REGISTRY_URL="file://$1"
  rm -rf "$(_registry_cache_dir)"
}

# ---------------------------------------------------------------------------
test_start "url_resolution_and_help"
unset DOTFILES_REGISTRY_URL
assert_equals "$(_registry_default_url)" "$(cmd_registry url)" "default URL"
mkdir -p "$XDG_CONFIG_HOME/dotfiles"
printf 'other = 1\n' >"$XDG_CONFIG_HOME/dotfiles/registry.toml"
assert_equals "$(_registry_default_url)" "$(cmd_registry url)" "config without url falls back"
rc="$(run set-url "file://$F/good.json")"
assert_equals "0" "$rc" "set-url succeeds"
assert_equals "file://$F/good.json" "$(cmd_registry url)" "config URL is used"
rc="$(run help)"
assert_file_contains "$OUT" "Usage: dot registry" "help text"
rc="$(run set-url)"
assert_equals "1" "$rc" "set-url needs a URL"
rc="$(run set-url "http://insecure.test/r.json")"
assert_equals "1" "$rc" "set-url refuses http"
assert_file_contains "$OUT" "must use https://" "scheme explained"
rc="$(run bogus)"
assert_equals "1" "$rc" "unknown subcommand fails"
assert_file_contains "$OUT" "dot registry --help" "hint printed"

test_start "set_url_write_failures"
cat >"$BIN/mv" <<EOF
#!$REAL_BASH
exit 1
EOF
chmod +x "$BIN/mv"
rc="$(run set-url "https://example.test/r.json")"
rm -f "$BIN/mv"
assert_equals "1" "$rc" "failed commit is an error"
assert_file_contains "$OUT" "failed to commit" "commit failure reported"
cat >"$BIN/mktemp" <<EOF
#!$REAL_BASH
echo "$WORK/no/such/dir/tmp"
EOF
chmod +x "$BIN/mktemp"
rc="$(run set-url "https://example.test/r.json")"
rm -f "$BIN/mktemp"
assert_equals "1" "$rc" "failed write is an error"
assert_file_contains "$OUT" "failed to write" "write failure reported"
rm -f "$XDG_CONFIG_HOME/dotfiles/registry.toml"

test_start "cache_key_hasher_fallbacks"
k1="$(_registry_cache_key "https://a")"
assert_equals "32" "${#k1}" "default hasher gives 32 chars"
H="$WORK/hash"
mkdir -p "$H/sha" "$H/ck"
for t in awk sha256sum; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$H/sha/$t"
done
if [[ ! -e "$H/sha/sha256sum" ]]; then
  printf '#!%s\n"%s" -a 256\n' "$REAL_BASH" "$(command -v shasum)" >"$H/sha/sha256sum"
  chmod +x "$H/sha/sha256sum"
fi
ln -sf "$(command -v awk)" "$H/ck/awk"
ln -sf "$(command -v cksum)" "$H/ck/cksum"
k2="$(PATH="$H/sha" _registry_cache_key "https://a")"
assert_equals "$k1" "$k2" "sha256sum path matches shasum digest"
k3="$(PATH="$H/ck" _registry_cache_key "https://a")"
assert_not_empty "$k3" "cksum fallback yields a key"
assert_output_contains "-" "printf '%s' '$k3'"

test_start "list_search_info_installed"
use "$F/good.json"
rc="$(run list)"
assert_equals "0" "$rc" "list ok"
assert_file_contains "$OUT" "good" "module listed"
rc="$(run list)"
assert_equals "0" "$rc" "list from fresh cache ok"
rc="$(run search demo)"
assert_equals "0" "$rc" "search by tag ok"
assert_file_contains "$OUT" "v1.2.3" "search row"
rc="$(run search)"
assert_equals "1" "$rc" "search needs a query"
rc="$(run info good)"
assert_equals "0" "$rc" "info ok"
assert_file_contains "$OUT" "Fixture, demo" "array joined"
rc="$(run info nope)"
assert_equals "1" "$rc" "info unknown module"
rc="$(run info)"
assert_equals "1" "$rc" "info needs a name"
rc="$(run installed)"
assert_file_contains "$OUT" "no modules installed" "nothing installed"
use "$F/none.json"
rc="$(run list)"
assert_equals "0" "$rc" "empty registry ok"
assert_file_contains "$OUT" "no modules published yet" "empty registry message"

test_start "fetch_cache_invalid_stale_and_bad_index"
use "$F/good.json"
cf="$(_registry_cache_file)"
mkdir -p "$(dirname "$cf")"
printf 'garbage\n' >"$cf"
rc="$(run list)"
assert_equals "0" "$rc" "invalid cache is discarded and refetched"
assert_equals "good" "$(jq -r '.modules[0].name' "$cf")" "cache refreshed"
touch -t 200001010000 "$cf"
export DOTFILES_REGISTRY_URL="file://$F/absent.json"
cp "$F/good.json" "$(_registry_cache_file)"
touch -t 200001010000 "$(_registry_cache_file)"
rc="$(run list)"
assert_equals "0" "$rc" "stale cache used when fetch fails"
assert_file_contains "$OUT" "using stale cache" "stale warning"
export DOTFILES_REGISTRY_URL="http://insecure.test/r.json"
rc="$(run list)"
assert_equals "1" "$rc" "http registry refused at fetch"
use "$F/absent.json"
rc="$(run list)"
assert_equals "1" "$rc" "unreachable index without cache fails"
assert_file_contains "$OUT" "could not fetch" "fetch failure reported"
use "$F/invalid.json"
rc="$(run list)"
assert_equals "1" "$rc" "invalid fetched index rejected"
assert_file_contains "$OUT" "failed schema and integrity validation" "validation error"

test_start "tool_requirements"
NJ="$WORK/nojq"
mkdir -p "$NJ"
for t in mkdir date stat awk mktemp rm mv cksum; do
  p="$(command -v "$t" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$NJ/$t"
done
# `hash -r` first: bash 3.2 (macOS /bin/bash, and `bash` on the macOS
# runners) answers `command -v jq` from its command hash even under a
# temporary PATH, so jq run by the earlier cases still "existed" here and
# the missing-tool path was never taken.
hash -r
out="$(PATH="$NJ" cmd_registry list 2>&1)"
assert_contains "jq is required" "$out" "missing jq reported"
use "$F/good.json"
ln -sf "$(command -v jq)" "$NJ/jq"
hash -r
out="$(PATH="$NJ" cmd_registry list 2>&1)"
assert_contains "curl not installed" "$out" "missing curl reported"

test_start "install_preview_and_apply"
use "$F/good.json"
: >"$CALLS"
rc="$(run install good)"
assert_equals "0" "$rc" "preview ok"
assert_file_contains "$OUT" "Preview only" "preview message"
assert_file_contains "$CALLS" "--dry-run" "chezmoi dry-run"
rc="$(run install good --yes)"
assert_equals "0" "$rc" "apply ok"
assert_file_exists "$XDG_DATA_HOME/dotfiles/modules/good/installed.json" "installed.json written"
assert_file_exists "$XDG_DATA_HOME/dotfiles/modules/good/1.2.3/dot_profile" "single root unwrapped"
rc="$(run installed)"
assert_file_contains "$OUT" "v1.2.3" "installed listing"
rc="$(run install good -n)"
assert_equals "0" "$rc" "-n preview ok"
index "$F/https.json" good "$F/good.tgz"
jq '.modules[0].archive_url = "https://local.test'"$F"'/good.tgz"' "$F/https.json" >"$F/https2.json"
export DOTFILES_REGISTRY_URL="https://local.test$F/https2.json"
rm -rf "$(_registry_cache_dir)"
rc="$(run install good)"
assert_equals "0" "$rc" "https index and archive fetched"
use "$F/multi.json"
rc="$(run install multi -y)"
assert_equals "0" "$rc" "multi-root archive applies"
assert_file_exists "$XDG_DATA_HOME/dotfiles/modules/multi/1.2.3/a/x" "multi root kept"

test_start "install_refusals"
rc="$(run install)"
assert_equals "1" "$rc" "install needs a name"
rc="$(run install good --weird)"
assert_equals "2" "$rc" "unknown option"
rc="$(run install 'Bad_Name')"
assert_equals "1" "$rc" "invalid name"
use "$F/good.json"
rc="$(run install ghost)"
assert_equals "1" "$rc" "module not found"
use "$F/no-archive.json"
rc="$(run install good)"
assert_file_contains "$OUT" "could not download" "download failure"
use "$F/bad-sha.json"
rc="$(run install good)"
assert_file_contains "$OUT" "SHA-256 mismatch" "sha mismatch"
use "$F/empty.json"
rc="$(run install emptymod)"
assert_file_contains "$OUT" "module archive is empty" "empty archive"
use "$F/link.json"
rc="$(run install linkmod)"
assert_file_contains "$OUT" "links are forbidden" "link refused"
use "$F/abs.json"
rc="$(run install absmod)"
assert_equals "1" "$rc" "absolute path refused"
assert_file_contains "$OUT" "unsafe path" "unsafe path reported"
use "$F/good.json"
cat >"$BIN/wc" <<EOF
#!$REAL_BASH
echo 99999999
EOF
chmod +x "$BIN/wc"
rc="$(run install good)"
rm -f "$BIN/wc"
assert_file_contains "$OUT" "50 MiB safety limit" "oversized archive"
rc="$(PATH="$NJ" run install good)"
assert_not_equals "0" "$rc" "install without curl fails"
out="$(
  _registry_fetch() { printf '%s\n' "$F/invalid.json"; }
  cmd_registry install good 2>&1
)"
assert_contains "index failed schema validation" "$out" "install revalidates the index"
out="$(
  _registry_require_jq() { return 127; }
  cmd_registry install good 2>&1
  echo "rc=$?"
)"
assert_contains "rc=127" "$out" "install propagates missing jq"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
