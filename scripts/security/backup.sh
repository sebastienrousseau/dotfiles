#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../dot/lib/ui.sh
source "$SCRIPT_DIR/../dot/lib/ui.sh"

ui_init
ui_header "Backup"

BACKUP_DIR="${DOTFILES_BACKUP_DIR:-$HOME/.backups}"
SRC_DIR="${DOTFILES_BACKUP_SRC:-$HOME}"
STAMP=$(date +%Y%m%d-%H%M%S)
OUT="$BACKUP_DIR/dotfiles-backup-$STAMP.tgz"

mkdir -p "$BACKUP_DIR"

if ! tar --exclude="$HOME/.cache" --exclude="$HOME/.local/share/Trash" -czf "$OUT" "$SRC_DIR"; then
  ui_err "Backup failed"
  rm -f "$OUT"
  exit 1
fi

ui_ok "Backup written" "$OUT"
