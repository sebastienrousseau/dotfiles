#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Regression: allowed_signers listed the owner's signing keys only when
# git_email was the personal address, so switching to the GitHub noreply
# address dropped them and every own commit verified as U, not G.
# Regression for: GH-1215
# Why: the owner commits as the noreply address; the roster must follow it
# and must not publish the personal address.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

_as_chezmoi="$(command -v chezmoi 2>/dev/null || true)"
if [[ -z "$_as_chezmoi" ]]; then
  echo "  (skip) chezmoi not available"
  echo "RESULTS:0:0:0"
  exit 0
fi

_as_tmp="$(mktemp -d -t dotfiles-signers.XXXXXX)"
trap 'rm -rf "$_as_tmp"' EXIT
_as_tmpl="$REPO_ROOT/defaults/dot_config/git/allowed_signers.tmpl"

# _as_render <git_email> — render the template with that git_email.
_as_render() {
  printf '{"data":{"git_email":"%s"}}\n' "$1" >"$_as_tmp/chezmoi.json"
  "$_as_chezmoi" --config "$_as_tmp/chezmoi.json" --source "$REPO_ROOT/defaults" \
    --destination "$_as_tmp/home" --cache "$_as_tmp/cache" \
    --persistent-state "$_as_tmp/state.boltdb" \
    execute-template <"$_as_tmpl" 2>/dev/null
}

# _as_keys <git_email> — number of key entries in that render.
_as_keys() { _as_render "$1" | grep -cv '^#'; }

# A user outside the owner list gets only the always-on entries; the
# owner's device and hardware keys sit in the email-gated block.
_as_base="$(_as_keys you@example.com)"

test_start "signers_other_user_gets_the_base_roster"
assert_not_equals "0" "$_as_base" "another user's roster still has the always-on entries"

test_start "signers_noreply_adds_owner_keys"
_as_n="$(_as_keys sebastienrousseau@users.noreply.github.com)"
assert_equals "true" "$([[ $_as_n -gt $_as_base ]] && echo true || echo false)" \
  "GitHub noreply git_email adds the owner keys ($_as_base -> $_as_n)"

test_start "signers_render_has_no_personal_address"
assert_output_not_contains "gmail" _as_render sebastienrousseau@users.noreply.github.com

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
