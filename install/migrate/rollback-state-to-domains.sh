#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# rollback-state-to-domains.sh: undo migrate-state-to-domains.sh. Each move
# in its manifest is reversed, newest first, when the moved entry is still
# where the migration put it and its old name is free. The done marker and
# the manifest then go, so the next apply migrates again.
#
#   bash install/migrate/rollback-state-to-domains.sh [--dry-run]
#
# A log the migration prepended to an existing one cannot be split again:
# it stays in the new file, and is listed. Downgrade first (to a release
# that writes $XDG_STATE_HOME/dotfiles/) and roll back after, or the next
# apply moves everything again.
#
# Exit codes: 0 rolled back or nothing to do; 1 bad usage; 3 something
# stayed (listed on stderr).

set -euo pipefail

STATE="${XDG_STATE_HOME:-$HOME/.local/state}"
MIGRATIONS="$STATE/dot/cli/migrations"
MARKER="$MIGRATIONS/state-domains.done"
MANIFEST="$MIGRATIONS/state-domains.manifest"

DRY_RUN=0
STAYED=0

stayed() {
  printf 'rollback-state: stayed %s: %s\n' "$1" "$2" >&2
  STAYED=1
}

# undo_one SRC DST [KIND]: put DST back at SRC.
undo_one() {
  if [[ "${3:-}" == prepended ]]; then
    stayed "$1" "its lines were prepended to $2"
  elif [[ ! -e "$2" && ! -L "$2" ]]; then
    stayed "$1" "$2 is gone"
  elif [[ -e "$1" || -L "$1" ]]; then
    stayed "$2" "$1 exists"
  elif [[ "$DRY_RUN" == 1 ]]; then
    printf 'rollback-state: move %s -> %s\n' "$2" "$1"
  else
    mkdir -p "$(dirname "$1")" && mv "$2" "$1"
  fi
}

main() {
  local src dst kind
  case "${1:-}" in
    "") ;;
    --dry-run | -n) DRY_RUN=1 ;;
    *)
      printf 'rollback-state: unknown option %s\n' "$1" >&2
      return 1
      ;;
  esac
  [[ -f "$MANIFEST" ]] || return 0
  while IFS=$'\t' read -r src dst kind; do
    [[ -n "$src" && -n "$dst" ]] && undo_one "$src" "$dst" "$kind"
  done < <(tac "$MANIFEST" 2>/dev/null || tail -r "$MANIFEST")
  [[ "$DRY_RUN" == 0 ]] || return 0
  rm -f "$MARKER" "$MANIFEST"
  [[ "$STAYED" == 0 ]] || return 3
}

main "$@"
