#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: patch-fonts.sh <font-file> [output-dir]" >&2
  exit 1
fi

font_file="$1"
out_dir="${2:-$PWD/patched-fonts}"

if [[ ! -f "$font_file" ]]; then
  echo "Font not found: $font_file" >&2
  exit 1
fi

if ! command -v fontforge >/dev/null; then
  echo "fontforge not found. Install it first (brew install fontforge / apt install fontforge)." >&2
  exit 1
fi

patcher="${NERD_FONTS_PATCHER:-$HOME/.local/share/nerd-fonts/font-patcher}"

if [[ ! -x "$patcher" ]]; then
  echo "Nerd Fonts patcher not found: $patcher" >&2
  echo "Set NERD_FONTS_PATCHER to the font-patcher path or clone nerd-fonts." >&2
  exit 1
fi

mkdir -p "$out_dir"

fontforge -script "$patcher" --complete --outputdir "$out_dir" "$font_file"

echo "Patched font written to: $out_dir"
