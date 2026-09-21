#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

PREFLIGHT="$REPO_ROOT/scripts/release-preflight"
FIXTURES=()
trap 'for fixture in "${FIXTURES[@]}"; do rm -rf "$fixture"; done' EXIT

fixture_repo() {
  local version="$1"
  local previous_version="0.0.0"
  if [[ "$version" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]] &&
    ((10#${BASH_REMATCH[3]} > 0)); then
    previous_version="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.$((10#${BASH_REMATCH[3]} - 1))"
  fi
  FIXTURE_ROOT="$(mktemp -d -t release-preflight.XXXXXX)"
  FIXTURES+=("$FIXTURE_ROOT")
  mkdir -p "$FIXTURE_ROOT/defaults" "$FIXTURE_ROOT/scripts"
  {
    printf 'dotfiles_version = "%s"\n' "$version"
    printf 'previous_dotfiles_version = "%s"\n' "$previous_version"
  } >"$FIXTURE_ROOT/defaults/.chezmoidata.toml"
  printf '%s\n' '#!/usr/bin/env bash' 'exit "${VERIFY_RC:-0}"' \
    >"$FIXTURE_ROOT/scripts/verify-release-versions"
  chmod +x "$FIXTURE_ROOT/scripts/verify-release-versions"
  git -C "$FIXTURE_ROOT" init -q
  git -C "$FIXTURE_ROOT" add .
  git -C "$FIXTURE_ROOT" -c user.name=Test -c user.email=test@example.invalid \
    -c commit.gpgsign=false commit -q -m initial
  if [[ "$previous_version" != "0.0.0" ]]; then
    git -C "$FIXTURE_ROOT" -c tag.gpgSign=false tag --no-sign "v$previous_version"
  fi
}

run_preflight() {
  local root="$1"
  shift
  REPO_ROOT="$root" bash "$PREFLIGHT" "$@" 2>&1
}

test_start "release_preflight_accepts_unused_version"
fixture_repo 1.2.3
root="$FIXTURE_ROOT"
output="$(run_preflight "$root")"
assert_contains "v1.2.3 is available" "$output" "unused version passes"

test_start "release_preflight_accepts_tag_at_head_for_verification"
fixture_repo 1.2.3
root="$FIXTURE_ROOT"
git -C "$root" -c tag.gpgSign=false tag --no-sign v1.2.3
output="$(run_preflight "$root")"
assert_contains "already identifies HEAD" "$output" "idempotent verification passes"

test_start "release_preflight_rejects_reused_tag"
fixture_repo 1.2.3
root="$FIXTURE_ROOT"
git -C "$root" -c tag.gpgSign=false tag --no-sign v1.2.3
printf 'next\n' >"$root/change"
git -C "$root" add change
git -C "$root" -c user.name=Test -c user.email=test@example.invalid \
  -c commit.gpgsign=false commit -q -m next
rc=0
output="$(run_preflight "$root")" || rc=$?
assert_equals 1 "$rc" "tag at another commit fails"
assert_contains "bump the version" "$output" "remediation is explicit"

test_start "release_preflight_require_untagged_rejects_existing_head_tag"
fixture_repo 1.2.3
root="$FIXTURE_ROOT"
git -C "$root" -c tag.gpgSign=false tag --no-sign v1.2.3
rc=0
output="$(run_preflight "$root" --require-untagged)" || rc=$?
assert_equals 1 "$rc" "new release cannot reuse an existing tag"
assert_contains "release tags are immutable" "$output" "immutability reason is explicit"

test_start "release_preflight_rejects_version_drift"
fixture_repo 1.2.3
root="$FIXTURE_ROOT"
rc=0
output="$(VERIFY_RC=1 run_preflight "$root")" || rc=$?
assert_equals 1 "$rc" "version verifier failure propagates"
assert_contains "version-bearing files do not match" "$output" "drift is diagnosed"

test_start "release_preflight_rejects_invalid_manifest_version"
fixture_repo not-semver
root="$FIXTURE_ROOT"
rc=0
output="$(run_preflight "$root")" || rc=$?
assert_equals 2 "$rc" "invalid canonical version is usage/config error"
assert_contains "invalid or missing dotfiles_version" "$output" "invalid manifest is diagnosed"

test_start "release_preflight_rejects_invalid_previous_version"
fixture_repo 1.2.3
root="$FIXTURE_ROOT"
sed -i.bak 's/previous_dotfiles_version = "1.2.2"/previous_dotfiles_version = "invalid"/' \
  "$root/defaults/.chezmoidata.toml"
rm -f "$root/defaults/.chezmoidata.toml.bak"
rc=0
output="$(run_preflight "$root")" || rc=$?
assert_equals 2 "$rc" "invalid predecessor version is a configuration error"
assert_contains "invalid or missing previous_dotfiles_version" "$output" \
  "invalid predecessor is diagnosed"

test_start "release_preflight_rejects_skipped_patch"
fixture_repo 1.2.3
root="$FIXTURE_ROOT"
sed -i.bak 's/previous_dotfiles_version = "1.2.2"/previous_dotfiles_version = "1.2.1"/' \
  "$root/defaults/.chezmoidata.toml"
rm -f "$root/defaults/.chezmoidata.toml.bak"
git -C "$root" -c tag.gpgSign=false tag --no-sign v1.2.1
rc=0
output="$(run_preflight "$root")" || rc=$?
assert_equals 1 "$rc" "candidate cannot skip a patch release"
assert_contains "must be exactly one patch after" "$output" \
  "patch-only remediation is explicit"

test_start "release_preflight_rejects_missing_predecessor_tag"
fixture_repo 1.2.3
root="$FIXTURE_ROOT"
git -C "$root" tag -d v1.2.2 >/dev/null
rc=0
output="$(run_preflight "$root")" || rc=$?
assert_equals 1 "$rc" "missing predecessor tag fails"
assert_contains "patch releases cannot be skipped" "$output" \
  "missing predecessor explains the release invariant"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
