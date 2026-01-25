#!/bin/sh
set -e

BACKUP_DIR="${DOTFILES_BACKUP_DIR:-$HOME/.backups}"
SRC_DIR="${DOTFILES_BACKUP_SRC:-$HOME}"
STAMP=$(date +%Y%m%d-%H%M%S)
OUT="$BACKUP_DIR/dotfiles-backup-$STAMP.tgz"

mkdir -p "$BACKUP_DIR"

tar --exclude="$HOME/.cache" --exclude="$HOME/.local/share/Trash" -czf "$OUT" "$SRC_DIR"

echo "Backup written to: $OUT"
