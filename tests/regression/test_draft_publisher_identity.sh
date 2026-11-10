#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Regression: draft's publisher identity is personal. The dotfiles render
# ~/.config/draft/config.toml from the host's draft_site_* chezmoi data,
# leave the file unmanaged on a host without it (an empty render would
# delete a hand-written one), and keep the keys across a re-init.
# Why: draft shipped its maintainer's identity as a default until v0.0.44;
# a framework default must not do the same.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

_dp_chezmoi="$(command -v chezmoi 2>/dev/null || true)"
if [[ -z "$_dp_chezmoi" ]]; then
  echo "  (skip) chezmoi not available"
  echo "RESULTS:0:0:0"
  exit 0
fi

_dp_tmp="$(mktemp -d -t dotfiles-draft.XXXXXX)"
trap 'rm -rf "$_dp_tmp"' EXIT
_dp_src="$REPO_ROOT/defaults"
_dp_with='"draft_site_name":"Ada Example","draft_site_base_url":"https://example.com","draft_site_copyright_from":2025'
_dp_base='"features":{},"profile":"laptop"'

# _dp_render <template> <extra data> [--init] — render a template with
# the given chezmoi data, non-interactively.
_dp_render() {
  printf '{"data":{%s%s}}\n' "$_dp_base" "${2:+,$2}" >"$_dp_tmp/chezmoi.json"
  "$_dp_chezmoi" --config "$_dp_tmp/chezmoi.json" --source "$_dp_src" \
    --destination "$_dp_tmp/home" --cache "$_dp_tmp/cache" \
    --persistent-state "$_dp_tmp/state.boltdb" \
    execute-template ${3:+"$3"} <"$1" 2>/dev/null
}
_dp_config() { _dp_render "$_dp_src/dot_config/draft/config.toml.tmpl" "$1"; }
_dp_ignored() {
  _dp_render "$_dp_src/.chezmoiignore.tmpl" "$1" | grep -qx '.config/draft/config.toml' && echo ignored || echo managed
}

_dp_out="$(_dp_config "$_dp_with")"

test_start "draft_identity_renders_the_name"
assert_contains 'name           = "Ada Example"' "$_dp_out" "name from draft_site_name"

test_start "draft_identity_renders_the_base_url"
assert_contains 'base-url       = "https://example.com"' "$_dp_out" "base-url from draft_site_base_url"

test_start "draft_identity_writes_a_number_as_a_string"
assert_contains 'copyright-from = "2025"' "$_dp_out" "a number is written as draft reads it"

test_start "draft_identity_writes_only_the_keys_set"
assert_output_not_contains "email" _dp_config "'$_dp_with'"

test_start "draft_identity_is_unmanaged_without_keys"
assert_equals "ignored" "$(_dp_ignored "")" "a host with no draft_site_* keys leaves the file alone"

test_start "draft_identity_template_has_no_identity_of_its_own"
assert_output_not_contains "Rousseau" _dp_config "''"

test_start "draft_identity_is_managed_when_set"
assert_equals "managed" "$(_dp_ignored "$_dp_with")" "a host with draft_site_* keys gets the file"

_dp_init="$(CHEZMOI_GIT_NAME=x CHEZMOI_GIT_EMAIL=x@example.com _dp_render "$_dp_src/.chezmoi.toml.tmpl" "$_dp_with" --init)"

test_start "draft_identity_reinit_keeps_the_name"
assert_contains 'draft_site_name = "Ada Example"' "$_dp_init" "chezmoi init keeps draft_site_name"

test_start "draft_identity_reinit_keeps_every_key"
assert_contains 'draft_site_copyright_from = "2025"' "$_dp_init" "and every other draft_site_* key"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
