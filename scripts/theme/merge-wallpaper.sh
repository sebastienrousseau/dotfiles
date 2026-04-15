#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# merge-wallpaper.sh — Merge dark+light wallpapers into a single dynamic HEIC.
#
# Creates an Apple-compatible dynamic HEIC with appearance metadata so macOS
# automatically shows the correct variant based on Light/Dark mode.
#
# Usage:
#   bash merge-wallpaper.sh                  # Merge all pairs in ~/Pictures/Wallpapers/
#   bash merge-wallpaper.sh <family>         # Merge a specific family (e.g. macos-tahoe)
#   bash merge-wallpaper.sh --dry-run        # Show what would be merged
set -euo pipefail

WALLPAPER_DIR="${DOTFILES_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
DRY_RUN=false
TARGET=""

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --help | -h)
      echo "Usage: merge-wallpaper.sh [--dry-run] [family-name]"
      echo ""
      echo "Merges *-dark.heic + *-light.heic into a single dynamic HEIC"
      echo "that switches appearance automatically on macOS."
      exit 0
      ;;
    *) TARGET="$arg" ;;
  esac
done

if ! command -v heif-enc &>/dev/null; then
  echo "Error: heif-enc required (brew install libheif)" >&2
  exit 1
fi

if ! command -v magick &>/dev/null; then
  echo "Error: ImageMagick (magick) required" >&2
  exit 1
fi

# Generate the Apple desktop appearance XMP metadata.
# Format: bplist with {l: 0, d: 1} meaning image 0 = light, image 1 = dark.
generate_xmp() {
  local apr_b64="YnBsaXN0MDDSAQIDBFFsUWQQABABCA0PERMAAAAAAAABAQAAAAAAAAAFAAAAAAAAAAAAAAAAAAAAFQ=="
  cat <<XMPEOF
<?xpacket begin="" id="W5M0MpCehiHzreSzNTczkc9d"?>
<x:xmpmeta xmlns:x="adobe:ns:meta/" x:xmptk="dotfiles">
  <rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#">
    <rdf:Description rdf:about=""
      xmlns:apple_desktop="http://ns.apple.com/namespace/1.0/"
      apple_desktop:apr="${apr_b64}"/>
  </rdf:RDF>
</x:xmpmeta>
<?xpacket end="w"?>
XMPEOF
}

merge_pair() {
  local family="$1"
  local dark_file=""
  local light_file=""

  # Find dark and light files
  for ext in heic jpg png; do
    [[ -z "$dark_file" && -f "$WALLPAPER_DIR/${family}-dark.${ext}" ]] && dark_file="$WALLPAPER_DIR/${family}-dark.${ext}"
    [[ -z "$light_file" && -f "$WALLPAPER_DIR/${family}-light.${ext}" ]] && light_file="$WALLPAPER_DIR/${family}-light.${ext}"
  done

  if [[ -z "$dark_file" || -z "$light_file" ]]; then
    echo "  ✗  $family — missing dark or light variant"
    return 1
  fi

  local output="$WALLPAPER_DIR/${family}.heic"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "  ○  $family — would merge $(basename "$light_file") + $(basename "$dark_file") → $(basename "$output")"
    return 0
  fi

  local tmpdir
  tmpdir="$(mktemp -d)"
  trap "rm -rf '$tmpdir'" RETURN

  # Convert both to JPEG for heif-enc input (it handles JPEG best)
  magick "$light_file" -quality 95 "$tmpdir/light.jpg" 2>/dev/null
  magick "$dark_file" -quality 95 "$tmpdir/dark.jpg" 2>/dev/null

  # Generate XMP metadata file
  generate_xmp >"$tmpdir/xmp.xml"

  # Encode as multi-image HEIC: image 0 = light (primary), image 1 = dark
  if heif-enc \
    -q 90 \
    "$tmpdir/light.jpg" \
    "$tmpdir/dark.jpg" \
    -o "$tmpdir/merged.heic" 2>/dev/null; then

    # Inject Apple desktop appearance XMP
    if command -v exiftool &>/dev/null; then
      exiftool -overwrite_original -XMP="<=$tmpdir/xmp.xml" "$tmpdir/merged.heic" 2>/dev/null || true
    fi

    # Replace the pair with the merged file
    mv "$tmpdir/merged.heic" "$output"
    rm -f "$dark_file" "$light_file"
    echo "  ✓  $family — merged → $(basename "$output")"
    return 0
  else
    echo "  ✗  $family — heif-enc failed"
    return 1
  fi
}

echo "Dynamic wallpaper merger"
echo ""

if [[ -n "$TARGET" ]]; then
  merge_pair "$TARGET"
else
  # Find all families with dark+light pairs
  merged=0
  failed=0
  for dark_file in "$WALLPAPER_DIR"/*-dark.heic "$WALLPAPER_DIR"/*-dark.jpg "$WALLPAPER_DIR"/*-dark.png; do
    [[ -f "$dark_file" ]] || continue
    base="$(basename "$dark_file")"
    family="${base%-dark.*}"
    if merge_pair "$family"; then
      merged=$((merged + 1))
    else
      failed=$((failed + 1))
    fi
  done
  echo ""
  echo "Done: $merged merged, $failed failed"
  if [[ "$DRY_RUN" != "true" && $merged -gt 0 ]]; then
    echo ""
    echo "Run 'dot theme rebuild --force' to regenerate themes for merged wallpapers."
  fi
fi
