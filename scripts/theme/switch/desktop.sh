#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by switch.sh; inherits set -euo pipefail
# Desktop surface for dot theme: wallpaper, fit, accent and the status
# dashboard. Sourced by scripts/theme/switch.sh.

# dot theme fit
_theme_cmd_fit() {
  shift
  want="${1:-}"
  if [[ -z "$want" ]]; then
    command -v gsettings >/dev/null 2>&1 && {
      ui_info "GNOME fit" "$(gsettings get org.gnome.desktop.background picture-options 2>/dev/null | tr -d "'")"
    }
    ui_info "Valid" "zoom | spanned | centered | scaled | stretched | wallpaper | none"
    exit 0
  fi
  case "$want" in
    zoom | spanned | centered | scaled | stretched | wallpaper | none) : ;;
    *)
      ui_err "Usage" "dot theme fit <zoom|spanned|centered|scaled|stretched|wallpaper|none>"
      exit 1
      ;;
  esac
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.background picture-options "$want" 2>/dev/null
    ui_ok "Fit" "$want"
  else
    ui_err "Fit" "gsettings not available"
    exit 1
  fi
}

# dot theme wallpaper
_theme_cmd_wallpaper() {
  shift
  wp="${1:-}"
  if [[ -z "$wp" ]]; then
    command -v gsettings >/dev/null 2>&1 && {
      ui_info "Current" "wallpaper (light)"
      ui_info "  " "$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'")"
      ui_info "Current" "wallpaper (dark)"
      ui_info "  " "$(gsettings get org.gnome.desktop.background picture-uri-dark 2>/dev/null | tr -d "'")"
    }
    exit 0
  fi
  # Resolve to absolute path.
  if [[ "$wp" != /* ]]; then
    wp="$(realpath -- "$wp" 2>/dev/null || readlink -f -- "$wp")"
  fi
  if [[ ! -f "$wp" ]]; then
    ui_err "Wallpaper" "file not found: $wp"
    exit 1
  fi
  # Detect DE (inlined mini-detector matching dot-theme-sync).
  raw="$(printf '%s' "${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}" | tr '[:upper:]' '[:lower:]')"
  case "$raw" in
    *kde* | *plasma*) de=kde ;;
    *xfce*) de=xfce ;;
    *) de=gnome ;;
  esac
  changed=0
  case "$de" in
    kde)
      if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
        plasma-apply-wallpaperimage "$wp" >/dev/null 2>&1 && changed=1
      elif command -v qdbus >/dev/null 2>&1; then
        qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
            var Desktops = desktops();
            for (i=0; i<Desktops.length; i++) {
              d = Desktops[i];
              d.wallpaperPlugin = 'org.kde.image';
              d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
              d.writeConfig('Image', '$wp');
            }" >/dev/null 2>&1 && changed=1
      fi
      ;;
    xfce)
      if command -v xfconf-query >/dev/null 2>&1; then
        while IFS= read -r prop; do
          [[ -z "$prop" ]] && continue
          xfconf-query -c xfce4-desktop -p "$prop" -s "$wp" 2>/dev/null && changed=1
        done < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E '/last-image$' || true)
      fi
      ;;
    *)
      if command -v gsettings >/dev/null 2>&1; then
        gsettings set org.gnome.desktop.background picture-uri "file://$wp" 2>/dev/null && changed=1
        gsettings set org.gnome.desktop.background picture-uri-dark "file://$wp" 2>/dev/null && changed=1
        gsettings set org.gnome.desktop.screensaver picture-uri "file://$wp" 2>/dev/null || true
      fi
      ;;
  esac
  if [[ $changed -gt 0 ]]; then
    ui_ok "Wallpaper" "$wp ($de)"
  else
    ui_err "Wallpaper" "no wallpaper mechanism found for $de"
    exit 1
  fi
}

# dot theme accent
# Live-tweak the desktop accent colour without changing the theme
# or the wallpaper. Accepts either a GNOME accent enum name
# (blue|teal|green|yellow|orange|red|pink|purple|slate) or an
# int 0-6 / -1 matching the macos_accent scale. Applies via the
# detected DE handler; skips silently on DEs without native accent.
_theme_cmd_accent() {
  shift
  want="${1:-}"
  if [[ -z "$want" ]]; then
    ui_info "Current" "accent"
    command -v gsettings >/dev/null 2>&1 &&
      ui_info "GNOME" "$(gsettings get org.gnome.desktop.interface accent-color 2>/dev/null | tr -d "'")"
    command -v kreadconfig6 >/dev/null 2>&1 &&
      ui_info "KDE" "$(kreadconfig6 --file kdeglobals --group General --key AccentColor 2>/dev/null)"
    exit 0
  fi
  # Map int → GNOME enum name if numeric.
  case "$want" in
    -1) want="slate" ;;
    0) want="red" ;;
    1) want="orange" ;;
    2) want="yellow" ;;
    3) want="green" ;;
    4) want="blue" ;;
    5) want="purple" ;;
    6) want="pink" ;;
    blue | teal | green | yellow | orange | red | pink | purple | slate) : ;;
    *)
      ui_err "Usage" "dot theme accent <int -1..6 | blue|teal|green|yellow|orange|red|pink|purple|slate>"
      exit 1
      ;;
  esac
  changed=0
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface accent-color "$want" 2>/dev/null && changed=1
  fi
  # Map GNOME name back to a KDE Plasma hex for kdeglobals.
  case "$want" in
    slate) hex="#4d4d4d" ;;
    red) hex="#da4453" ;;
    orange) hex="#f67400" ;;
    yellow) hex="#f6bb00" ;;
    green) hex="#2ecc71" ;;
    teal) hex="#1abc9c" ;;
    blue) hex="#3daee9" ;;
    purple) hex="#9b59b6" ;;
    pink) hex="#e91e63" ;;
  esac
  if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kdeglobals --group General --key AccentColor "$hex" 2>/dev/null && changed=1
    command -v qdbus >/dev/null 2>&1 && qdbus org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  fi
  if [[ $changed -gt 0 ]]; then
    ui_ok "Accent" "$want ($hex)"
  else
    ui_err "Accent" "no gsettings or kwriteconfig6 available"
    exit 1
  fi
}

# dot theme status
# Comprehensive dashboard: recorded theme, live gsettings/kwriteconfig
# state, wallpaper file existence, detected DE. Great for diagnosing
# "why doesn't my theme match my terminal?" moments.
# `--json` emits machine-readable output for scripting / monitoring.
_theme_cmd_status() {
  shift
  _status_json=false
  [[ "${1:-}" == "--json" ]] && _status_json=true
  current="$(current_theme)"
  current_family="${current%-dark}"
  [[ "$current_family" != "$current" ]] || current_family="${current%-light}"

  live_dark=""
  live_light=""
  live_accent=""
  live_scheme=""
  live_cursor=""
  kde_scheme=""
  kde_accent=""
  if command -v gsettings >/dev/null 2>&1; then
    live_dark="$(gsettings get org.gnome.desktop.background picture-uri-dark 2>/dev/null | tr -d "'")"
    live_light="$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'")"
    live_accent="$(gsettings get org.gnome.desktop.interface accent-color 2>/dev/null | tr -d "'")"
    live_scheme="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")"
    live_cursor="$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")"
  fi
  if command -v kreadconfig6 >/dev/null 2>&1; then
    kde_scheme="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)"
    kde_accent="$(kreadconfig6 --file kdeglobals --group General --key AccentColor 2>/dev/null)"
  fi
  # DE detection (inlined to match _detect_linux_de).
  de=""
  if [[ "$(uname -s)" == "Linux" ]]; then
    raw="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
    raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
    case "$raw" in
      *budgie*) de=budgie ;;
      *cinnamon*) de=cinnamon ;;
      *mate*) de=mate ;;
      *unity*) de=unity ;;
      *lxqt*) de=lxqt ;;
      *kde* | *plasma*) de=kde ;;
      *xfce*) de=xfce ;;
      *sway*) de=sway ;;
      *hyprland*) de=hyprland ;;
      *niri*) de=niri ;;
      *gnome*) de=gnome ;;
      *) de=unknown ;;
    esac
  fi

  if [[ "$_status_json" == true ]]; then
    # Minimal jq-free JSON emission. Values are strings (no interior
    # double-quotes expected from any of these gsettings/kreadconfig
    # fields), so we can quote them directly.
    printf '{\n'
    printf '  "recorded": "%s",\n' "$current"
    printf '  "family": "%s",\n' "$current_family"
    printf '  "detected_de": "%s",\n' "$de"
    printf '  "gnome": {\n'
    printf '    "color_scheme": "%s",\n' "$live_scheme"
    printf '    "accent": "%s",\n' "$live_accent"
    printf '    "cursor": "%s",\n' "$live_cursor"
    printf '    "wallpaper_light": "%s",\n' "$live_light"
    printf '    "wallpaper_dark": "%s"\n' "$live_dark"
    printf '  },\n'
    printf '  "kde": {\n'
    printf '    "color_scheme": "%s",\n' "$kde_scheme"
    printf '    "accent": "%s"\n' "$kde_accent"
    printf '  }\n'
    printf '}\n'
    exit 0
  fi

  ui_header "dot theme status"
  ui_info "Recorded" "$current"
  ui_info "Family" "$current_family"
  [[ -n "$live_scheme" ]] && ui_info "Color scheme" "$live_scheme"
  [[ -n "$live_accent" ]] && ui_info "Accent" "$live_accent"
  [[ -n "$live_cursor" ]] && ui_info "Cursor" "$live_cursor"
  [[ -n "$live_light" ]] && ui_info "Wallpaper (light)" "$(echo "$live_light" | sed 's|.*/||')"
  [[ -n "$live_dark" ]] && ui_info "Wallpaper (dark)" "$(echo "$live_dark" | sed 's|.*/||')"
  [[ -n "$kde_scheme" ]] && ui_info "KDE scheme" "$kde_scheme"
  [[ -n "$kde_accent" ]] && ui_info "KDE accent" "$kde_accent"
  if [[ -n "$de" ]]; then ui_info "Detected DE" "$de"; fi
}
