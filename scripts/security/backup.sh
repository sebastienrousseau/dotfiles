#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
# shellcheck source=../dot/lib/ui.sh
source "$REPO_ROOT/scripts/dot/lib/ui.sh"

ui_logo_dot "Dot Backup • Security"

BACKUP_DIR="${DOTFILES_BACKUP_DIR:-$HOME/.backups}"
SRC_DIR="${DOTFILES_BACKUP_SRC:-$HOME}"
STAMP=$(date +%Y%m%d-%H%M%S)
OUT="$BACKUP_DIR/dotfiles-backup-$STAMP.tgz"

mkdir -p "$BACKUP_DIR"

if ! tar --exclude="$HOME/.cache" --exclude="$HOME/.local/share/Trash" -czf "$OUT" "$SRC_DIR"; then
  ui_error "Backup failed!"
  rm -f "$OUT"
  exit 1
fi

ui_success "Backup written to" "$OUT"
