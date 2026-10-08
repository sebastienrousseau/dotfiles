#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Sourced by scripts/dot/commands/registry.sh; inherits set -euo pipefail
#
# Trust checks for the `dot registry` index, before any module is read:
#   * minisign signature (<url>.minisig) against security/registry.pub;
#   * rollback floor: the newest `updated` ever accepted per registry URL;
#   * stale-cache limit when a fetch fails;
#   * control-character scrubbing of registry text before it is printed.
# Every diagnostic goes to stderr: callers capture stdout.

[[ "${_DOT_REGISTRY_TRUST_LOADED:-0}" == "1" ]] && return 0
_DOT_REGISTRY_TRUST_LOADED=1

_REGISTRY_TRUST_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# The oldest cached index used when a fetch fails: seven days.
_REGISTRY_STALE_MAX=604800

# jq filter `clean`: C0 and C1 controls, DEL and the bidi overrides and
# isolates (U+202A-202E, U+2066-2069) become "?". Applied to every piece of
# registry text that reaches a terminal: an index is third-party data, and an
# OSC 52 sequence in a description would write the user's clipboard.
# shellcheck disable=SC2016
_REGISTRY_JQ_CLEAN='def clean: tostring | explode | map(if . < 32 or (. >= 127 and . < 160) or (. >= 8234 and . <= 8238) or (. >= 8294 and . <= 8297) then 63 else . end) | implode;'

## _registry_clean_stream — the same scrub for raw text (archive listings,
## diffs), keeping tab and newline. Bytes, not characters: C1 controls are
## only reachable from UTF-8 as two-byte sequences, which this leaves alone,
## so the preview is not a terminal-safe channel for C1; C0 is the vector
## every terminal honours.
_registry_clean_stream() {
  LC_ALL=C tr '\000-\010\013-\037\177' '?'
}

_registry_pubkey_file() {
  printf '%s\n' "${DOTFILES_REGISTRY_PUBKEY:-$_REGISTRY_TRUST_ROOT/security/registry.pub}"
}

_registry_state_dir() {
  printf '%s/dotfiles/registry\n' "${XDG_STATE_HOME:-$HOME/.local/state}"
}

## _registry_verify_signature <index> <signature> <url>
## Succeeds when <signature> is a valid minisign signature of <index> by the
## registry key. A file:// index skips this only with
## DOTFILES_REGISTRY_UNSIGNED=1; https never does.
_registry_verify_signature() {
  local index="$1" sig="$2" url="$3" pubkey
  if [[ "$url" == file://* && "${DOTFILES_REGISTRY_UNSIGNED:-}" == "1" ]]; then
    ui_warn "registry" "DOTFILES_REGISTRY_UNSIGNED=1: index signature NOT verified ($url)" >&2
    return 0
  fi
  pubkey="$(_registry_pubkey_file)"
  if [[ ! -s "$pubkey" ]]; then
    ui_err "registry" "no registry public key at $pubkey; refusing an unverified index" >&2
    return 1
  fi
  if [[ ! -s "$sig" ]]; then
    ui_err "registry" "index signature missing ($url.minisig); refusing an unsigned index" >&2
    return 1
  fi
  if ! command -v minisign >/dev/null 2>&1; then
    ui_err "registry" "minisign is required to verify the registry index signature" >&2
    return 127
  fi
  if ! minisign -V -q -m "$index" -x "$sig" -p "$pubkey" >/dev/null 2>&1; then
    ui_err "registry" "index signature verification FAILED for $url; refusing it" >&2
    return 1
  fi
}

## _registry_floor_file <cache-key> — where the newest accepted `updated`
## for one registry URL is kept. State, not cache: clearing the cache must
## not reset the rollback floor.
_registry_floor_file() {
  printf '%s/updated-%s\n' "$(_registry_state_dir)" "$1"
}

## _registry_check_rollback <index> <cache-key>
## Refuses an index whose `updated` is older than the floor, or missing once
## a floor exists. `updated` is validated as YYYY-MM-DDThh:mm:ssZ, so its
## digits compare as one integer.
_registry_check_rollback() {
  local index="$1" floor_file new old=""
  floor_file="$(_registry_floor_file "$2")"
  new="$(jq -r '.updated // ""' "$index")"
  [[ -s "$floor_file" ]] && old="$(cat "$floor_file")"
  [[ -n "$old" ]] || return 0
  if [[ -z "$new" ]] || ((10#${new//[^0-9]/} < 10#${old//[^0-9]/})); then
    ui_err "registry" "index updated '${new:-none}' is older than the last accepted '$old'; refusing a possible rollback" >&2
    return 1
  fi
}

## _registry_record_floor <index> <cache-key> — raise the floor to this
## index's `updated` (only called after _registry_check_rollback passed).
_registry_record_floor() {
  local new floor_file
  new="$(jq -r '.updated // ""' "$1")"
  [[ -n "$new" ]] || return 0
  floor_file="$(_registry_floor_file "$2")"
  mkdir -p "$(dirname "$floor_file")"
  printf '%s\n' "$new" >"$floor_file"
}

_registry_mtime() {
  stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null
}

## _registry_stale_cache <cache-file> — after a failed fetch: succeed (and
## say so) when a cached index younger than seven days exists.
_registry_stale_cache() {
  local cache_file="$1" mtime age
  [[ -s "$cache_file" ]] || return 1
  mtime="$(_registry_mtime "$cache_file")" || return 1
  age=$(($(date +%s) - mtime))
  if ((age >= _REGISTRY_STALE_MAX)); then
    ui_err "registry" "fetch failed and the cached index is older than 7 days; refusing it" >&2
    return 1
  fi
  ui_warn "registry" "fetch failed; using stale cache at $cache_file ($((age / 3600))h old)" >&2
}
