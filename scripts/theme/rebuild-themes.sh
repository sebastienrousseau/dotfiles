#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# rebuild-themes.sh — Discover wallpapers and generate themes.toml dynamically.
#
# Scans system wallpaper directories and ~/Pictures/Wallpapers/ for images,
# extracts dominant colors via extract-theme.py, and assembles themes.toml.
# Custom wallpapers override system wallpapers with the same name.
#
# Usage:
#   bash rebuild-themes.sh              # Rebuild themes.toml
#   bash rebuild-themes.sh --force      # Force regeneration (ignore cache)
#   bash rebuild-themes.sh --list       # List discovered wallpapers without rebuilding
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACT_SCRIPT="$SCRIPT_DIR/extract-theme.py"
DOTFILES_DIR="${HOME}/.dotfiles"
THEMES_FILE="$DOTFILES_DIR/.chezmoidata/themes.toml"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/themes"
CUSTOM_DIR="${DOTFILES_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"

FORCE=false
LIST_ONLY=false

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --list) LIST_ONLY=true ;;
  esac
done

# ---------------------------------------------------------------------------
# Discover wallpapers from all sources
# ---------------------------------------------------------------------------

declare -A WALLPAPERS # name -> path (custom overrides system)
declare -A WP_SOURCE  # name -> "system" | "custom"

