#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
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
# .chezmoiroot is present (v0.2.503+, where chezmoi files live in defaults/)
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

wallpaper_for_theme() {
  local theme="${1:-}"
  local mode="${2:-}"
  local candidate=""
  local family=""

  [[ -n "$theme" ]] || return 1
  [[ -n "$mode" ]] || return 1

  family="${theme%-dark}"
  if [[ "$family" == "$theme" ]]; then
    family="${theme%-light}"
  fi

  # 1. Prefer pre-extracted frames (fast, no conversion needed).
  #    Convention: {family}-0.png = light, {family}-1.png = dark.
  #    These are created externally (e.g. ImageMagick/ffmpeg from dynamic HEIC).
  local frame_idx=0
  [[ "$mode" == "dark" ]] && frame_idx=1
  for ext in png jpg webp; do
    candidate="$WALLPAPER_DIR/${family}-${frame_idx}.${ext}"
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  # 2. Check exact theme name (e.g. hello-dark.png)
  for ext in png jpg webp heic; do
    candidate="$WALLPAPER_DIR/${theme}.${ext}"
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  # 3. Check family-mode variant (e.g. hello-dark.png)
  for ext in png jpg webp heic; do
    candidate="$WALLPAPER_DIR/${family}-${mode}.${ext}"
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  # 4. Check themes.toml stored wallpaper path (set by extract-theme.py)
  local themes_file="${_CHEZMOI_SRC}/.chezmoidata/themes.toml"
  if [[ -f "$themes_file" ]]; then
    local stored_wp
    stored_wp="$(awk -v n="$theme" '
      $0 == "[themes." n "]" { found=1; next }
      /^\[/ { found=0 }
      found && /^wallpaper/ { sub(/.*= *"/, ""); sub(/".*/, ""); print; exit }
    ' "$themes_file")"
    if [[ -n "$stored_wp" ]]; then
      # Cross-platform: resolve macOS paths on Linux
      if [[ ! -f "$stored_wp" ]]; then
        if [[ "$stored_wp" == /Users/* ]]; then
          # /Users/<user>/Pictures/... → $HOME/Pictures/...
          stored_wp="${HOME}/${stored_wp#/Users/*/}"
        elif [[ "$stored_wp" == /System/* ]]; then
          # macOS system wallpapers don't exist on Linux — skip to next fallback
          stored_wp=""
        fi
      fi
      if [[ -n "$stored_wp" && -f "$stored_wp" ]]; then
        printf '%s\n' "$stored_wp"
        return 0
      fi
    fi
  fi

  # 5. Check family-only file (e.g. hello.heic — dynamic wallpaper).
  #    For HEIC on Linux, extract frames first then return the correct one.
  for ext in png jpg webp; do
    candidate="$WALLPAPER_DIR/${family}.${ext}"
    if [[ -f "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  candidate="$WALLPAPER_DIR/${family}.heic"
  if [[ -f "$candidate" ]] && [[ "$(uname -s)" == "Linux" ]]; then
    # Extract frames from HEIC then return the mode-appropriate one
    ensure_linux_compatible "$candidate" >/dev/null
    # Re-check for extracted frames
    for fext in png jpg; do
      if [[ -f "$WALLPAPER_DIR/${family}-${frame_idx}.${fext}" ]]; then
        printf '%s\n' "$WALLPAPER_DIR/${family}-${frame_idx}.${fext}"
        return 0
      fi
    done
  elif [[ -f "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return 0
  fi

  return 1
}

# Fallback: find a matching system wallpaper when no custom one exists.
# Maps theme names to platform-native wallpapers shipped with the OS.
system_wallpaper_for_theme() {
  local theme="${1:-}"
  local mode="${2:-}"
  local SYS_MAC="/System/Library/Desktop Pictures"
  local SYS_LINUX_DIRS=(
    /usr/share/backgrounds
    /usr/share/wallpapers
  )

  [[ -n "$theme" ]] || return 1

  # macOS: map theme names to Apple system wallpapers
  if [[ "$(uname -s)" == "Darwin" && -d "$SYS_MAC" ]]; then
    local -A mac_map=(
      [macos - sonoma]="$SYS_MAC/Sonoma.heic"
      [macos - blue]="$SYS_MAC/Mac Blue.heic"
      [macos - pink]="$SYS_MAC/Mac Pink.heic"
      [macos - purple]="$SYS_MAC/Mac Purple.heic"
      [macos - yellow]="$SYS_MAC/Mac Yellow.heic"
      [macos - orange]="$SYS_MAC/iMac Orange.heic"
      [macos - green]="$SYS_MAC/iMac Green.heic"
      [macos - silver]="$SYS_MAC/iMac Silver.heic"
    )

    # Extract family from theme name (strip -dark/-light)
    local family="${theme%-dark}"
    [[ "$family" == "$theme" ]] && family="${theme%-light}"

    local sys_wp="${mac_map[$family]:-}"
    if [[ -n "$sys_wp" && -f "$sys_wp" ]]; then
      printf '%s\n' "$sys_wp"
      return 0
    fi
  fi

  # Linux: search system background directories for keyword match
  if [[ "$(uname -s)" == "Linux" ]]; then
    local keyword="${theme#macos-}"
    keyword="${keyword%-dark}"
    keyword="${keyword%-light}"

    for dir in "${SYS_LINUX_DIRS[@]}"; do
      [[ -d "$dir" ]] || continue
      local match
      match="$(find "$dir" -maxdepth 3 -type f \( -name "*.jpg" -o -name "*.png" -o -name "*.webp" \) \
        -iname "*${keyword}*" 2>/dev/null | head -1)"
      if [[ -n "$match" ]]; then
        printf '%s\n' "$match"
        return 0
      fi
    done
  fi

  return 1
}

theme_wallpaper_pair() {
  local theme="${1:-}"
  local family=""
  local light_wp=""
  local dark_wp=""

  [[ -n "$theme" ]] || return 1

  family="${theme%-dark}"
  if [[ "$family" == "$theme" ]]; then
    family="${theme%-light}"
  fi

  light_wp="$(wallpaper_for_theme "${family}-light" "light" || true)"
  dark_wp="$(wallpaper_for_theme "${family}-dark" "dark" || true)"

  if [[ -n "$light_wp" && -n "$dark_wp" ]]; then
    printf '%s\n%s\n' "$light_wp" "$dark_wp"
    return 0
  fi

  return 1
}

# Pick a wallpaper matching the current mode
pick_wallpaper() {
  local mode="$1"
  local theme="${2:-}"
  local files=()

  if [[ -n "$theme" ]]; then
    local matched
    matched="$(wallpaper_for_theme "$theme" "$mode" || true)"
    if [[ -n "$matched" ]]; then
      printf '%s\n' "$matched"
      return 0
    fi
  fi

  while IFS= read -r line; do
    files+=("$line")
  done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*-${mode}.jpg" -o -iname "*-${mode}.png" -o -iname "*-${mode}.webp" -o -iname "*-${mode}.heic" \) | sort)

  # Fallback: search for extracted frames (-0 = light, -1 = dark)
  if [[ ${#files[@]} -eq 0 ]]; then
    local frame_suffix=0
    [[ "$mode" == "dark" ]] && frame_suffix=1
    while IFS= read -r line; do
      files+=("$line")
    done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \( -iname "*-${frame_suffix}.jpg" -o -iname "*-${frame_suffix}.png" -o -iname "*-${frame_suffix}.webp" \) | sort)
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

THEME="$(current_theme || true)"

# Derive mode from theme name (authoritative) instead of querying DMS
# which may have just restarted and report stale state.
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

if [[ -z "$WALLPAPER" ]]; then
  ui_info "Wallpaper" "no wallpaper for ${THEME:-unknown} (skipping — theme colors still apply)"
  exit 0
fi

# Convert .heic to .png on Linux (HEIC not universally supported)
ensure_linux_compatible() {
  local wp="$1"
  [[ "$(uname -s)" == "Linux" ]] || {
    printf '%s\n' "$wp"
    return
  }
  [[ "${wp##*.}" == "heic" ]] || {
    printf '%s\n' "$wp"
    return
  }

  local png="${wp%.heic}.png"
  # Use cached PNG only if it exists, is newer than source, and is > 1MB
  # (corrupt/truncated conversions produce tiny files that crash matugen).
  if [[ -f "$png" ]] && [[ "$png" -nt "$wp" ]]; then
    local fsize
    fsize="$(stat -c%s "$png" 2>/dev/null || stat -f%z "$png" 2>/dev/null || echo 0)"
    if [[ "$fsize" -gt 1000000 ]]; then
      printf '%s\n' "$png"
      return
    fi
  fi

  # Write to temp file then atomic move — prevents DMS/matugen from
  # reading a partially-written PNG during multi-frame HEIC extraction.
  local tmp_png
  tmp_png="$(mktemp "${png%.png}.XXXXXX.png")"

  if command -v magick &>/dev/null; then
    magick "$wp" -quality 95 "$tmp_png" 2>/dev/null && {
      # Multi-frame HEIC: magick creates {name}-0.png, {name}-1.png etc.
      # Move each extracted frame to its final location atomically.
      local tmp_base="${tmp_png%.png}"
      local final_base="${png%.png}"
      if [[ -f "${tmp_base}-0.png" ]]; then
        for f in "${tmp_base}"-*.png; do
          local suffix="${f#"$tmp_base"}"
          mv -f "$f" "${final_base}${suffix}" 2>/dev/null
        done
        rm -f "$tmp_png" 2>/dev/null
        # Return the correct frame: -0 = light, -1 = dark
        if [[ -f "${final_base}-0.png" ]]; then
          printf '%s\n' "${final_base}-0.png"
        else
          printf '%s\n' "$png"
        fi
      else
        mv -f "$tmp_png" "$png" 2>/dev/null
        printf '%s\n' "$png"
      fi
      return
    }
  elif command -v heif-convert &>/dev/null; then
    heif-convert "$wp" "$tmp_png" 2>/dev/null && {
      mv -f "$tmp_png" "$png" 2>/dev/null
      printf '%s\n' "$png"
      return
    }
  elif command -v convert &>/dev/null; then
    convert "$wp" "$tmp_png" 2>/dev/null && {
      mv -f "$tmp_png" "$png" 2>/dev/null
      printf '%s\n' "$png"
      return
    }
  fi

  rm -f "$tmp_png" 2>/dev/null
  # Fallback: use original and hope the DE supports it
  printf '%s\n' "$wp"
}

# Apply wallpaper based on platform and compositor
apply_wallpaper() {
  local wp="$1"
  local mode="$2"

  # Convert HEIC to PNG on Linux if needed
  wp="$(ensure_linux_compatible "$wp")"
  local wp_uri="file://${wp}"

  case "$(uname -s)" in
    Darwin)
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
      python3 - "$wp" <<'PYEOF' 2>/dev/null || true
import plistlib, os, sys
wp = sys.argv[1]
uri = "file://" + wp
store = os.path.expanduser(
    "~/Library/Application Support/com.apple.wallpaper/Store/Index.plist"
)
if not os.path.exists(store):
    sys.exit(0)

def make_config(uri):
    return plistlib.dumps(
        {"type": "imageFile", "url": {"relative": uri}},
        fmt=plistlib.FMT_BINARY,
    )

def patch_node(node, uri):
    """Patch a Desktop/Linked node in-place. Returns 1 if patched."""
    content = node.get("Content")
    if not isinstance(content, dict):
        return 0
    choices = content.get("Choices")
    if not isinstance(choices, list) or not choices:
        return 0
    first = choices[0]
    if not isinstance(first, dict):
        return 0
    first["Configuration"] = make_config(uri)
    first["Provider"] = "com.apple.wallpaper.choice.image"
    first["Files"] = []
    content["Choices"] = [first]
    content["Shuffle"] = "$null"
    # Leave EncodedOptionValues alone — it stores crop/color and is per-image.
    return 1

# Recursively patch every wallpaper-bearing node. A node qualifies when it
# has a Content.Choices list — this matches Desktop and Linked entries
# wherever they appear (top-level Displays, AllSpacesAndDisplays, Spaces[*]
# .Default, Spaces[*].Displays[*], etc.) and ignores Idle (screensaver) so
# we don't clobber the user's lock-screen wallpaper.
def walk(node, uri, key=None):
    count = 0
    if isinstance(node, dict):
        if key in ("Desktop", "Linked") and "Content" in node:
            count += patch_node(node, uri)
        else:
            for k, v in node.items():
                count += walk(v, uri, k)
    elif isinstance(node, list):
        for item in node:
            count += walk(item, uri)
    return count

with open(store, "rb") as f:
    data = plistlib.load(f)

# Safety backup before mutating.
try:
    with open(store + ".dot-bak", "wb") as f:
        plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)
except Exception:
    pass

updated = walk(data, uri)

if updated:
    with open(store, "wb") as f:
        plistlib.dump(data, f, fmt=plistlib.FMT_BINARY)

print(updated)
PYEOF

      # Restart WallpaperAgent so it re-reads the store. launchd respawns it.
      killall WallpaperAgent 2>/dev/null || true

      # Also nudge the active Space via the public API. This covers the
      # initial render before WallpaperAgent comes back, and handles screens
      # the Index.plist rewrite somehow missed.
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
      ;;
    Linux)
      # DMS owns wallpaper display and runs matugen for color extraction.
      # Set the wallpaper ONCE for the current mode — DMS handles the rest.
      # Multiple IPC calls (pair-setting, mode switching) cause matugen
      # worker crashes and slow transitions. Keep it simple.
      if command -v dms &>/dev/null; then
        local dms_result current_outputs output
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
      fi

      # gsettings-based desktop state for GTK/freedesktop consumers
      if command -v gsettings &>/dev/null; then
        # Find the matching pair for picture-uri and picture-uri-dark.
        # Wallpapers use two naming conventions:
        #   -light/-dark   (e.g. hello-light.png, hello-dark.png)
        #   -0/-1          (e.g. hello-0.png = light, hello-1.png = dark)
        local light_wp="" dark_wp="" base ext family_base
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

        if [[ -n "$light_wp" ]] && [[ -n "$dark_wp" ]]; then
          light_wp="$(ensure_linux_compatible "$light_wp")"
          dark_wp="$(ensure_linux_compatible "$dark_wp")"
          gsettings set org.gnome.desktop.background picture-uri "file://${light_wp}"
          gsettings set org.gnome.desktop.background picture-uri-dark "file://${dark_wp}"
          gsettings set org.gnome.desktop.screensaver picture-uri "file://${light_wp}"
        else
          gsettings set org.gnome.desktop.background picture-uri "$wp_uri"
          gsettings set org.gnome.desktop.background picture-uri-dark "$wp_uri"
          gsettings set org.gnome.desktop.screensaver picture-uri "$wp_uri"
        fi
        gsettings set org.gnome.desktop.background picture-options "zoom"
        ui_info "Applied via" "gsettings"
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
      ;;
    *)
      ui_err "Unsupported OS" "wallpaper sync"
      return 1
      ;;
  esac
}

apply_wallpaper "$WALLPAPER" "$MODE"
if [[ -n "$THEME" ]]; then
  ui_ok "Applied wallpaper (${MODE})" "$(basename "$WALLPAPER") ← $THEME"
else
  ui_ok "Applied wallpaper (${MODE})" "$(basename "$WALLPAPER")"
fi
