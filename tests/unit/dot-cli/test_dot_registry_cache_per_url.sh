#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# The registry index cache must be keyed by the URL it came from.
#
# It used to live at <cache>/index.json for every registry and be treated as
# fresh for six hours, so pointing DOTFILES_REGISTRY_URL at a different index
# (or running `dot registry set-url`) kept serving the previous registry's
# modules until the TTL expired. Nothing about the six-hour window says which
# registry produced the file.
#
# curl is shimmed to copy a local fixture, so no test here touches the
# network; every index is served from a file the test wrote.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

REGISTRY_SH="$REPO_ROOT/scripts/dot/commands/registry.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
# XDG_RUNTIME_DIR belongs inside the sandbox too: leaving it unset sends any
# lock or socket a command opens to a machine-global /tmp path shared with
# every other test process the runner has in flight.
export XDG_RUNTIME_DIR="$DOTFILES_COV_TMPDIR/run"
mkdir -p "$XDG_RUNTIME_DIR"

WORK="$DOTFILES_COV_TMPDIR/registry-cache"
BIN="$DOTFILES_COV_TMPDIR/bin"
mkdir -p "$WORK"

test_start "registry_module_exists"
assert_file_exists "$REGISTRY_SH" "scripts/dot/commands/registry.sh must exist"

if ! command -v jq >/dev/null 2>&1; then
  test_start "registry_cache_per_url"
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: skipped — jq not installed"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

# ---------------------------------------------------------------------------
# Two registries, each valid against _registry_validate_index's schema.
# ---------------------------------------------------------------------------
_fixture() {
  local path="$1" module="$2"
  cat >"$path" <<JSON
{
  "version": 1,
  "modules": [
    {
      "name": "$module",
      "description": "fixture module $module",
      "tags": ["fixture"],
      "version": "1.0.0",
      "archive_url": "https://example.com/$module-1.0.0.tar.gz",
      "sha256": "$(printf 'a%.0s' $(seq 1 64))"
    }
  ]
}
JSON
}
_fixture "$WORK/alpha.json" "alpha-module"
_fixture "$WORK/beta.json" "beta-module"

# curl shim: serves whichever fixture $FAKE_CURL_SOURCE names, and records
# every call so "was this a cache hit?" is answerable.
CURL_LOG="$WORK/curl.log"
cat >"$BIN/curl" <<SHIM
#!/usr/bin/env bash
out=""
url=""
while (( \$# )); do
  case "\$1" in
    -o)
      out="\$2"
      shift 2
      ;;
    -*) shift ;;
    *)
      url="\$1"
      shift
      ;;
  esac
done
printf '%s\n' "\$url" >>"$CURL_LOG"
[[ -n "\$out" ]] && cp "\$FAKE_CURL_SOURCE" "\$out"
exit 0
SHIM
chmod +x "$BIN/curl"
: >"$CURL_LOG"

# fetch <url> <fixture> — run _registry_fetch for a URL and print the module
# name the returned index contains.
fetch() {
  local url="$1" source_file="$2"
  DOTFILES_REGISTRY_URL="$url" FAKE_CURL_SOURCE="$source_file" \
    PATH="$BIN:$PATH" \
    bash -c '
      source "$1"
      index="$(_registry_fetch)" || exit $?
      jq -r ".modules[0].name" "$index"
    ' _ "$REGISTRY_SH" 2>/dev/null
}

URL_A="https://alpha.example/registry.json"
URL_B="https://beta.example/registry.json"

test_start "the_first_fetch_populates_the_cache"
got="$(fetch "$URL_A" "$WORK/alpha.json")"
assert_equals "alpha-module" "$got" "the first registry's index is served"
assert_equals "1" "$(wc -l <"$CURL_LOG" | tr -d ' ')" "one fetch so far"

test_start "a_second_fetch_of_the_same_url_is_served_from_the_cache"
got="$(fetch "$URL_A" "$WORK/alpha.json")"
assert_equals "alpha-module" "$got" "the cached index is reused"
assert_equals "1" "$(wc -l <"$CURL_LOG" | tr -d ' ')" "no second fetch inside the TTL"

test_start "changing_the_registry_url_does_not_serve_the_previous_index"
got="$(fetch "$URL_B" "$WORK/beta.json")"
assert_equals "beta-module" "$got" "the new registry's index is served, not the cached one"
assert_equals "2" "$(wc -l <"$CURL_LOG" | tr -d ' ')" "the new URL is actually fetched"

test_start "switching_back_reuses_the_first_registrys_cache"
got="$(fetch "$URL_A" "$WORK/beta.json")"
assert_equals "alpha-module" "$got" "each URL keeps its own cached index"
assert_equals "2" "$(wc -l <"$CURL_LOG" | tr -d ' ')" "no refetch when switching back inside the TTL"

test_start "each_url_has_its_own_cache_file"
paths="$(DOTFILES_REGISTRY_URL="" PATH="$BIN:$PATH" bash -c '
  source "$1"
  _registry_cache_file "$2"
  _registry_cache_file "$3"
' _ "$REGISTRY_SH" "$URL_A" "$URL_B")"
assert_equals "2" "$(printf '%s\n' "$paths" | sort -u | wc -l | tr -d ' ')" \
  "two URLs must map to two cache files"
assert_output_not_contains "/index.json" "printf '%s' '$paths'"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
