#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"

ui_init
ui_header "Wallpaper Sync"

WALLPAPER_DIR="${DOTFILES_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
CHEZMOI_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"

# Resolve dotfiles repo root, then descend into chezmoi source subdir if
# .chezmoiroot is present (where chezmoi files live in defaults/)
_DOTFILES_ROOT="${HOME}/.dotfiles"
[[ ! -d "$_DOTFILES_ROOT" && -d "${HOME}/.local/share/chezmoi" ]] && _DOTFILES_ROOT="${HOME}/.local/share/chezmoi"
_CHEZMOI_SRC="$_DOTFILES_ROOT"
if [[ -f "$_DOTFILES_ROOT/.chezmoiroot" ]]; then
  _sub="$(head -1 "$_DOTFILES_ROOT/.chezmoiroot" | tr -d '[:space:]')"
  [[ -n "$_sub" && -d "$_DOTFILES_ROOT/$_sub" ]] && _CHEZMOI_SRC="$_DOTFILES_ROOT/$_sub"
fi
DATA_FILE="${_CHEZMOI_SRC}/.chezmoidata.toml"

WALLPAPER_DIR_EXISTS=true
if [ ! -d "$WALLPAPER_DIR" ]; then
  WALLPAPER_DIR_EXISTS=false
fi

# Detect current color scheme (light/dark)
detect_mode() {
  if command -v dms &>/dev/null; then
    local dms_mode
    dms_mode="$(dms ipc theme getMode 2>/dev/null || true)"
    case "$dms_mode" in
      dark | light)
        echo "$dms_mode"
        return 0
        ;;
    esac
  fi

  if [[ "$(uname -s)" == "Darwin" ]]; then
    # AppleInterfaceStyle is "Dark" in dark mode and unset in light mode.
    if [[ "$(defaults read -g AppleInterfaceStyle 2>/dev/null || true)" == "Dark" ]]; then
      echo "dark"
    else
      echo "light"
    fi
    return 0
  fi

  if command -v gsettings &>/dev/null; then
    local scheme
    scheme="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null || echo "")"
    case "$scheme" in
      *dark*) echo "dark" ;;
      *) echo "light" ;;
    esac
  else
    echo "dark"
  fi
}

current_theme() {
  if [[ -f "$CHEZMOI_CFG" ]]; then
    local chezmoi_theme
    chezmoi_theme="$(awk -F'"' '/^theme =/ {print $2}' "$CHEZMOI_CFG" | head -n 1)"
    if [[ -n "$chezmoi_theme" ]]; then
      printf '%s\n' "$chezmoi_theme"
      return 0
    fi
  fi

  if [[ -f "$DATA_FILE" ]]; then
    awk -F'"' '/^theme =/ {print $2}' "$DATA_FILE" | head -n 1
  fi
}

# _ws_first_existing <path-without-extension> <ext>...: the first existing
# <path>.<ext>, printed; returns 1 when none exists.
_ws_first_existing() {
  local stem="$1" ext
  shift
  for ext in "$@"; do
    if [[ -f "${stem}.${ext}" ]]; then
      printf '%s\n' "${stem}.${ext}"
      return 0
    fi
  done
  return 1
}

# _ws_family <theme>: the theme without its -dark/-light suffix.
_ws_family() {
  local family="${1%-dark}"
  if [[ "$family" == "$1" ]]; then
    family="${1%-light}"
  fi
  printf '%s\n' "$family"
}

