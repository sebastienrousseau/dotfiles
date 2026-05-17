#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
#
# migrate-v0_2-to-v0_2_503.sh — Idempotent, silent-by-default
# migration for the v0.2.503 repository reorganisation (Phases 2-4).
#
# Two invocation modes (both safe to run repeatedly):
#
#   1. AUTOMATIC (seamless to the user):
#      • install.sh detects pre-0.2.503 state and runs this script
#        before bootstrapping the new source.
#      • install/provision/run_before_00-migrate-v0_2_503.sh.tmpl
#        invokes this script on every `chezmoi apply`. The state-file
#        guard at the top of this script ensures it does real work
#        exactly once per host.
#
#   2. MANUAL (explicit user control):
#      bash install/migrate/migrate-v0_2-to-v0_2_503.sh
#      bash install/migrate/migrate-v0_2-to-v0_2_503.sh --verbose
#      bash install/migrate/migrate-v0_2-to-v0_2_503.sh --dry-run
#
# Per the RFC at docs/operations/RFC_v0_2_503_reorganization.md, the
# v0.2.503 reorg moves chezmoi-managed source paths:
#
#   dot_local/bin/executable_dot   → bin/dot                  (Phase 2)
#   dot_local/share/man/...        → share/man/...            (Phase 3)
#   dot_local/share/.../comp...    → share/completions/...    (Phase 3)
#   dot_*, dot_config/, etc.       → defaults/...             (Phase 4)
#
# Without intervention, chezmoi would see the old paths as "deleted
# from source" and REMOVE the deployed files at the user's HOME
# before deploying the new ones. This script makes that transition
# safe by un-tracking moved paths from chezmoi state.
#
# CURRENT STATUS: Phases 2-4 have not yet shipped in v0.2.503. This
# script's `do_migration()` body is a no-op stub today; it logs
# "no migration required (Phases 2-4 not yet shipped)" and marks
# complete. The hooks + state-file machinery are wired so the
# automation lights up the moment Phases 2-4 land — no version
# bump or extra commit needed.
#
# Exit codes:
#   0  migration succeeded OR already done OR no work needed
#   1  bad usage
#   2  chezmoi missing or unreachable
#   3  migration failed mid-flight; snapshot retained for inspection

set -euo pipefail

# ── Configuration ───────────────────────────────────────────────────────
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/v0_2_503-migration"
STATE_FILE="$STATE_DIR/.complete"
SNAPSHOT="$STATE_DIR/snapshot-$(date -u +%Y%m%dT%H%M%SZ).log"
NEW_VERSION="0.2.503"

# ── Flags ───────────────────────────────────────────────────────────────
VERBOSE=0
DRY_RUN=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --verbose | -v) VERBOSE=1 ;;
    --dry-run | -n) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    -h | --help)
      sed -n '2,40p' "$0"
      exit 0
      ;;
    *)
      printf '[migrate] unknown flag: %s\n' "$arg" >&2
      exit 1
      ;;
  esac
done

_log() { ((VERBOSE)) && printf '[migrate] %s\n' "$*"; }
_say() { printf '[migrate] %s\n' "$*"; }    # always-printed
_warn() { printf '[migrate] WARN %s\n' "$*" >&2; }
_die() {
  printf '[migrate] ERROR %s\n' "$*" >&2
  exit "${2:-3}"
}

# ── Fast-path: already migrated? ────────────────────────────────────────
if [[ -f "$STATE_FILE" ]] && ((!FORCE)); then
  _log "already migrated (state file: $STATE_FILE) — skipping"
  exit 0
fi

# ── Pre-flight: do we have a chezmoi to migrate? ────────────────────────
if ! command -v chezmoi >/dev/null 2>&1; then
  _log "chezmoi not on PATH — nothing to migrate"
  mkdir -p "$STATE_DIR"
  : >"$STATE_FILE"
  exit 0
fi

