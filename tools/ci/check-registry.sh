#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
schema="$repo_root/docs/schema/dot-registry-v1.json"
index="$repo_root/docs/registry.json"

command -v jq >/dev/null 2>&1 || {
  printf 'registry check: jq is required\n' >&2
  exit 127
}
jq empty "$schema" "$index"

# Use the same validation logic as the runtime consumer so CI and the
# installed command cannot silently drift apart.
# shellcheck source=../../scripts/dot/commands/registry.sh disable=SC1091
source "$repo_root/scripts/dot/commands/registry.sh"
_registry_validate_index "$index" || {
  printf 'registry check: docs/registry.json violates the v1 contract\n' >&2
  exit 1
}

duplicates="$(jq -r '[.modules[].name] | group_by(.)[] | select(length > 1) | .[0]' "$index")"
[[ -z "$duplicates" ]] || {
  printf 'registry check: duplicate module names:\n%s\n' "$duplicates" >&2
  exit 1
}

if ! diff -u \
  <(jq -r '.modules[].name' "$index") \
  <(jq -r '.modules[].name' "$index" | LC_ALL=C sort); then
  printf 'registry check: modules must be sorted by name\n' >&2
  exit 1
fi

# The published index must verify against the committed registry key, which
# is what `dot registry` checks on every fetch. Until the maintainer has
# generated the key and committed security/registry.pub together with
# docs/registry.json.minisig, there is nothing to verify: say so and pass.
# Once either exists, both are required and the signature must verify.
# REGISTRY_PUBKEY / REGISTRY_SIGNATURE point the check at other files (tests).
check_signature() {
  local pubkey="$1" signature="$2" pub_rel sig_rel
  pub_rel="${pubkey#"$repo_root"/}"
  sig_rel="${signature#"$repo_root"/}"
  if [[ ! -e "$pubkey" && ! -e "$signature" ]]; then
    printf 'registry check: index not signed yet (no %s, no %s); signature check skipped\n' "$pub_rel" "$sig_rel"
    return 0
  fi
  if [[ ! -s "$pubkey" || ! -s "$signature" ]]; then
    printf 'registry check: %s and %s must be committed together\n' "$pub_rel" "$sig_rel" >&2
    return 1
  fi
  command -v minisign >/dev/null 2>&1 || {
    printf 'registry check: minisign is required to verify %s\n' "$sig_rel" >&2
    return 127
  }
  minisign -V -q -m "$index" -x "$signature" -p "$pubkey" >/dev/null || {
    printf 'registry check: docs/registry.json does not match its signature; re-sign it\n' >&2
    return 1
  }
  printf 'registry check: signature verified against %s\n' "$pub_rel"
}
check_signature "${REGISTRY_PUBKEY:-$repo_root/security/registry.pub}" \
  "${REGISTRY_SIGNATURE:-$index.minisig}" || exit $?

printf 'registry check: valid v1 index (%s modules)\n' "$(jq '.modules | length' "$index")"
