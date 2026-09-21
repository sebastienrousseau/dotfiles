#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CHECKSUM="$REPO_ROOT/tools/docs/checksum-manual.sh"
WORKFLOW="$REPO_ROOT/.github/workflows/manual-publish.yml"
fixture="$(mktemp -d "${TMPDIR:-/tmp}/dot-manual-assets.XXXXXX")"
trap 'rm -rf "$fixture"' EXIT
mkdir "$fixture/build" "$fixture/download"

# Materialize exactly the release upload allowlist. Any checksum entry omitted
# by the workflow then fails at generation or at consumer verification.
upload_list="$(sed -n 's|^[[:space:]]*_build/manual/\([^ /]*\)$|\1|p' "$WORKFLOW")"
while IFS= read -r asset; do
  [[ $asset == SHA256SUMS ]] && continue
  printf 'fixture for %s\n' "$asset" >"$fixture/build/$asset"
done <<<"$upload_list"

test_start "full_manifest_matches_release_uploads"
bash "$CHECKSUM" "$fixture/build" >"$fixture/build/SHA256SUMS"
expected="$(printf '%s\n' "$upload_list" | sed '/^SHA256SUMS$/d' | LC_ALL=C sort)"
actual="$(awk '{print $2}' "$fixture/build/SHA256SUMS" | LC_ALL=C sort)"
assert_equals "$expected" "$actual" "every upload must be hashed and every hash uploaded"

test_start "bsd_shasum_fallback_matches_manifest"
mkdir "$fixture/bin"
ln -s "$(command -v shasum)" "$fixture/bin/shasum"
PATH="$fixture/bin" /bin/bash "$CHECKSUM" "$fixture/build" >"$fixture/fallback"
assert_equals "$(<"$fixture/build/SHA256SUMS")" "$(<"$fixture/fallback")" "GNU and BSD hash output agrees"

test_start "hash_failure_does_not_trigger_fallback"
sha256sum() { return 77; }
export -f sha256sum
assert_exit_code 77 "bash '$CHECKSUM' '$fixture/build'"
unset -f sha256sum

test_start "consumer_verifies_only_downloaded_assets"
while IFS= read -r asset; do
  cp "$fixture/build/$asset" "$fixture/download/$asset"
done <<<"$upload_list"
assert_exit_code 0 "(cd '$fixture/download' && shasum -a 256 -c SHA256SUMS)"

test_start "markdown_source_is_hashed"
assert_file_contains "$fixture/build/SHA256SUMS" 'dotfiles-md.tar.gz' "source archive has integrity coverage"

test_start "tampering_fails_consumer_verification"
printf 'tampered\n' >>"$fixture/download/dotfiles.html"
assert_exit_code 1 "(cd '$fixture/download' && shasum -a 256 -c SHA256SUMS)"

test_start "unpublished_intermediates_are_not_hashed"
printf 'private build intermediate\n' >"$fixture/build/dotfiles.private"
assert_output_not_contains 'dotfiles.private' "bash '$CHECKSUM' '$fixture/build'"

test_start "fast_manifest_excludes_stale_pdf"
assert_output_not_contains 'dotfiles.pdf' "bash '$CHECKSUM' '$fixture/build' --fast"

test_start "missing_pdf_is_allowed_only_for_fast_builds"
mv "$fixture/build/dotfiles.pdf" "$fixture/saved.pdf"
assert_exit_code 0 "bash '$CHECKSUM' '$fixture/build' --fast"
test_start "missing_pdf_fails_full_builds"
assert_exit_code 1 "bash '$CHECKSUM' '$fixture/build'"
mv "$fixture/saved.pdf" "$fixture/build/dotfiles.pdf"

test_start "missing_asset_fails_without_partial_manifest"
mv "$fixture/build/search-index.json" "$fixture/saved.json"
assert_exit_code 1 "bash '$CHECKSUM' '$fixture/build' >'$fixture/partial'"
test_start "preflight_failure_emits_no_partial_manifest"
assert_equals '' "$(<"$fixture/partial")" "failed preflight produces no checksums"

test_start "empty_asset_is_rejected"
touch "$fixture/build/search-index.json"
assert_exit_code 1 "bash '$CHECKSUM' '$fixture/build'"
rm "$fixture/build/search-index.json"

test_start "symlinked_asset_is_rejected"
ln -s "$fixture/saved.json" "$fixture/build/search-index.json"
assert_exit_code 1 "bash '$CHECKSUM' '$fixture/build'"

test_start "unknown_checksum_mode_is_rejected"
assert_exit_code 2 "bash '$CHECKSUM' '$fixture/build' --unknown"

test_start "upload_is_fail_closed"
assert_file_contains "$WORKFLOW" 'fail_on_unmatched_files: true' "missing formats stop publication"

test_start "downloaded_assets_are_verified_before_upload"
assert_file_contains "$WORKFLOW" 'run: sha256sum --check --strict SHA256SUMS' "verify transferred build outputs"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