# The wallpaper path stored for <theme> in themes.toml (set by
# extract-theme.py), resolved for this machine; returns 1 when there is
# none or it does not exist here.
_ws_stored_wallpaper() {
  local theme="$1" themes_file="${_CHEZMOI_SRC}/.chezmoidata/themes.toml" stored_wp
  [[ -f "$themes_file" ]] || return 1
  stored_wp="$(awk -v n="$theme" '
    $0 == "[themes." n "]" { found=1; next }
    /^\[/ { found=0 }
    found && /^wallpaper/ { sub(/.*= *"/, ""); sub(/".*/, ""); print; exit }
  ' "$themes_file")"
  # Home-relative form (current generator): ~/Pictures/... → $HOME/Pictures/...
  # Prefix-strip comparison avoids a quoted-tilde glob (SC2088); the tilde
  # here is a literal leading character, not a path to expand.
  if [[ "$stored_wp" != "${stored_wp#\~/}" ]]; then
    stored_wp="${HOME}/${stored_wp#\~/}"
  fi
  # Cross-platform: resolve legacy absolute macOS paths on Linux:
  # /Users/<user>/Pictures/... → $HOME/Pictures/... (pre-relativize data).
  # A missing /System/... path (a macOS system wallpaper on Linux) or an
  # empty value falls through to the next lookup via the -f test.
  if [[ ! -f "$stored_wp" && "$stored_wp" == /Users/* ]]; then
    stored_wp="${HOME}/${stored_wp#/Users/*/}"
  fi
  [[ -n "$stored_wp" && -f "$stored_wp" ]] || return 1
  printf '%s\n' "$stored_wp"
}

# Family-only file (e.g. hello.heic — dynamic wallpaper). For HEIC on
# Linux, extract frames first then return the correct one.
_ws_family_only() {
  local family="$1" frame_idx="$2" candidate
  _ws_first_existing "$WALLPAPER_DIR/${family}" png jpg webp && return 0
  candidate="$WALLPAPER_DIR/${family}.heic"
  [[ -f "$candidate" ]] || return 1
  if [[ "$(uname -s)" == "Linux" ]]; then
    # Extract frames from HEIC then return the mode-appropriate one
    ensure_linux_compatible "$candidate" >/dev/null
    # Re-check for extracted frames
    _ws_first_existing "$WALLPAPER_DIR/${family}-${frame_idx}" png jpg
    return
  fi
  printf '%s\n' "$candidate"
}

wallpaper_for_theme() {
  local theme="${1:-}"
  local mode="${2:-}"
  local family frame_idx=0

  [[ -n "$theme" ]] || return 1
  [[ -n "$mode" ]] || return 1
  family="$(_ws_family "$theme")"
  [[ "$mode" == "dark" ]] && frame_idx=1

  # 1. Prefer pre-extracted frames (fast, no conversion needed).
  #    Convention: {family}-0.png = light, {family}-1.png = dark.
  #    These are created externally (e.g. ImageMagick/ffmpeg from dynamic HEIC).
  _ws_first_existing "$WALLPAPER_DIR/${family}-${frame_idx}" png jpg webp && return 0
  # 2. Check exact theme name (e.g. hello-dark.png)
  _ws_first_existing "$WALLPAPER_DIR/${theme}" png jpg webp heic && return 0
  # 3. Check family-mode variant (e.g. hello-dark.png)
  _ws_first_existing "$WALLPAPER_DIR/${family}-${mode}" png jpg webp heic && return 0
  # 4. Check themes.toml stored wallpaper path (set by extract-theme.py)
  _ws_stored_wallpaper "$theme" && return 0
  # 5. Family-only file
  _ws_family_only "$family" "$frame_idx"
}

# macOS: map theme names to Apple system wallpapers.
# A lookup table (not `local -A`) because macOS still ships
# /bin/bash 3.2 which doesn't support associative arrays. Users who
# have brew bash get the same behaviour; first-run users with stock
# bash do too.
_ws_macos_system_wallpaper() {
  local family="$1" sys_mac="${DOTFILES_THEME_SYSTEM_ROOT:-}/System/Library/Desktop Pictures" name
  name="$(
    awk -F'|' -v f="$family" '$1 == f { print $2; exit }' <<'MAP'
macos - sonoma|Sonoma.heic
macos - blue|Mac Blue.heic
macos - pink|Mac Pink.heic
macos - purple|Mac Purple.heic
macos - yellow|Mac Yellow.heic
macos - orange|iMac Orange.heic
macos - green|iMac Green.heic
macos - silver|iMac Silver.heic
MAP
  )"
  [[ -n "$name" && -f "$sys_mac/$name" ]] || return 1
  printf '%s\n' "$sys_mac/$name"
}

# Linux: search system background directories for keyword match
_ws_linux_system_wallpaper() {
  local keyword="${1#macos-}" dir match
  keyword="${keyword%-dark}"
  keyword="${keyword%-light}"
  for dir in "${DOTFILES_THEME_SYSTEM_ROOT:-}"/usr/share/{backgrounds,wallpapers}; do
    [[ -d "$dir" ]] || continue
    match="$(find "$dir" -maxdepth 3 -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) \
      -iname "*${keyword}*" 2>/dev/null | head -1)"
    if [[ -n "$match" ]]; then
      printf '%s\n' "$match"
      return 0
    fi
  done
  return 1
}

# Fallback: find a matching system wallpaper when no custom one exists.
# Maps theme names to platform-native wallpapers shipped with the OS.
# DOTFILES_THEME_SYSTEM_ROOT prefixes the system paths (a chroot or a test
# tree), as in rebuild-themes.sh.
system_wallpaper_for_theme() {
  local theme="${1:-}"
  [[ -n "$theme" ]] || return 1
  if [[ "$(uname -s)" == "Darwin" && -d "${DOTFILES_THEME_SYSTEM_ROOT:-}/System/Library/Desktop Pictures" ]]; then
    _ws_macos_system_wallpaper "$(_ws_family "$theme")" && return 0
  fi
  if [[ "$(uname -s)" == "Linux" ]]; then
    _ws_linux_system_wallpaper "$theme" && return 0
  fi
  return 1
}

theme_wallpaper_pair() {
  local theme="${1:-}"
  local family=""
  local light_wp=""
  local dark_wp=""

  [[ -n "$theme" ]] || return 1
  family="$(_ws_family "$theme")"

  light_wp="$(wallpaper_for_theme "${family}-light" "light" || true)"
  dark_wp="$(wallpaper_for_theme "${family}-dark" "dark" || true)"

  if [[ -n "$light_wp" && -n "$dark_wp" ]]; then
    printf '%s\n%s\n' "$light_wp" "$dark_wp"
    return 0
  fi

  return 1
}

# _ws_find_suffix <suffix> <ext>...: wallpapers named *-<suffix>.<ext>, sorted.
_ws_find_suffix() {
  local suffix="$1" ext
  shift
  local -a expr=()
  for ext in "$@"; do
    [[ ${#expr[@]} -eq 0 ]] || expr+=(-o)
    expr+=(-iname "*-${suffix}.${ext}")
  done
  find "$WALLPAPER_DIR" -maxdepth 1 -type f \( "${expr[@]}" \) | sort
}

# Pick a wallpaper matching the current mode
pick_wallpaper() {
  local mode="$1"
  local theme="${2:-}"
  local files=() matched line frame_suffix=0

  if [[ -n "$theme" ]]; then
    matched="$(wallpaper_for_theme "$theme" "$mode" || true)"
    if [[ -n "$matched" ]]; then
      printf '%s\n' "$matched"
      return 0
    fi
  fi

  while IFS= read -r line; do
    files+=("$line")
  done < <(_ws_find_suffix "$mode" jpg png webp heic)

  # Fallback: search for extracted frames (-0 = light, -1 = dark)
  if [[ ${#files[@]} -eq 0 ]]; then
    [[ "$mode" == "dark" ]] && frame_suffix=1
    while IFS= read -r line; do
      files+=("$line")
    done < <(_ws_find_suffix "$frame_suffix" jpg png webp)
  fi

  if [[ ${#files[@]} -eq 0 ]]; then
    return 1
  fi

  # Pick a random one
  if command -v shuf &>/dev/null; then
    printf '%s\n' "${files[@]}" | shuf -n 1
  else
    echo "${files[$RANDOM % ${#files[@]}]}"
  fi
}

# Use cached PNG only if it exists, is newer than source, and is > 1MB
# (corrupt/truncated conversions produce tiny files that crash matugen).
_ws_cached_png() {
  local wp="$1" png="$2" fsize
  [[ -f "$png" ]] && [[ "$png" -nt "$wp" ]] || return 1
  fsize="$(stat -c%s "$png" 2>/dev/null || stat -f%z "$png" 2>/dev/null || echo 0)"
  [[ "$fsize" -gt 1000000 ]]
}

# _ws_magick_heic <heic> <tmp.png> <png>: convert with ImageMagick.
# Multi-frame HEIC: magick creates {name}-0.png, {name}-1.png etc.; move
# each extracted frame to its final location atomically and print the
# light frame (-0 = light, -1 = dark). Returns 1 when magick fails.
_ws_magick_heic() {
  local wp="$1" tmp_png="$2" png="$3" f suffix
  magick "$wp" -quality 95 "$tmp_png" 2>/dev/null || return 1
  local tmp_base="${tmp_png%.png}"
  local final_base="${png%.png}"
  if [[ ! -f "${tmp_base}-0.png" ]]; then
    mv -f "$tmp_png" "$png" 2>/dev/null
    printf '%s\n' "$png"
    return 0
  fi
  for f in "${tmp_base}"-*.png; do
    suffix="${f#"$tmp_base"}"
    mv -f "$f" "${final_base}${suffix}" 2>/dev/null
  done
  rm -f "$tmp_png" 2>/dev/null
  if [[ -f "${final_base}-0.png" ]]; then
    printf '%s\n' "${final_base}-0.png"
  else
    printf '%s\n' "$png"
  fi
}

# _ws_convert_heic <heic> <tmp.png> <png>: the first available converter;
# returns 1 when none is installed or the one found fails.
_ws_convert_heic() {
  local wp="$1" tmp_png="$2" png="$3" tool
  if command -v magick &>/dev/null; then
    _ws_magick_heic "$@"
    return
  fi
  for tool in heif-convert convert; do
    command -v "$tool" &>/dev/null || continue
    "$tool" "$wp" "$tmp_png" 2>/dev/null || return 1
    mv -f "$tmp_png" "$png" 2>/dev/null
    printf '%s\n' "$png"
    return 0
  done
  return 1
}

# Convert .heic to .png on Linux (HEIC not universally supported)
ensure_linux_compatible() {
  local wp="$1" png tmp_png
  if [[ "$(uname -s)" != "Linux" || "${wp##*.}" != "heic" ]]; then
    printf '%s\n' "$wp"
    return
  fi

  png="${wp%.heic}.png"
  if _ws_cached_png "$wp" "$png"; then
    printf '%s\n' "$png"
    return
  fi

  # Write to temp file then atomic move — prevents DMS/matugen from
  # reading a partially-written PNG during multi-frame HEIC extraction.
  tmp_png="$(mktemp "${png%.png}.XXXXXX.png")"
  _ws_convert_heic "$wp" "$tmp_png" "$png" && return

  rm -f "$tmp_png" 2>/dev/null
  # Fallback: use original and hope the DE supports it
  printf '%s\n' "$wp"
}

# macOS: a dynamic appearance HEIC (two frames + apple_desktop:apr metadata)
# set as a plain imageFile gets pinned to a single frame and stops tracking
# Light/Dark — so Light mode can show the dark frame. Extract the frame that
# matches the requested mode (0 = light, 1 = dark, per Apple's apr convention,
# same as the Linux -0/-1 path) to a small single-image HEIC and apply that
# instead. Single-image HEICs and non-HEICs are returned unchanged.
# _ws_extract_frame <heic> <index> <frame>: print the cached frame when it is
# newer than its source, else extract it; returns 1 when extraction fails.
_ws_extract_frame() {
  local wp="$1" idx="$2" frame="$3" tmp
  # Reuse a cached frame that is newer than its source wallpaper.
  if [[ -f "$frame" && "$frame" -nt "$wp" ]]; then
    printf '%s\n' "$frame"
    return 0
  fi
  tmp="$(mktemp "${frame%.heic}.XXXXXX.heic")"
  if magick "${wp}[${idx}]" "$tmp" 2>/dev/null && [[ -s "$tmp" ]] && mv -f "$tmp" "$frame" 2>/dev/null; then
    printf '%s\n' "$frame"
    return 0
  fi
  rm -f "$tmp" 2>/dev/null
  return 1
}

macos_appearance_frame() {
  local wp="$1" mode="$2" frames idx=0 cache_dir
  if [[ "${wp##*.}" != "heic" ]] || ! command -v magick &>/dev/null; then
    printf '%s\n' "$wp"
    return
  fi
  frames="$(magick identify "$wp" 2>/dev/null | wc -l | tr -d ' ')"
  cache_dir="$WALLPAPER_DIR/.dot-frames"
  if [[ "${frames:-0}" -lt 2 ]] || ! mkdir -p "$cache_dir" 2>/dev/null; then
    printf '%s\n' "$wp"
    return
  fi
  [[ "$mode" == "dark" ]] && idx=1
  _ws_extract_frame "$wp" "$idx" "$cache_dir/$(basename "${wp%.heic}")-${mode}.heic" && return
  printf '%s\n' "$wp"
}

# Restart WallpaperAgent so it re-reads the store and repaints EVERY
# Space (the store rewrite above covers all Spaces; the agent only
# applies it on respawn). Then BLOCK until it's actually back and the
# wallpaper has re-applied — the caller reports "Done" once this returns,
# so it must not return while Spaces are still repainting. Set
# DOT_THEME_SKIP_WALLPAPER_AGENT=1 to skip the restart (faster, but
# background Spaces won't refresh until next login).
_ws_restart_agent() {
  local _waited=0
  [[ "${DOT_THEME_SKIP_WALLPAPER_AGENT:-0}" != "1" ]] || return 0
  killall WallpaperAgent 2>/dev/null || true
  # Wait for launchd to bring WallpaperAgent back (KeepAlive respawns it
  # within ~1s; cap the wait so a theme switch can never hang).
  while ! pgrep -x WallpaperAgent >/dev/null 2>&1; do
    sleep 0.1
    _waited=$((_waited + 1))
    [[ "$_waited" -ge 60 ]] && break
  done
  return 0 # the loop's last test is usually false; that is not a failure
}

# macOS Sonoma+ moved wallpaper state to ~/Library/Application Support/
# com.apple.wallpaper/Store/Index.plist, owned by WallpaperAgent. Each
# Space and Display has its own entry, and AppleScript's `every desktop`
# only sees the active Space — so the only reliable way to cover all
# desktops is to rewrite each entry in Index.plist directly.
#
# The Configuration field of each choice is itself a nested binary plist
# of the form: {type: 'imageFile', url: {relative: 'file:///path'}}
# The store has several shapes: Spaces[uuid].Default.Desktop (per-Space
# wallpaper), Spaces[uuid].Default.Linked (desktop + screensaver share
# one image), and per-display nesting under Spaces[uuid].Displays[uuid].
# Walk the tree and patch any node that holds a wallpaper Choice list.
# After updating, killall WallpaperAgent so launchd respawns it and it
# re-reads the store.
# The store rewrite lives in macos-wallpaper-store.py.
_ws_apply_macos() {
  local wp="$1" mode="$2"
  # Resolve a dynamic HEIC down to the mode-appropriate static frame so
  # macOS renders the right appearance instead of pinning one frame.
  wp="$(macos_appearance_frame "$wp" "$mode")"
  python3 "$SCRIPT_DIR/macos-wallpaper-store.py" "$wp" 2>/dev/null || true
  _ws_restart_agent

  # Re-assert the wallpaper through the (now running) agent — covers the
  # active Space's first paint and any screen the store rewrite missed —
  # then give that paint a moment to finish before returning.
  if command -v wallpaper &>/dev/null; then
    wallpaper set "$wp" --screen all 2>/dev/null || true
  else
    osascript -e "
tell application \"System Events\"
    set theFile to POSIX file \"${wp}\"
    repeat with d in (get every desktop)
        set picture of d to theFile
    end repeat
end tell" 2>/dev/null || true
  fi
  sleep 0.5
}

# DMS owns wallpaper display and runs matugen for color extraction.
# Set the wallpaper ONCE for the current mode — DMS handles the rest.
# Multiple IPC calls (pair-setting, mode switching) cause matugen
# worker crashes and slow transitions. Keep it simple.
_ws_apply_dms() {
  local wp="$1" dms_result current_outputs output
  command -v dms &>/dev/null || return 0
  dms_result="$(dms ipc wallpaper set "$wp" 2>/dev/null || true)"
  if [[ "$dms_result" == SUCCESS:* ]]; then
    ui_info "Applied via" "dms ipc"
  elif [[ "$dms_result" == ERROR:\ Per-monitor\ mode\ enabled* ]]; then
    current_outputs="$(dms ipc outputs current 2>/dev/null | tr -d '[]"')"
    for output in ${current_outputs//,/ }; do
      [[ -n "$output" ]] || continue
      dms ipc wallpaper setFor "$output" "$wp" >/dev/null 2>&1 || true
    done
    ui_info "Applied via" "dms ipc (per-monitor)"
  fi
}

# Find the matching pair for picture-uri and picture-uri-dark; sets the
# caller's light_wp / dark_wp. Wallpapers use two naming conventions:
#   -light/-dark   (e.g. hello-light.png, hello-dark.png)
#   -0/-1          (e.g. hello-0.png = light, hello-1.png = dark)
_ws_gsettings_pair() {
  local wp="$1" mode="$2" base ext family_base try_ext
  ext="${wp##*.}"
  # Strip -light/-dark suffix to get family base
  base="${wp%-${mode}.${ext}}"
  # Strip -0/-1 suffix to get family base for frame naming
  family_base="${wp%-[01].${ext}}"
  # If neither pattern matched, both equal $wp — derive family from theme
  if [[ "$family_base" == "$wp" && "$base" == "$wp" ]]; then
    family_base="${WALLPAPER_DIR}/${THEME%-dark}"
    [[ "$family_base" == "${WALLPAPER_DIR}/${THEME}" ]] && family_base="${WALLPAPER_DIR}/${THEME%-light}"
    base="$family_base"
  fi

  for try_ext in "$ext" png jpg webp heic; do
    [[ -z "$light_wp" ]] || break
    if [[ -f "${base}-light.${try_ext}" ]] && [[ -f "${base}-dark.${try_ext}" ]]; then
      light_wp="${base}-light.${try_ext}"
      dark_wp="${base}-dark.${try_ext}"
    elif [[ -f "${family_base}-0.${try_ext}" ]] && [[ -f "${family_base}-1.${try_ext}" ]]; then
      light_wp="${family_base}-0.${try_ext}"
      dark_wp="${family_base}-1.${try_ext}"
    fi
  done
}

# gsettings-based desktop state for GTK/freedesktop consumers
_ws_apply_gsettings() {
  local wp="$1" mode="$2" wp_uri="file://${1}" light_wp="" dark_wp=""
  _ws_gsettings_pair "$wp" "$mode"
  if [[ -n "$light_wp" ]] && [[ -n "$dark_wp" ]]; then
    light_wp="$(ensure_linux_compatible "$light_wp")"
    dark_wp="$(ensure_linux_compatible "$dark_wp")"
    gsettings set org.gnome.desktop.background picture-uri "file://${light_wp}"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://${dark_wp}"
    # Screensaver schema has no dark variant — pick by active mode
    # so the lock screen matches the desktop the user was on.
    if [[ "$mode" == "dark" ]]; then
      gsettings set org.gnome.desktop.screensaver picture-uri "file://${dark_wp}"
    else
      gsettings set org.gnome.desktop.screensaver picture-uri "file://${light_wp}"
    fi
  else
    gsettings set org.gnome.desktop.background picture-uri "$wp_uri"
    gsettings set org.gnome.desktop.background picture-uri-dark "$wp_uri"
    gsettings set org.gnome.desktop.screensaver picture-uri "$wp_uri"
  fi
  gsettings set org.gnome.desktop.background picture-options "zoom"
  ui_info "Applied via" "gsettings"
}

_ws_apply_linux() {
  local wp="$1" mode="$2"
  _ws_apply_dms "$wp"
  if command -v gsettings &>/dev/null; then
    _ws_apply_gsettings "$wp" "$mode"
  elif command -v swaybg &>/dev/null; then
    pkill swaybg || true
    swaybg -i "$wp" -m fill &
    ui_info "Applied via" "swaybg"
  elif command -v feh &>/dev/null; then
    feh --bg-fill "$wp"
    ui_info "Applied via" "feh"
  else
    ui_err "Wallpaper setter" "not found (gsettings/swaybg/feh)"
    return 1
  fi
}

# Apply wallpaper based on platform and compositor
apply_wallpaper() {
  local wp="$1"
  local mode="$2"

  # Convert HEIC to PNG on Linux if needed
  wp="$(ensure_linux_compatible "$wp")"
  case "$(uname -s)" in
    Darwin) _ws_apply_macos "$wp" "$mode" ;;
    Linux) _ws_apply_linux "$wp" "$mode" ;;
    *)
      ui_err "Unsupported OS" "wallpaper sync"
      return 1
      ;;
  esac
}

# Theme from chezmoi; mode from the theme name (authoritative) instead of
# querying DMS, which may have just restarted and report stale state.
_ws_resolve() {
  THEME="$(current_theme || true)"
  if [[ "$THEME" == *-dark ]]; then
    MODE="dark"
  elif [[ "$THEME" == *-light ]]; then
    MODE="light"
  else
    MODE="$(detect_mode)"
  fi

  WALLPAPER=""
  if [[ "$WALLPAPER_DIR_EXISTS" == "true" ]]; then
    WALLPAPER="$(pick_wallpaper "$MODE" "$THEME" || true)"
  fi

  # Fallback: try OS-native system wallpapers
  if [[ -z "$WALLPAPER" ]]; then
    WALLPAPER="$(system_wallpaper_for_theme "$THEME" "$MODE" || true)"
    if [[ -n "$WALLPAPER" ]]; then
      ui_info "Wallpaper" "using system wallpaper: $(basename "$WALLPAPER")"
    fi
  fi
}

_ws_main() {
  _ws_resolve
  if [[ -z "$WALLPAPER" ]]; then
    ui_info "Wallpaper" "no wallpaper for ${THEME:-unknown} (skipping — theme colors still apply)"
    exit 0
  fi
  apply_wallpaper "$WALLPAPER" "$MODE"
  if [[ -n "$THEME" ]]; then
    ui_ok "Applied wallpaper (${MODE})" "$(basename "$WALLPAPER") ← $THEME"
  else
    ui_ok "Applied wallpaper (${MODE})" "$(basename "$WALLPAPER")"
  fi
}

_ws_main