discover_macos_system() {
  local sys_dir="/System/Library/Desktop Pictures"
  [[ -d "$sys_dir" ]] || return 0

  # Register top-level system wallpapers (will be deduped later if thumbnails have dark/light)
  local file name
  for file in "$sys_dir"/*.heic; do
    [[ -f "$file" ]] || continue
    name="$(basename "$file" .heic)"
    name="$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
    name="${name//[^a-z0-9-]/}"
    WALLPAPERS["$name"]="$file"
    WP_SOURCE["$name"]="system"
  done

  # Also check .thumbnails for wallpapers with Dark/Light variants
  local thumb_dir="$sys_dir/.thumbnails"
  if [[ -d "$thumb_dir" ]]; then
    # First pass: register all thumbnails
    for file in "$thumb_dir"/*.heic; do
      [[ -f "$file" ]] || continue
      local base
      base="$(basename "$file" .heic)"
      name="$(echo "$base" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
      name="${name//[^a-z0-9-]/}"
      if [[ -z "${WALLPAPERS[$name]+x}" ]]; then
        WALLPAPERS["$name"]="$file"
        WP_SOURCE["$name"]="system"
      fi
    done

    # Second pass: remove base wallpapers that have explicit dark/light variants
    # e.g. if "big-sur-graphic-dark" exists, remove "big-sur-graphic"
    local check_name
    for name in "${!WALLPAPERS[@]}"; do
      if [[ "${name}" != *-dark && "${name}" != *-light ]]; then
        check_name="${name}-dark"
        if [[ -n "${WALLPAPERS[$check_name]+x}" ]]; then
          unset "WALLPAPERS[$name]"
          unset "WP_SOURCE[$name]"
          continue
        fi
        check_name="${name}-light"
        if [[ -n "${WALLPAPERS[$check_name]+x}" ]]; then
          unset "WALLPAPERS[$name]"
          unset "WP_SOURCE[$name]"
        fi
      fi
    done
  fi
}

discover_linux_system() {
  local dirs=(
    /usr/share/backgrounds
    /usr/share/wallpapers
  )

  local dir file name
  for dir in "${dirs[@]}"; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r file; do
      name="$(basename "$file")"
      name="${name%.*}"
      name="$(echo "$name" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
      name="${name//[^a-z0-9-]/}"
      # Avoid duplicates — first found wins for system
      if [[ -z "${WALLPAPERS[$name]+x}" ]]; then
        WALLPAPERS["$name"]="$file"
        WP_SOURCE["$name"]="system"
      fi
    done < <(find "$dir" -maxdepth 3 -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.heic" \) 2>/dev/null | sort)
  done
}

discover_custom() {
  [[ -d "$CUSTOM_DIR" ]] || return 0

  local file name frame_count
  for file in "$CUSTOM_DIR"/*.heic "$CUSTOM_DIR"/*.jpg "$CUSTOM_DIR"/*.png; do
    [[ -f "$file" ]] || continue
    name="$(basename "$file")"
    name="${name%.*}"

    # Check if this is a dynamic HEIC (multi-frame = light+dark in one file)
    if [[ "${file##*.}" == "heic" ]]; then
      frame_count="$(magick identify "$file" 2>/dev/null | wc -l | tr -d ' ')"
      if [[ "$frame_count" -ge 2 && "$name" != *-dark && "$name" != *-light ]]; then
        # Dynamic HEIC: register as both dark and light
        WALLPAPERS["${name}-light"]="$file[0]"
        WP_SOURCE["${name}-light"]="custom"
        WALLPAPERS["${name}-dark"]="$file[1]"
        WP_SOURCE["${name}-dark"]="custom"
        # Store the original file path for wallpaper-sync
        WALLPAPERS["${name}"]="$file"
        WP_SOURCE["${name}"]="custom-dynamic"
        continue
      fi
    fi

    WALLPAPERS["$name"]="$file"
    WP_SOURCE["$name"]="custom"
  done
}

# Remove dynamic base entries (keep only the -dark/-light variants for theme gen)
cleanup_dynamic_entries() {
  for name in "${!WP_SOURCE[@]}"; do
    if [[ "${WP_SOURCE[$name]}" == "custom-dynamic" ]]; then
      unset "WALLPAPERS[$name]"
      unset "WP_SOURCE[$name]"
    fi
  done
}

# Discover in order: system first, custom overrides
case "$(uname -s)" in
  Darwin) discover_macos_system ;;
  Linux) discover_linux_system ;;
esac
discover_custom
cleanup_dynamic_entries

# ---------------------------------------------------------------------------
# List mode
# ---------------------------------------------------------------------------

if [[ "$LIST_ONLY" == "true" ]]; then
  printf '%-40s %-8s %s\n' "NAME" "SOURCE" "PATH"
  printf '%-40s %-8s %s\n' "----" "------" "----"
  for name in $(printf '%s\n' "${!WALLPAPERS[@]}" | sort); do
    printf '%-40s %-8s %s\n' "$name" "${WP_SOURCE[$name]}" "${WALLPAPERS[$name]}"
  done
  echo ""
  echo "Total: ${#WALLPAPERS[@]} wallpapers"
  exit 0
fi

# ---------------------------------------------------------------------------
# Check dependencies
# ---------------------------------------------------------------------------

if [[ ! -f "$EXTRACT_SCRIPT" ]]; then
  echo "Error: extract-theme.py not found at $EXTRACT_SCRIPT" >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "Error: python3 required" >&2
  exit 1
fi

if ! command -v magick &>/dev/null; then
  echo "Error: ImageMagick (magick) required" >&2
  exit 1
fi

mkdir -p "$CACHE_DIR"

# Clean orphaned cache files (wallpapers that no longer exist)
for cache_file in "$CACHE_DIR"/*.toml; do
  [[ -f "$cache_file" ]] || continue
  cached_name="$(basename "$cache_file" .toml)"
  if [[ -z "${WALLPAPERS[$cached_name]+x}" ]]; then
    rm -f "$cache_file"
  fi
done

# ---------------------------------------------------------------------------
# Generate themes
# ---------------------------------------------------------------------------

sys_count=0
cust_count=0
for name in "${!WP_SOURCE[@]}"; do
  case "${WP_SOURCE[$name]}" in
    system) sys_count=$((sys_count + 1)) ;;
    custom) cust_count=$((cust_count + 1)) ;;
  esac
done
echo "Discovering wallpapers..."
echo "  Found: $sys_count system, $cust_count custom (${#WALLPAPERS[@]} total)"
echo ""

GENERATED=0
CACHED=0
FAILED=0

echo "Generating themes..."

# Build work list (skip cached)
WORK=()
for name in $(printf '%s\n' "${!WALLPAPERS[@]}" | sort); do
  [[ -n "${WALLPAPERS[$name]+x}" ]] || continue
  wp_path="${WALLPAPERS[$name]}"
  cache_file="$CACHE_DIR/${name}.toml"

  if [[ "$FORCE" != "true" && -f "$cache_file" && "$cache_file" -nt "$wp_path" ]]; then
    CACHED=$((CACHED + 1))
    continue
  fi
  WORK+=("$name")
done

# Process in parallel (up to 4 jobs)
JOBS=4
TOTAL_WORK=${#WORK[@]}
if [[ $TOTAL_WORK -gt 0 ]]; then
  echo "  Processing $TOTAL_WORK wallpapers ($JOBS parallel jobs)..."
  for name in "${WORK[@]}"; do
    wp_path="${WALLPAPERS[$name]}"
    cache_file="$CACHE_DIR/${name}.toml"
    source_type="${WP_SOURCE[$name]}"

    (
      if python3 "$EXTRACT_SCRIPT" "$wp_path" --name "$name" --source "$source_type" >"$cache_file" 2>/dev/null; then
        printf "  %-40s [%s] ✓\n" "$name" "$source_type"
      else
        rm -f "$cache_file"
        printf "  %-40s [%s] ✗\n" "$name" "$source_type"
      fi
    ) &

    # Limit parallel jobs
    while [[ $(jobs -r | wc -l) -ge $JOBS ]]; do
      wait -n 2>/dev/null || true
    done
  done
  wait
fi

# Count results
GENERATED=$(find "$CACHE_DIR" -name "*.toml" -newer "$0" 2>/dev/null | wc -l | tr -d ' ')
FAILED=$((TOTAL_WORK - GENERATED))
echo ""
echo "Results: $TOTAL_WORK processed, $CACHED cached, $FAILED failed"

# ---------------------------------------------------------------------------
# Assemble themes.toml
# ---------------------------------------------------------------------------

echo ""
echo "Assembling themes.toml..."

{
  cat <<'HEADER'
# ============================================================================
# Theme Manifest — Auto-generated from wallpaper dominant colors
# ============================================================================
# Generated by: scripts/theme/rebuild-themes.sh
# Algorithm: K-Means clustering in CIELAB color space
# Do not edit manually — run `dot theme rebuild` to regenerate.
#
# Sources:
#   System: /System/Library/Desktop Pictures/ (macOS)
#           /usr/share/backgrounds/ (Linux)
#   Custom: ~/Pictures/Wallpapers/

HEADER

  for cache_file in "$CACHE_DIR"/*.toml; do
    [[ -f "$cache_file" ]] || continue
    echo ""
    cat "$cache_file"
  done
} >"$THEMES_FILE"

theme_count=$(grep -c '^\[themes\.' "$THEMES_FILE" | head -1)
echo "  Written: $THEMES_FILE ($theme_count theme sections)"
echo ""
echo "Done. Run 'dot theme list' to see available themes."
