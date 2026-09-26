#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# ~/.npmrc (defaults/modify_private_dot_npmrc) keeps the registry auth lines
# `npm login` writes. As a plain template it dropped them on every apply, so
# a non-interactive `dot upgrade` stopped at chezmoi's "has changed since
# chezmoi last wrote it" prompt (EOF, exit 1). Runs the real chezmoi on a
# sandbox source holding only this file; tokens here are fake.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CHEZMOI_BIN="$(command -v chezmoi || true)"
if [[ -z "$CHEZMOI_BIN" ]]; then
  test_start "npmrc_requires_chezmoi"
  assert_true "true" "skipped: chezmoi not installed"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

SB="$(cd "$(mktemp -d "${TMPDIR:-/tmp}/npmrc.XXXXXX")" && pwd)"
trap 'rm -rf "$SB"' EXIT
mkdir -p "$SB/old/defaults" "$SB/new/defaults"
echo defaults >"$SB/old/.chezmoiroot"
echo defaults >"$SB/new/.chezmoiroot"
cp "$REPO_ROOT/defaults/modify_private_dot_npmrc" "$SB/new/defaults/"
# The pre-fix template, as a plain managed file, to set up chezmoi's state.
cat >"$SB/old/defaults/private_dot_npmrc.tmpl" <<'OLD'
# npm configuration
save-exact=true
OLD

# cz <home> <config> <source> <args...>: non-interactive, like dot upgrade.
cz() {
  local home="$1" config="$2" src="$3"
  shift 3
  env -i HOME="$home" PATH="/usr/bin:/bin" "$CHEZMOI_BIN" --config "$config" --source "$src" \
    --destination "$home" --cache "$home/.cz-cache" --persistent-state "$home/.cz-state.boltdb" \
    "$@" </dev/null
}

# 1. chezmoi wrote ~/.npmrc, then `npm login` appended a token.
H1="$SB/h1"
mkdir -p "$H1"
: >"$SB/empty.toml"
cz "$H1" "$SB/empty.toml" "$SB/old" apply >/dev/null 2>&1
printf '# npm registry auth token\n//registry.npmjs.org/:_authToken=npm_FAKE_LOGIN\n' >>"$H1/.npmrc"
rc=0
cz "$H1" "$SB/empty.toml" "$SB/new" apply >"$SB/out" 2>&1 || rc=$?

test_start "npmrc_apply_after_npm_login_is_non_interactive"
assert_equals "0" "$rc" "applying over an npm-login-edited ~/.npmrc needs no prompt"

test_start "npmrc_keeps_npm_login_token"
assert_equals "1" "$(grep -c '^//registry.npmjs.org/:_authToken=npm_FAKE_LOGIN$' "$H1/.npmrc")" \
  "the token npm login wrote is kept, once"

test_start "npmrc_keeps_managed_settings"
assert_equals "1" "$(grep -c '^save-exact=true$' "$H1/.npmrc")" "the managed settings are written"

test_start "npmrc_stays_private"
assert_equals "600" "$(stat -c '%a' "$H1/.npmrc" 2>/dev/null || stat -f '%Lp' "$H1/.npmrc")" \
  "~/.npmrc stays owner-only"

rc=0
cz "$H1" "$SB/empty.toml" "$SB/new" apply >/dev/null 2>&1 || rc=$?
test_start "npmrc_second_apply_is_stable"
assert_equals "0|1" "$rc|$(grep -c 'npm_FAKE_LOGIN' "$H1/.npmrc")" "a second apply changes nothing"

# 2. A token in chezmoi data wins for its registry; other registries are kept.
H2="$SB/h2"
mkdir -p "$H2"
printf '[data]\n  npm_token = "npm_FAKE_DATA"\n' >"$SB/data.toml"
printf '//registry.npmjs.org/:_authToken=npm_FAKE_OLD\n//npm.example.com/:_authToken=npm_FAKE_OTHER\n' >"$H2/.npmrc"
cz "$H2" "$SB/data.toml" "$SB/new" apply >/dev/null 2>&1

test_start "npmrc_data_token_wins_for_its_registry"
assert_equals "npm_FAKE_DATA" \
  "$(sed -n 's|^//registry.npmjs.org/:_authToken=||p' "$H2/.npmrc" | tr '\n' ' ' | sed 's/ $//')" \
  "the data token replaces the old line for registry.npmjs.org"

test_start "npmrc_keeps_other_registry_tokens"
assert_equals "1" "$(grep -c '^//npm.example.com/:_authToken=npm_FAKE_OTHER$' "$H2/.npmrc")" \
  "a token for another registry is kept"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
