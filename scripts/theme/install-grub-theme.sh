#!/usr/bin/env bash
set -euo pipefail

THEME_SRC="${DOTFILES_GRUB_THEME_DIR:-$HOME/.config/dotfiles/grub/theme}"
THEME_NAME="${DOTFILES_GRUB_THEME_NAME:-dotfiles}"
APPLY=0

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;; 
  esac
 done

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "GRUB theming is Linux-only." >&2
  exit 0
fi

if [[ ! -d "$THEME_SRC" ]]; then
  echo "Theme directory not found: $THEME_SRC" >&2
  echo "Place a GRUB theme there or set DOTFILES_GRUB_THEME_DIR." >&2
  exit 1
fi

if [[ $APPLY -ne 1 ]]; then
  echo "Dry run. Use --apply to install the theme." >&2
  exit 0
fi

if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo for GRUB theme install." >&2
  exit 1
fi

THEME_DST="/boot/grub/themes/$THEME_NAME"
mkdir -p "$THEME_DST"
cp -R "$THEME_SRC/." "$THEME_DST"

if grep -q '^GRUB_THEME=' /etc/default/grub; then
  sed -i.bak "s|^GRUB_THEME=.*|GRUB_THEME=\"$THEME_DST/theme.txt\"|" /etc/default/grub
else
  echo "GRUB_THEME=\"$THEME_DST/theme.txt\"" >> /etc/default/grub
fi

if command -v update-grub >/dev/null; then
  update-grub
elif command -v grub-mkconfig >/dev/null; then
  grub-mkconfig -o /boot/grub/grub.cfg
fi

echo "GRUB theme installed: $THEME_DST"
