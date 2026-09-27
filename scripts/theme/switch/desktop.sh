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
# _theme_desktop_env: $XDG_CURRENT_DESKTOP (else $DESKTOP_SESSION), lower-cased.
_theme_desktop_env() {
  printf '%s' "${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}" | tr '[:upper:]' '[:lower:]'
}

# _theme_match_de <raw> <fallback> <name[=pattern|pattern]>...: the first
# name, in the order given, one of whose patterns occurs in <raw>; else
# <fallback>. A bare name is its own pattern.
_theme_match_de() {
  local raw="$1" fallback="$2" spec pat
  local -a pats
  shift 2
  for spec in "$@"; do
    IFS='|' read -ra pats <<<"${spec#*=}"
    for pat in "${pats[@]}"; do
      if [[ "$raw" == *"$pat"* ]]; then
        printf '%s\n' "${spec%%=*}"
        return 0
      fi
    done
  done
  printf '%s\n' "$fallback"
}

# _theme_wallpaper_show: the GNOME light/dark wallpaper URIs.
_theme_wallpaper_show() {
  command -v gsettings >/dev/null 2>&1 || return 0
  ui_info "Current" "wallpaper (light)"
  ui_info "  " "$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'")"
  ui_info "Current" "wallpaper (dark)"
  ui_info "  " "$(gsettings get org.gnome.desktop.background picture-uri-dark 2>/dev/null | tr -d "'")"
}

# _theme_wallpaper_<de> <file>: apply <file>; true when something took it.
_theme_wallpaper_kde() {
  if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
    plasma-apply-wallpaperimage "$1" >/dev/null 2>&1
  elif command -v qdbus >/dev/null 2>&1; then
    qdbus org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "
            var Desktops = desktops();
            for (i=0; i<Desktops.length; i++) {
              d = Desktops[i];
              d.wallpaperPlugin = 'org.kde.image';
              d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
              d.writeConfig('Image', '$1');
            }" >/dev/null 2>&1
  else
    return 1
  fi
}

_theme_wallpaper_xfce() {
  local prop applied=1
  command -v xfconf-query >/dev/null 2>&1 || return 1
  while IFS= read -r prop; do
    [[ -z "$prop" ]] && continue
    xfconf-query -c xfce4-desktop -p "$prop" -s "$1" 2>/dev/null && applied=0
  done < <(xfconf-query -c xfce4-desktop -l 2>/dev/null | grep -E '/last-image$' || true)
  return "$applied"
}

_theme_wallpaper_gnome() {
  local applied=1
  command -v gsettings >/dev/null 2>&1 || return 1
  gsettings set org.gnome.desktop.background picture-uri "file://$1" 2>/dev/null && applied=0
  gsettings set org.gnome.desktop.background picture-uri-dark "file://$1" 2>/dev/null && applied=0
  gsettings set org.gnome.desktop.screensaver picture-uri "file://$1" 2>/dev/null || true
  return "$applied"
}

_theme_cmd_wallpaper() {
  shift
  local wp="${1:-}" de
  if [[ -z "$wp" ]]; then
    _theme_wallpaper_show
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
  # Same mini-detector as dot-theme-sync: KDE, XFCE, else GNOME.
  de="$(_theme_match_de "$(_theme_desktop_env)" gnome 'kde=kde|plasma' xfce)"
  if ! "_theme_wallpaper_$de" "$wp"; then
    ui_err "Wallpaper" "no wallpaper mechanism found for $de"
    exit 1
  fi
  ui_ok "Wallpaper" "$wp ($de)"
}

# dot theme accent
# Live-tweak the desktop accent colour without changing the theme
# or the wallpaper. Accepts either a GNOME accent enum name
# (blue|teal|green|yellow|orange|red|pink|purple|slate) or an
# int 0-6 / -1 matching the macos_accent scale. Applies via the
# detected DE handler; skips silently on DEs without native accent.
# GNOME accent name, macos_accent integer (none for teal) and the KDE
# Plasma hex written to kdeglobals.
_THEME_ACCENTS="slate:-1:#4d4d4d red:0:#da4453 orange:1:#f67400 yellow:2:#f6bb00 green:3:#2ecc71 teal::#1abc9c blue:4:#3daee9 purple:5:#9b59b6 pink:6:#e91e63"

