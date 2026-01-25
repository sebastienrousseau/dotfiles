#!/usr/bin/env bash
set -euo pipefail

logo_path="${DOTFILES_BOOT_LOGO:-$HOME/.config/dotfiles/boot/logo.png}"
APPLY=0

for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;; 
  esac
 done

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "Boot logo customization is Linux-only." >&2
  exit 0
fi

if [[ ! -f "$logo_path" ]]; then
  echo "Boot logo not found: $logo_path" >&2
  echo "Place a PNG at that path or set DOTFILES_BOOT_LOGO." >&2
  exit 1
fi

if [[ $APPLY -ne 1 ]]; then
  echo "Dry run. Use --apply to install the boot logo." >&2
  exit 0
fi

if [[ $EUID -ne 0 ]]; then
  echo "Please run with sudo for boot logo install." >&2
  exit 1
fi

if command -v plymouth-set-default-theme >/dev/null; then
  theme_dir="/usr/share/plymouth/themes/dotfiles"
  mkdir -p "$theme_dir"
  cp "$logo_path" "$theme_dir/logo.png"
  cat > "$theme_dir/dotfiles.plymouth" <<PLY
[Plymouth Theme]
Name=Dotfiles
Description=Dotfiles boot splash
ModuleName=script

[script]
ImageDir=$theme_dir
ScriptFile=$theme_dir/dotfiles.script
PLY

  cat > "$theme_dir/dotfiles.script" <<'SCRIPT'
# Simple Plymouth script
image = Image("logo.png");
image.SetPosition(Window.GetX() + Window.GetWidth()/2 - image.GetWidth()/2,
                  Window.GetY() + Window.GetHeight()/2 - image.GetHeight()/2);
SCRIPT

  plymouth-set-default-theme -R dotfiles
  echo "Boot logo installed via Plymouth." 
else
  echo "Plymouth not found. Install plymouth to apply boot logo." >&2
  exit 1
fi
