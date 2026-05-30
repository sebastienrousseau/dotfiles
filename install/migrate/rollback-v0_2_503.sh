#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
#
# rollback-v0_2_503.sh — Revert the v0.2.503 migration.
#
# Use this if the post-migration `dot doctor` reports breakage you
# can't immediately fix, or if you simply want to go back to v0.2.502.
#
# What this does:
#   1. Reads the most recent snapshot in
#      ~/.local/state/dotfiles/v0_2_503-migration/snapshot-*.log
#   2. Resets the chezmoi source repo to the version recorded there.
#   3. Re-runs `chezmoi apply` against the old layout.
#
# Idempotent. Safe to run even if no migration ever happened (exits 0).

set -euo pipefail

STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/v0_2_503-migration"

_log() { printf '[rollback] %s\n' "$*"; }
_die() {
  printf '[rollback] ERROR %s\n' "$*" >&2
  exit 1
}

if [[ ! -d "$STATE_DIR" ]]; then
  _log "no migration snapshot found at $STATE_DIR — nothing to roll back"
  exit 0
fi

snapshot="$(find "$STATE_DIR" -name 'snapshot-*.log' -type f 2>/dev/null \
  | sort -r | head -1)"

[[ -n "$snapshot" ]] || _die "snapshot directory exists but is empty: $STATE_DIR"
_log "using snapshot: $snapshot"

prev_ver="$(grep -E '^current ver:' "$snapshot" | awk '{print $NF}')"
[[ -n "$prev_ver" ]] || _die "snapshot missing 'current ver:' line — corrupted?"
[[ "$prev_ver" != "unknown" ]] \
  || _die "snapshot recorded version 'unknown' — cannot determine rollback target"

_log "rolling back to v$prev_ver"

CHEZMOI_SOURCE="$(chezmoi source-path 2>/dev/null || true)"
[[ -n "$CHEZMOI_SOURCE" ]] || _die "chezmoi has no source configured"

if [[ ! -d "$CHEZMOI_SOURCE/.git" ]]; then
  _die "source is not a git checkout — manual rollback required"
fi

_log "checking out v$prev_ver in $CHEZMOI_SOURCE"
( cd "$CHEZMOI_SOURCE" && git fetch --tags origin && git checkout "v$prev_ver" )

_log "running chezmoi apply (old layout will restore)"
chezmoi apply || _die "rollback apply failed — inspect $snapshot and resolve manually"

# Mark this snapshot as rolled back.
mv "$snapshot" "${snapshot}.rolled-back"

_log "rollback complete. Source is now at v$prev_ver."
_log "next: dot doctor   (verify)   |   dot version   (confirm $prev_ver)"
exit 0