# _theme_accent_lookup <name|int>: prints "<name> <hex>", or fails.
_theme_accent_lookup() {
  local entry name num hex
  for entry in $_THEME_ACCENTS; do
    IFS=: read -r name num hex <<<"$entry"
    if [[ "$1" == "$name" || (-n "$num" && "$1" == "$num") ]]; then
      printf '%s %s\n' "$name" "$hex"
      return 0
    fi
  done
  return 1
}

# _theme_accent_show: the accent each desktop currently reports.
_theme_accent_show() {
  ui_info "Current" "accent"
  command -v gsettings >/dev/null 2>&1 &&
    ui_info "GNOME" "$(gsettings get org.gnome.desktop.interface accent-color 2>/dev/null | tr -d "'")"
  command -v kreadconfig6 >/dev/null 2>&1 &&
    ui_info "KDE" "$(kreadconfig6 --file kdeglobals --group General --key AccentColor 2>/dev/null)"
  return 0
}

_theme_cmd_accent() {
  shift
  local entry want hex changed=0
  if [[ -z "${1:-}" ]]; then
    _theme_accent_show
    exit 0
  fi
  if ! entry="$(_theme_accent_lookup "$1")"; then
    ui_err "Usage" "dot theme accent <int -1..6 | blue|teal|green|yellow|orange|red|pink|purple|slate>"
    exit 1
  fi
  want="${entry% *}" hex="${entry#* }"
  if command -v gsettings >/dev/null 2>&1; then
    gsettings set org.gnome.desktop.interface accent-color "$want" 2>/dev/null && changed=1
  fi
  if command -v kwriteconfig6 >/dev/null 2>&1; then
    kwriteconfig6 --file kdeglobals --group General --key AccentColor "$hex" 2>/dev/null && changed=1
    command -v qdbus >/dev/null 2>&1 && qdbus org.kde.KWin /KWin reconfigure >/dev/null 2>&1 || true
  fi
  if [[ $changed -eq 0 ]]; then
    ui_err "Accent" "no gsettings or kwriteconfig6 available"
    exit 1
  fi
  ui_ok "Accent" "$want ($hex)"
}

# dot theme status
# Comprehensive dashboard: recorded theme, live gsettings/kwriteconfig
# state, wallpaper file existence, detected DE. Great for diagnosing
# "why doesn't my theme match my terminal?" moments.
# `--json` emits machine-readable output for scripting / monitoring.
# _theme_status_read: the live GNOME and KDE values the dashboard shows
# (globals live_* and kde_*; empty where the tool is missing).
_theme_status_read() {
  live_dark="" live_light="" live_accent="" live_scheme="" live_cursor=""
  kde_scheme="" kde_accent=""
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
  return 0
}

# _theme_status_json <recorded> <family> <de>: jq-free JSON. Values are
# strings with no interior double quotes, so they are quoted directly.
_theme_status_json() {
  printf '{\n'
  printf '  "recorded": "%s",\n' "$1"
  printf '  "family": "%s",\n' "$2"
  printf '  "detected_de": "%s",\n' "$3"
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
}

# _theme_info_set <label> <value>: a dashboard row, only when there is a value.
_theme_info_set() {
  if [[ -n "$2" ]]; then
    ui_info "$1" "$2"
  fi
}

_theme_status_text() {
  ui_header "dot theme status"
  ui_info "Recorded" "$1"
  ui_info "Family" "$2"
  _theme_info_set "Color scheme" "$live_scheme"
  _theme_info_set "Accent" "$live_accent"
  _theme_info_set "Cursor" "$live_cursor"
  [[ -n "$live_light" ]] && ui_info "Wallpaper (light)" "$(echo "$live_light" | sed 's|.*/||')"
  [[ -n "$live_dark" ]] && ui_info "Wallpaper (dark)" "$(echo "$live_dark" | sed 's|.*/||')"
  _theme_info_set "KDE scheme" "$kde_scheme"
  _theme_info_set "KDE accent" "$kde_accent"
  _theme_info_set "Detected DE" "$3"
}

_theme_cmd_status() {
  shift
  local current family de=""
  current="$(current_theme)"
  family="${current%-dark}"
  [[ "$family" != "$current" ]] || family="${current%-light}"
  _theme_status_read
  if [[ "$(uname -s)" == "Linux" ]]; then
    de="$(_theme_match_de "$(_theme_desktop_env)" unknown budgie cinnamon mate unity lxqt 'kde=kde|plasma' xfce sway hyprland niri gnome)"
  fi
  if [[ "${1:-}" == "--json" ]]; then
    _theme_status_json "$current" "$family" "$de"
    exit 0
  fi
  _theme_status_text "$current" "$family" "$de"
}
