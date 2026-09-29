#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
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

# This script relies on associative arrays (`declare -A`) and `wait -n`,
# both of which need bash >= 4. macOS ships /bin/bash 3.2, where it would
# otherwise fail with cryptic "invalid option" / "bad array subscript"
# errors mid-run. Re-exec under a newer bash when one is available
# (Homebrew, MacPorts, mise), and fail with a clear, actionable message
# otherwise rather than corrupting a half-built themes.toml.
_rt_require_bash4() {
  local newer
  ((BASH_VERSINFO[0] < 4)) || return 0
  for newer in \
    /opt/homebrew/bin/bash \
    /usr/local/bin/bash \
    "${HOMEBREW_PREFIX:-}/bin/bash" \
    "$(command -v bash 2>/dev/null || true)"; do
    if [[ -n "$newer" && -x "$newer" ]] && # mutation: ignore bash < 4 only; CI runs bash 5, so this line never executes there
      "$newer" -c '((BASH_VERSINFO[0] >= 4))' 2>/dev/null; then
      exec "$newer" "$0" "$@"
    fi
  done
  echo "Error: 'dot theme rebuild' needs bash >= 4 (macOS ships bash 3.2)." >&2
  echo "       Install a newer bash and retry:  brew install bash" >&2
  exit 1
}
_rt_require_bash4 "$@"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTRACT_SCRIPT="$SCRIPT_DIR/extract-theme.py"
DOTFILES_DIR="${HOME}/.dotfiles"

# Descend into the chezmoi source subdir when .chezmoiroot is present (post-reorg, chezmoi files under defaults/)
CHEZMOI_SRC="$DOTFILES_DIR"
if [[ -f "$DOTFILES_DIR/.chezmoiroot" ]]; then
  _sub="$(head -1 "$DOTFILES_DIR/.chezmoiroot" | tr -d '[:space:]')"
  [[ -n "$_sub" && -d "$DOTFILES_DIR/$_sub" ]] && CHEZMOI_SRC="$DOTFILES_DIR/$_sub"
fi
THEMES_FILE="$CHEZMOI_SRC/.chezmoidata/themes.toml"
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

# Explicit empty init: with no wallpapers at all, ${#WALLPAPERS[@]} on a
# never-assigned `declare -A` trips `set -u` and the rebuild died before
# writing the fallback themes.
declare -A WALLPAPERS=() # name -> path (custom overrides system)
declare -A WP_SOURCE=()  # name -> "system" | "custom"

# _rt_register <name> <path> <source>: add or replace a wallpaper.
_rt_register() {
  WALLPAPERS["$1"]="$2"
  WP_SOURCE["$1"]="$3"
}

# _rt_register_new <name> <path> <source>: add it unless already known.
_rt_register_new() {
  if [[ -z "${WALLPAPERS[$1]+x}" ]]; then
    _rt_register "$@"
  fi
}

_rt_forget() {
  unset "WALLPAPERS[$1]"
  unset "WP_SOURCE[$1]"
}

# macOS system names: lowercase, spaces to dashes, [a-z0-9-] only.
_rt_mac_name() {
  local name
  name="$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
  printf '%s' "${name//[^a-z0-9-]/}"
}

# Normalize to the [a-z0-9-] namespace that themes.toml and the
# `dot theme list` picker regex both require — a raw name with
# spaces/uppercase would generate a section the picker can't match.
_rt_normalize_name() {
  local name
  name="$(echo "$1" | tr '[:upper:]' '[:lower:]' | tr ' _' '--')"
  name="${name//[^a-z0-9-]/}"
  while [[ "$name" == *--* ]]; do name="${name//--/-}"; done
  name="${name#-}"
  printf '%s' "${name%-}"
}

