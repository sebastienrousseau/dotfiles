#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
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

printf 'registry check: valid v1 index (%s modules)\n' "$(jq '.modules | length' "$index")"
