#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# extract-heic-frames.sh — extract per-frame PNGs from dynamic HEIC wallpapers.
#
# Apple's dynamic HEIC format packs two images (frame 0 = light, frame 1 =
# dark) in one container. DMS's matugen worker reads the wallpaper path from
# ~/.local/state/DankMaterialShell/session.json and feeds it to matugen,
# which calls ImageMagick's heif decoder. On many systems (Arch Linux's
# libheif 1.23 + libde265 1.1 is one) that decoder fails to decompress
# Apple's dynamic HEIC with:
#
#   Decoder plugin generated an error: Unspecified: Decoding the input
#   data did not give a decompressed image.
#
# Symptom: every `dot theme <family>` for a HEIC-only family produces
# a matugen "Theme worker FATAL" in the dms journal and the dynamic
# color scheme stops regenerating.
#
# Workaround: pre-extract `{family}-0.png` (light) and `{family}-1.png`
# (dark) PNG frames next to each HEIC. wallpaper-sync.sh's resolver
# prefers `{family}-{0,1}.png` over `{family}.heic`, so DMS gets the
# decodable PNG instead of the broken HEIC.
#
# We use libheif's `heif-dec -d ffmpeg` because libde265 fails where
# the bundled ffmpeg decoder succeeds for the same input.
#
# Usage:
#   bash scripts/theme/extract-heic-frames.sh                 # all HEICs in default dir
#   bash scripts/theme/extract-heic-frames.sh --force         # re-extract even if PNGs exist
#   bash scripts/theme/extract-heic-frames.sh --dry-run       # show what would extract
#   DOTFILES_WALLPAPER_DIR=/path bash scripts/.../extract-heic-frames.sh

set -euo pipefail

WALLPAPER_DIR="${DOTFILES_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
FORCE=0
DRY_RUN=0

for arg in "$@"; do
  case "$arg" in
    --force | -f) FORCE=1 ;;
    --dry-run | -n) DRY_RUN=1 ;;
    --help | -h)
      sed -n '4,30p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

if [[ ! -d "$WALLPAPER_DIR" ]]; then
  echo "Wallpaper dir not found: $WALLPAPER_DIR" >&2
  exit 1
fi

for cmd in magick heif-dec; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "Required: $cmd (install ImageMagick + libheif-tools)" >&2
    exit 1
  fi
done

cd "$WALLPAPER_DIR"

extracted=0
skipped=0
single=0
failed=()
tmp_prefix="$(mktemp -d)/heic"

trap 'rm -rf "$(dirname "$tmp_prefix")"' EXIT

for f in *.heic; do
  [[ -e "$f" ]] || continue
  name="${f%.heic}"

  if [[ $FORCE -eq 0 && -f "${name}-0.png" && -f "${name}-1.png" ]]; then
    ((skipped++)) || true
    continue
  fi

  frames=$(magick identify "$f" 2>/dev/null | wc -l | tr -d ' ')
  if [[ "$frames" -lt 2 ]]; then
    ((single++)) || true
    continue
  fi

  if [[ $DRY_RUN -eq 1 ]]; then
    echo "would extract: $name (frames=$frames)"
    continue
  fi

  if heif-dec -d ffmpeg "$f" "${tmp_prefix}-${name}.png" >/dev/null 2>&1 &&
    [[ -f "${tmp_prefix}-${name}-1.png" && -f "${tmp_prefix}-${name}-2.png" ]]; then
    # heif-dec writes 1-indexed (-1, -2). Our convention is 0-indexed:
    # light = frame 0, dark = frame 1.
    mv "${tmp_prefix}-${name}-1.png" "${name}-0.png"
    mv "${tmp_prefix}-${name}-2.png" "${name}-1.png"
    ((extracted++)) || true
    echo "  + $name"
  else
    failed+=("$name")
  fi
done

echo "---"
echo "extracted: $extracted  skipped (already have PNGs): $skipped  single-frame: $single  failed: ${#failed[@]}"
if [[ ${#failed[@]} -gt 0 ]]; then
  printf '  ! %s\n' "${failed[@]}"
  exit 1
fi