# Remove base wallpapers that have explicit dark/light variants
# e.g. if "big-sur-graphic-dark" exists, remove "big-sur-graphic"
_rt_mac_drop_bases() {
  local name dark light
  for name in "${!WALLPAPERS[@]}"; do
    [[ "${name}" != *-dark && "${name}" != *-light ]] || continue
    dark="${name}-dark" light="${name}-light"
    if [[ -n "${WALLPAPERS[$dark]+x}" || -n "${WALLPAPERS[$light]+x}" ]]; then
      _rt_forget "$name"
    fi
  done
}

discover_macos_system() {
  local sys_dir="${DOTFILES_THEME_SYSTEM_ROOT:-}/System/Library/Desktop Pictures"
  [[ -d "$sys_dir" ]] || return 0

  # Register top-level system wallpapers (will be deduped later if thumbnails have dark/light)
  local file
  for file in "$sys_dir"/*.heic; do
    [[ -f "$file" ]] || continue
    _rt_register "$(_rt_mac_name "$(basename "$file" .heic)")" "$file" system
  done

  # Also check .thumbnails for wallpapers with Dark/Light variants
  local thumb_dir="$sys_dir/.thumbnails"
  [[ -d "$thumb_dir" ]] || return 0
  for file in "$thumb_dir"/*.heic; do
    [[ -f "$file" ]] || continue
    _rt_register_new "$(_rt_mac_name "$(basename "$file" .heic)")" "$file" system
  done
  _rt_mac_drop_bases
}

# One Linux system image. Static system images carry no mode; theme them
# in both modes so they show as a pair (unless the file is already a
# -dark/-light).
_rt_linux_file() {
  local file="$1" name base variant
  base="$(basename "$file")"
  name="$(_rt_normalize_name "${base%.*}")"
  [[ -n "$name" ]] || return 0
  if [[ "$name" == *-dark || "$name" == *-light ]]; then
    _rt_register_new "$name" "$file" system
    return 0
  fi
  for variant in dark light; do
    _rt_register_new "${name}-${variant}" "$file" system
  done
}

discover_linux_system() {
  local dir file
  for dir in "${DOTFILES_THEME_SYSTEM_ROOT:-}"/usr/share/{backgrounds,wallpapers}; do
    [[ -d "$dir" ]] || continue
    while IFS= read -r file; do
      _rt_linux_file "$file"
    done < <(find "$dir" -maxdepth 3 -type f \
      \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
      -o -iname '*.heic' -o -iname '*.webp' -o -iname '*.tiff' \) 2>/dev/null | sort)
  done
}

# Dynamic HEIC (multi-frame = light+dark packed in one file): register both
# frames plus the original file (for wallpaper-sync). Sets _rt_dynamic=1
# when <file> is one (not via the status, so errexit still applies here).
_rt_custom_dynamic() {
  local file="$1" name="$2" frame_count
  _rt_dynamic=0
  [[ "$(echo "${file##*.}" | tr '[:upper:]' '[:lower:]')" == "heic" ]] || return 0
  # No magick: treat it as one frame. _rt_check_deps reports the missing
  # tool before any rebuild (under pipefail + errexit the identify pipeline
  # used to end the run with a bare 127), and --list needs no magick.
  command -v magick >/dev/null 2>&1 || return 0
  frame_count="$(magick identify "$file" 2>/dev/null | wc -l | tr -d ' ')"
  [[ "$frame_count" -ge 2 && "$name" != *-dark && "$name" != *-light ]] || return 0
  _rt_register "${name}-light" "${file}[0]" custom
  _rt_register "${name}-dark" "${file}[1]" custom
  _rt_register "$name" "$file" custom-dynamic
  _rt_dynamic=1
}

_rt_custom_file() {
  local file="$1" base name
  [[ -f "$file" ]] || return 0
  base="$(basename "$file")"
  name="$(_rt_normalize_name "${base%.*}")"
  [[ -n "$name" ]] || return 0
  _rt_custom_dynamic "$file" "$name"
  [[ "$_rt_dynamic" == 0 ]] || return 0

  # Explicitly-named single-mode variant (foo-dark.jpg / foo-light.jpg):
  # honour the author's mode, register the one variant as-is.
  if [[ "$name" == *-dark || "$name" == *-light ]]; then
    _rt_register "$name" "$file" custom
    return 0
  fi

  # Static single image: theme it in BOTH modes (extract-theme forces
  # the mode from the -dark/-light suffix) so it appears as a light/dark
  # pair in `dot theme list`. Previously a static produced only one
  # variant and paired_families() hid it entirely.
  _rt_register "${name}-dark" "$file" custom
  _rt_register "${name}-light" "$file" custom
}

discover_custom() {
  [[ -d "$CUSTOM_DIR" ]] || return 0
  local file
  # Case-insensitive, wide extension match. The old fixed-glob loop
  # (`*.heic *.jpg *.png`) silently dropped `.jpeg`, `.webp`, `.tiff`
  # and every uppercase variant (`.JPG`, `.HEIC`, …), so those
  # wallpapers never made it into the theme table.
  while IFS= read -r file; do
    _rt_custom_file "$file"
  done < <(find "$CUSTOM_DIR" -maxdepth 1 -type f \
    \( -iname '*.heic' -o -iname '*.jpg' -o -iname '*.jpeg' \
    -o -iname '*.png' -o -iname '*.webp' -o -iname '*.tiff' \) 2>/dev/null | sort)
}

# Remove dynamic base entries (keep only the -dark/-light variants for theme gen)
cleanup_dynamic_entries() {
  for name in "${!WP_SOURCE[@]}"; do
    if [[ "${WP_SOURCE[$name]}" == "custom-dynamic" ]]; then
      _rt_forget "$name"
    fi
  done
}

# Discover in order: system first, custom overrides. DOTFILES_THEME_SYSTEM_ROOT
# prefixes the system wallpaper paths (a chroot or a test tree). System (OS-shipped)
# wallpapers are opt-in — most users only want themes from their own
# wallpapers. Enable the ~100 built-in ones with DOTFILES_THEME_SYSTEM=1.
_rt_discover() {
  if [[ "${DOTFILES_THEME_SYSTEM:-0}" == "1" ]]; then
    case "$(uname -s)" in
      Darwin) discover_macos_system ;;
      Linux) discover_linux_system ;;
    esac
  fi
  discover_custom
  cleanup_dynamic_entries
}

_rt_sorted_names() { printf '%s\n' "${!WALLPAPERS[@]}" | sort; }

# ---------------------------------------------------------------------------
# List mode
# ---------------------------------------------------------------------------
_rt_list() {
  local name
  printf '%-40s %-8s %s\n' "NAME" "SOURCE" "PATH"
  printf '%-40s %-8s %s\n' "----" "------" "----"
  for name in $(_rt_sorted_names); do
    printf '%-40s %-8s %s\n' "$name" "${WP_SOURCE[$name]}" "${WALLPAPERS[$name]}"
  done
  echo ""
  echo "Total: ${#WALLPAPERS[@]} wallpapers"
}

# ---------------------------------------------------------------------------
# Check dependencies
# ---------------------------------------------------------------------------
_rt_check_deps() {
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
}

# ---------------------------------------------------------------------------
# Invalidate the cache when the generator itself changes
#
# A cache entry is only valid for the extract-theme.py that produced it, but
# the freshness check below compares the entry against its *wallpaper* alone.
# So a wallpaper that never changes keeps serving whatever the generator
# emitted the first time, indefinitely — while every other theme silently
# moves on.
#
# That is not hypothetical: catalina and sonoma shipped in themes.toml with
# blocks generated in June/July, months after the rest. They carried an
# absolute /Users/<name>/ wallpaper path (predating the `~/` normalisation)
# and a c15 of #181818 in a *light* theme (predating the structural-ramp fix),
# which failed the WCAG AAA gate in CI. Two real defects, both invisible here
# because those two wallpapers had simply not been touched since.
#
# Keyed on the generator's CONTENT, not its mtime: `git checkout` rewrites
# mtimes without changing behaviour, and mtime alone would force a full
# rebuild of every theme on each checkout.
generator_digest() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    # No digest tool: fall back to always regenerating rather than risk
    # serving stale blocks. Correctness over speed.
    echo "no-digest-tool-$(date +%s)"
  fi
}

# Sets GENERATOR_STAMP / GENERATOR_HASH / GENERATOR_STALE.
_rt_generator_state() {
  GENERATOR_STAMP="$CACHE_DIR/.extract-theme.sha256"
  GENERATOR_HASH="$(generator_digest "$EXTRACT_SCRIPT")"
  # extract-theme.py imports aaa.py for its final AAA pass; an edit there
  # changes every generated palette just as much.
  if [[ -f "$SCRIPT_DIR/aaa.py" ]]; then
    GENERATOR_HASH="$GENERATOR_HASH:$(generator_digest "$SCRIPT_DIR/aaa.py")"
  fi
  GENERATOR_STALE=false
  if [[ ! -f "$GENERATOR_STAMP" || "$(cat "$GENERATOR_STAMP")" != "$GENERATOR_HASH" ]]; then
    GENERATOR_STALE=true
    echo "Generator changed since the cache was written — rebuilding all themes."
  fi
}

# Clean orphaned cache files (wallpapers that no longer exist)
_rt_clean_orphans() {
  local cache_file
  for cache_file in "$CACHE_DIR"/*.toml; do
    [[ -f "$cache_file" ]] || continue
    if [[ -z "${WALLPAPERS[$(basename "$cache_file" .toml)]+x}" ]]; then
      rm -f "$cache_file"
    fi
  done
}

# ---------------------------------------------------------------------------
# Generate themes
# ---------------------------------------------------------------------------

# Report distinct WALLPAPERS (families), not theme sections. Every
# wallpaper — a dynamic HEIC (light+dark frames) or a static image —
# yields a `-light` and a `-dark` theme, so a raw section count is ~2x
# the file count and reads as wrong ("74 files → 148 custom"). Collapse
# -dark/-light back to the family so the numbers match what's on disk
# and what `dot theme list` shows, and report the theme total separately.
# Explicit empty init: a `declare -A x` that never gets a key still trips
# `set -u` on ${#x[@]} (even in bash 5) — happens now that system wallpapers
# are opt-in and sys_fam can stay empty.
_rt_report_discovery() {
  local name family sys_count cust_count
  local -A sys_fam=() cust_fam=()
  for name in "${!WP_SOURCE[@]}"; do
    family="${name%-dark}"
    family="${family%-light}"
    case "${WP_SOURCE[$name]}" in
      system) sys_fam["$family"]=1 ;;
      custom) cust_fam["$family"]=1 ;;
    esac
  done
  sys_count=${#sys_fam[@]}
  cust_count=${#cust_fam[@]}
  echo "Discovering wallpapers..."
  echo "  Found: $sys_count system, $cust_count custom wallpapers" \
    "($((sys_count + cust_count)) total → ${#WALLPAPERS[@]} light/dark themes)"
  echo ""
}

# Build the work list (skipping entries whose cache is fresh); sets WORK
# and CACHED.
_rt_build_work() {
  local name wp_path cache_file
  WORK=()
  CACHED=0
  for name in $(_rt_sorted_names); do
    [[ -n "${WALLPAPERS[$name]+x}" ]] || continue
    wp_path="${WALLPAPERS[$name]}"
    cache_file="$CACHE_DIR/${name}.toml"
    if [[ "$FORCE" != "true" && "$GENERATOR_STALE" != "true" &&
      -f "$cache_file" && "$cache_file" -nt "$wp_path" ]]; then
      CACHED=$((CACHED + 1))
      continue
    fi
    WORK+=("$name")
  done
}

# _rt_extract <name>: generate one cache entry (run in the background).
_rt_extract() {
  local name="$1" wp_path="${WALLPAPERS[$1]}" source_type="${WP_SOURCE[$1]}"
  local cache_file="$CACHE_DIR/${name}.toml"
  if python3 "$EXTRACT_SCRIPT" "$wp_path" --name "$name" --source "$source_type" >"$cache_file" 2>/dev/null; then
    printf "  %-40s [%s] ✓\n" "$name" "$source_type"
  else
    rm -f "$cache_file"
    printf "  %-40s [%s] ✗\n" "$name" "$source_type"
  fi
}

# Process in parallel (up to 4 jobs)
_rt_run_work() {
  local name jobs=4
  [[ ${#WORK[@]} -gt 0 ]] || return 0
  echo "  Processing ${#WORK[@]} wallpapers ($jobs parallel jobs)..."
  for name in "${WORK[@]}"; do
    _rt_extract "$name" &
    # Limit parallel jobs (bash >= 4 guaranteed by the guard at the top).
    while [[ $(jobs -r | wc -l) -ge $jobs ]]; do
      wait -n 2>/dev/null || true
    done
  done
  wait
}

# Count results — how many of THIS run's work items produced a cache file.
# (The old `find -newer "$0"` counted every cache file newer than the script,
# so when everything was cached FAILED went negative.)
_rt_count_results() {
  local name generated=0 failed=0
  for name in "${WORK[@]}"; do
    if [[ -f "$CACHE_DIR/${name}.toml" ]]; then
      generated=$((generated + 1))
    else
      failed=$((failed + 1))
    fi
  done
  echo ""
  echo "Results: $generated generated, $CACHED cached, $failed failed"
}

# ---------------------------------------------------------------------------
# Assemble themes.toml
# ---------------------------------------------------------------------------

# Synthetic fallback themes — always emitted, never wallpaper-derived.
# Every theme template degrades to `fallback-dark` when `.theme` is unset or
# names a theme absent from this file. Because these are re-emitted on every
# rebuild, a regeneration that drops any wallpaper theme can never break the
# fallback (unlike hardcoding a wallpaper theme like the old big-sur-dark).
# switch.sh hides the `fallback` family from user-facing theme lists.
# The blocks live in fallback-themes.toml, next to this script.
_rt_fallback_themes() {
  cat "$SCRIPT_DIR/fallback-themes.toml"
}

_rt_assemble() {
  local name cache_file
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

    # Assemble ONLY the wallpapers discovered this run, not every file left in
    # the cache. This drops themes for wallpapers no longer present (e.g. system
    # wallpapers once DOTFILES_THEME_SYSTEM is turned off) instead of letting
    # stale cache entries pile up in themes.toml.
    for name in $(_rt_sorted_names); do
      cache_file="$CACHE_DIR/${name}.toml"
      [[ -f "$cache_file" ]] || continue
      echo ""
      cat "$cache_file"
    done
    _rt_fallback_themes
  } >"$THEMES_FILE"
}

_rt_main() {
  _rt_discover
  if [[ "$LIST_ONLY" == "true" ]]; then
    _rt_list
    exit 0
  fi
  _rt_check_deps
  mkdir -p "$CACHE_DIR"
  _rt_generator_state
  _rt_clean_orphans
  _rt_report_discovery
  echo "Generating themes..."
  _rt_build_work
  _rt_run_work
  _rt_count_results

  echo ""
  echo "Assembling themes.toml..."
  _rt_assemble
  # Count top-level [themes.NAME] blocks only — not the .term/.ui/.app
  # subsections (which inflated the tally ~4x).
  local theme_count
  theme_count=$(grep -cE '^\[themes\.[a-z0-9-]+\]$' "$THEMES_FILE")
  echo "  Written: $THEMES_FILE ($theme_count themes)"

  # Record which generator produced this cache. Written only now, after the
  # file has been assembled: stamping earlier would mark the cache current
  # even if the run died partway, so the next run would trust
  # half-regenerated blocks.
  printf '%s\n' "$GENERATOR_HASH" >"$GENERATOR_STAMP"
  echo ""
  echo "Done. Run 'dot theme list' to see available themes."
}

_rt_main