CHEZMOI_SOURCE="$(chezmoi source-path 2>/dev/null || true)"
if [[ -z "$CHEZMOI_SOURCE" ]] || [[ ! -d "$CHEZMOI_SOURCE" ]]; then
  _log "chezmoi source not configured — nothing to migrate"
  mkdir -p "$STATE_DIR"
  : >"$STATE_FILE"
  exit 0
fi

# Fresh install (no prior CLI deployed)? → no migration needed, just
# mark complete so we never re-check on this host.
if [[ ! -f "$HOME/.local/bin/dot" ]] && [[ ! -f "$HOME/.local/share/man/man1/dot.1" ]]; then
  _log "no prior install detected on this host — nothing to migrate"
  mkdir -p "$STATE_DIR"
  : >"$STATE_FILE"
  exit 0
fi

# ── Migration body ──────────────────────────────────────────────────────
# Each phase below is a guarded block. Phases 2-4 ship in subsequent
# commits; their guards stay false until the corresponding source
# paths exist in the new layout.

do_migration() {
  mkdir -p "$STATE_DIR"
  {
    printf '## v0.2.503 migration snapshot\n'
    printf 'date:           %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf 'chezmoi source: %s\n' "$CHEZMOI_SOURCE"
    printf 'target ver:     %s\n' "$NEW_VERSION"
    printf 'dry-run:        %s\n\n' "$DRY_RUN"
  } >"$SNAPSHOT"

  local did_work=0

  # ── Phase 2: bin/ — fires once `bin/dot` exists in the source ─────
  if [[ -f "$CHEZMOI_SOURCE/bin/dot" ]] && [[ -f "$HOME/.local/bin/dot" ]]; then
    _say "Phase 2: untracking dot_local/bin/* paths"
    for old in \
      "$HOME/.local/bin/dot" \
      "$HOME/.local/bin/dot-bootstrap" \
      "$HOME/.local/bin/dot-theme-sync" \
      "$HOME/.local/bin/dot-load-benchmark-pty"; do
      if [[ -f "$old" ]]; then
        if ((DRY_RUN)); then
          _say "  [dry-run] would forget: $old"
        else
          chezmoi forget --force "$old" >>"$SNAPSHOT" 2>&1 && _log "  forgot: $old" || _warn "  forget failed: $old"
        fi
      fi
    done
    did_work=1
  fi

  # ── Phase 3: share/ — man + completions ─────────────────────────────
  if [[ -f "$CHEZMOI_SOURCE/share/man/man1/dot.1" ]] && [[ -f "$HOME/.local/share/man/man1/dot.1" ]]; then
    _say "Phase 3: untracking dot_local/share/* paths"
    for old in \
      "$HOME/.local/share/man/man1/dot.1" \
      "$HOME/.local/share/zsh/completions/_dot"; do
      if [[ -f "$old" ]]; then
        if ((DRY_RUN)); then
          _say "  [dry-run] would forget: $old"
        else
          chezmoi forget --force "$old" >>"$SNAPSHOT" 2>&1 && _log "  forgot: $old" || _warn "  forget failed: $old"
        fi
      fi
    done
    did_work=1
  fi

  # ── Phase 4: defaults/ + .chezmoiroot ───────────────────────────────
  if [[ -f "$CHEZMOI_SOURCE/.chezmoiroot" ]]; then
    _say "Phase 4: .chezmoiroot detected — chezmoi handles defaults/ subtree natively"
    # chezmoi reads .chezmoiroot on its own. No forgets needed for
    # defaults/ — chezmoi simply re-bases its source-root.
    did_work=1
  fi

  if ((did_work == 0)); then
    _log "no migration required (Phases 2-4 not yet shipped in source)"
  fi

  # Mark complete (even in dry-run, so we don't keep re-checking).
  if ((DRY_RUN == 0)); then
    : >"$STATE_FILE"
    _log "marked migration complete: $STATE_FILE"
  fi
}

do_migration

if ((VERBOSE)) || [[ ! -s "$STATE_FILE" ]]; then
  _say "Migration finished. Snapshot: $SNAPSHOT"
fi

exit 0
