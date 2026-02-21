#!/usr/bin/env bash
## Create compressed backup of home directory.
##
## Archives the home directory (excluding cache and trash) to a timestamped
## .tgz file. Supports custom source and destination directories via
## environment variables.
##
## # Usage
## dot backup
## DOTFILES_BACKUP_DIR=/mnt/backup dot backup
##
## # Dependencies
## - tar: Archive creation
##
## # Environment Variables
## | Variable | Default | Description |
## |----------|---------|-------------|
## | DOTFILES_BACKUP_DIR | ~/.backups | Backup destination |
## | DOTFILES_BACKUP_SRC | ~/ | Source directory |
##
## # Platform Notes
## - macOS: Uses BSD tar
## - Linux: Uses GNU tar
## - WSL: Backup stored in Linux filesystem for performance
##
## # Security
## Does not encrypt backups. Use age/gpg for sensitive data.
##
## # Idempotency
## Creates new timestamped backup on each run.

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
