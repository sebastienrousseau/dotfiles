#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
## Theme Switcher — Switch between theme families and light/dark modes.
##
## Supports Tokyo Night, Catppuccin, Rose Pine, Kanagawa, and other
## popular theme families. Updates chezmoi data and applies changes.
##
## # Requirements
## - chezmoi: Dotfiles manager
## - sed: For updating theme configuration
##
## # Usage
## dot theme list              # Show all available themes
## dot theme set NAME          # Set theme to NAME
## dot theme toggle            # Toggle light/dark within family
## dot theme family            # Switch between theme families
## dot theme current           # Show current theme info
##
## # Platform Notes
## - All platforms: Updates chezmoi configuration

set -euo pipefail

# Cleanup function for temp files
cleanup() {
  if [[ -n "${tmp_file:-}" ]] && [[ -f "$tmp_file" ]]; then
    rm -f "$tmp_file"
  fi
}
trap cleanup EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/dot/ui.sh
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../../lib/dot/ui.sh"

ui_init

resolve_source_dir() {
  if [ -n "${CHEZMOI_SOURCE_DIR:-}" ] && [ -d "$CHEZMOI_SOURCE_DIR" ]; then
    echo "$CHEZMOI_SOURCE_DIR"
    return
  fi
  if [ -d "$HOME/.dotfiles" ]; then
    echo "$HOME/.dotfiles"
    return
  fi
  if [ -d "$HOME/.local/share/chezmoi" ]; then
    echo "$HOME/.local/share/chezmoi"
    return
  fi
  echo ""
}

SRC_DIR="$(resolve_source_dir)"
if [ -z "$SRC_DIR" ]; then
  ui_err "Dotfiles source" "not found"
  exit 1
fi

# Descend into the chezmoi source subdir when .chezmoiroot is present (v0.2.503+)
CHEZMOI_SRC="$SRC_DIR"
if [[ -f "$SRC_DIR/.chezmoiroot" ]]; then
  _sub="$(head -1 "$SRC_DIR/.chezmoiroot" | tr -d '[:space:]')"
  [[ -n "$_sub" && -d "$SRC_DIR/$_sub" ]] && CHEZMOI_SRC="$SRC_DIR/$_sub"
fi

DATA_FILE="$CHEZMOI_SRC/.chezmoidata.toml"
THEMES_FILE="$CHEZMOI_SRC/.chezmoidata/themes.toml"
WALLPAPER_DIR="${DOTFILES_WALLPAPER_DIR:-$HOME/Pictures/Wallpapers}"
if [ ! -f "$DATA_FILE" ]; then
  ui_err "Missing" "$DATA_FILE"
  exit 1
fi

# =============================================================================
# Theme Database
# =============================================================================

# Default preferences
DEFAULT_DARK="macos-monterey-dark"
DEFAULT_LIGHT="macos-monterey-light"

# =============================================================================
# Theme Functions
# =============================================================================

current_theme() {
  awk -F'"' '/^theme =/ {print $2}' "$DATA_FILE" | head -n 1
}

theme_mode() {
  local name="${1:-}"
  awk -v n="$name" '
    $0 == "[themes." n "]" { found=1; next }
    /^\[/ { found=0 }
    found && /^mode/ { sub(/.*= *"/, ""); sub(/".*/, ""); print; exit }
  ' "$THEMES_FILE"
}

theme_exists() {
  local name="${1:-}"
  grep -q "^\[themes\.${name}\]$" "$THEMES_FILE" 2>/dev/null
}

all_theme_names() {
  sed -n 's/^\[themes\.\([a-zA-Z0-9-]*\)\]$/\1/p' "$THEMES_FILE" | sort -u
}

# List wallpaper families that have BOTH dark and light variants in themes.toml.
# Only these are presented to users — unpaired wallpapers are hidden.
paired_families() {
  local -A has_dark has_light
  local name family
  while IFS= read -r name; do
    if [[ "$name" == *-dark ]]; then
      family="${name%-dark}"
      has_dark["$family"]=1
    elif [[ "$name" == *-light ]]; then
      family="${name%-light}"
      has_light["$family"]=1
    fi
  done < <(all_theme_names)

  for family in $(printf '%s\n' "${!has_dark[@]}" | sort); do
    [[ -n "${has_light[$family]+x}" ]] && echo "$family"
  done
}

# Determine source type (system/custom) for a wallpaper family.
wallpaper_source() {
  local family="${1:-}"
  # Check for custom wallpapers: dynamic (family.heic) or split (family-dark/light.ext)
  for ext in heic jpg png webp; do
    if [[ -f "$WALLPAPER_DIR/${family}.${ext}" || -f "$WALLPAPER_DIR/${family}-dark.${ext}" || -f "$WALLPAPER_DIR/${family}-light.${ext}" || -f "$WALLPAPER_DIR/${family}-0.${ext}" ]]; then
      echo "Custom"
      return
    fi
  done
  echo "System"
}

get_theme_family() {
  local theme="${1:-}"
  # Read family from themes.toml if available
  if [[ -f "$THEMES_FILE" ]]; then
    local family
    family="$(awk -v n="$theme" '
      $0 == "[themes." n "]" { found=1; next }
      /^\[/ { found=0 }
      found && /^family/ { sub(/.*= *"/, ""); sub(/".*/, ""); print; exit }
    ' "$THEMES_FILE")"
    if [[ -n "$family" ]]; then
      echo "$family"
      return
    fi
  fi
  # Fallback: strip -dark/-light suffix
  local family="${theme%-dark}"
  [[ "$family" != "$theme" ]] || family="${theme%-light}"
  echo "$family"
}

is_dark_theme() {
  local theme="${1:-}"
  case "$theme" in
    *-dark)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

set_theme() {
  local new_theme="$1"
  if [ -z "$new_theme" ]; then
    pick_theme
    return
  fi
  # Pass remaining args (e.g. --force, --full) straight through so the
  # sync backend can honour them.
  shift
  dot-theme-sync "$new_theme" "$@"
}

# Interactive theme picker
pick_theme() {
  if ! command -v fzf &>/dev/null; then
    ui_err "fzf" "required for interactive picker"
    ui_info "Usage" "dot theme set <name>"
    exit 1
  fi

  local current
  current="$(current_theme)"

  if [[ ! -f "$THEMES_FILE" ]]; then
    ui_err "Missing" "$THEMES_FILE"
    exit 1
  fi

  local current_family="${current%-dark}"
  [[ "$current_family" != "$current" ]] || current_family="${current%-light}"
  local current_mode="dark"
  is_dark_theme "$current" 2>/dev/null || current_mode="light"

  # Build theme list: one row per family, shows active mode
  local theme_list=""
  local family source marker active_mode
  while IFS= read -r family; do
    [[ -n "$family" ]] || continue
    source="$(wallpaper_source "$family")"
    marker="○"
    active_mode=""
    if [[ "$family" == "$current_family" ]]; then
      marker="✓"
      active_mode="$current_mode"
    fi
    theme_list+="$(printf '%s  %-35s  %-8s  %s' "$marker" "$family" "$source" "$active_mode")"$'\n'
  done < <(paired_families)

  local selected_family
  selected_family="$(echo "$theme_list" | fzf \
    --header "Select wallpaper theme (current: $current_family [$current_mode])" \
    --prompt "Theme > " \
    --height 30 \
    --reverse \
    --no-sort \
    --no-preview \
    --ansi |
    awk '$1 !~ /^#/ && NF >= 2 {print $2}')" || return 0

  if [[ -n "$selected_family" ]]; then
    # Apply with current appearance mode (dark/light)
    local new_theme="${selected_family}-${current_mode}"
    if [[ "$new_theme" != "$current" ]]; then
      dot-theme-sync "$new_theme"
    else
      ui_info "Theme" "already on $current"
    fi
  fi
}

list_themes() {
  local current
  current="$(current_theme)"
  local current_family="${current%-dark}"
  [[ "$current_family" != "$current" ]] || current_family="${current%-light}"

  local count=0
  local family source

  printf '  %-35s  %s\n' "WALLPAPER" "SOURCE"
  printf '  %-35s  %s\n' "---------" "------"
  while IFS= read -r family; do
    [[ -n "$family" ]] || continue
    source="$(wallpaper_source "$family")"
    if [[ "$family" == "$current_family" ]]; then
      ui_ok "$family" "$source ◀"
    else
      printf '  %-35s  %s\n' "$family" "$source"
    fi
    count=$((count + 1))
  done < <(paired_families)

  echo ""
  ui_info "Current" "$(current_theme) ($count wallpaper themes available)"
}

# Toggle between light and dark within the same family, or switch families
toggle_theme() {
  local current
  current="$(current_theme)"

  if is_dark_theme "$current"; then
    if [[ "$current" == *-dark ]]; then
      set_theme "${current%-dark}-light"
    else
      set_theme "$DEFAULT_LIGHT"
    fi
  else
    if [[ "$current" == *-light ]]; then
      set_theme "${current%-light}-dark"
    else
      set_theme "$DEFAULT_DARK"
    fi
  fi
}

# Switch to the next wallpaper family while preserving mode.
switch_family() {
  local current family
  current="$(current_theme)"
  family="$(get_theme_family "$current")"
  local mode="dark"
  local families=()
  local idx=0
  local next_family=""

  if [[ "$current" == *-light ]]; then
    mode="light"
  fi

  while IFS= read -r name; do
    [[ -n "$name" ]] || continue
    families+=("$name")
  done < <(paired_families)

  if [[ ${#families[@]} -eq 0 ]]; then
    set_theme "$DEFAULT_DARK"
    return
  fi

  for idx in "${!families[@]}"; do
    if [[ "${families[$idx]}" == "$family" ]]; then
      next_family="${families[$(((idx + 1) % ${#families[@]}))]}"
      break
    fi
  done

  if [[ -z "$next_family" ]]; then
    next_family="${families[0]}"
  fi

  set_theme "${next_family}-${mode}"
}

# Show current theme info
show_current() {
  local current family
  current="$(current_theme)"
  family="$(get_theme_family "$current")"
  local mode="dark"
  if ! is_dark_theme "$current" 2>/dev/null; then
    mode="light"
  fi
  ui_info "Current" "$current ($family, $mode)"
}

# Detect system appearance (Dark/Light) and sync dotfiles
sync_theme() {
  local os_mode="dark" # Default fallback
  case "$(uname -s)" in
    Darwin)
      if defaults read -g AppleInterfaceStyle >/dev/null 2>&1; then
        os_mode="dark"
      else
        os_mode="light"
      fi
      ;;
    Linux)
      if command -v gsettings >/dev/null 2>&1; then
        # Check GNOME color scheme. Fixes a long-standing bug where the
        # variable was declared as `local scheme=scheme=$(...)` — the
        # extra `scheme=` prefix made the value always start with that
        # literal, so the `prefer-light` test below could never match
        # and the system always fell through to the dark branch.
        local scheme
        scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
        if [[ "$scheme" == "prefer-light" ]]; then
          os_mode="light"
        else
          os_mode="dark"
        fi
      fi
      ;;
  esac

  local current
  current="$(current_theme)"
  if is_dark_theme "$current" && [[ "$os_mode" == "light" ]]; then
    ui_info "Sync" "System is light, switching dotfiles to light..."
    toggle_theme
  elif ! is_dark_theme "$current" && [[ "$os_mode" == "dark" ]]; then
    ui_info "Sync" "System is dark, switching dotfiles to dark..."
    toggle_theme
  else
    ui_ok "Sync" "Dotfiles already match system ($os_mode mode)"
  fi
}

# Ambient auto-switch: pick light|dark based on time of day.
# Default sunrise/sunset: 07:00 / 19:00 (configurable via env or state file).
# Applies to the current wallpaper family — never changes wallpaper choice.
ambient_theme() {
  local sunrise sunset now hour minute now_min sunrise_min sunset_min desired
  local state_file="${XDG_STATE_HOME:-$HOME/.local/state}/dot/theme-ambient.conf"
  # Priority: env vars > state file > defaults.
  sunrise="${DOT_THEME_SUNRISE:-}"
  sunset="${DOT_THEME_SUNSET:-}"
  if [[ -z "$sunrise" || -z "$sunset" ]] && [[ -f "$state_file" ]]; then
    # shellcheck disable=SC1090
    source "$state_file"
    sunrise="${sunrise:-$DOT_THEME_SUNRISE}"
    sunset="${sunset:-$DOT_THEME_SUNSET}"
  fi
  sunrise="${sunrise:-07:00}"
  sunset="${sunset:-19:00}"

  # Convert HH:MM strings to minutes since midnight for cheap comparison.
  IFS=':' read -r hour minute <<< "$sunrise"
  sunrise_min=$((10#$hour * 60 + 10#$minute))
  IFS=':' read -r hour minute <<< "$sunset"
  sunset_min=$((10#$hour * 60 + 10#$minute))
  now="$(date +%H:%M)"
  IFS=':' read -r hour minute <<< "$now"
  now_min=$((10#$hour * 60 + 10#$minute))

  if (( now_min >= sunrise_min && now_min < sunset_min )); then
    desired="light"
  else
    desired="dark"
  fi

  local current family target
  current="$(current_theme)"
  family="${current%-dark}"
  [[ "$family" != "$current" ]] || family="${current%-light}"
  target="${family}-${desired}"

  if [[ "$current" == "$target" ]]; then
    ui_ok "Ambient" "$current — already matches (sunrise=$sunrise sunset=$sunset now=$now)"
    return 0
  fi
  ui_info "Ambient" "$current -> $target (sunrise=$sunrise sunset=$sunset now=$now)"
  set_theme "$target"
}

# Install/uninstall systemd user timer that runs `dot theme ambient` hourly.
ambient_enable() {
  local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  mkdir -p "$unit_dir"
  local dot_path
  dot_path="$(command -v dot 2>/dev/null || echo "$HOME/.local/bin/dot")"

  cat > "$unit_dir/dot-theme-ambient.service" <<EOF
[Unit]
Description=Ambient theme switch (dot theme ambient)
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=${dot_path} theme ambient
EOF

  cat > "$unit_dir/dot-theme-ambient.timer" <<EOF
[Unit]
Description=Run 'dot theme ambient' hourly and on session start

[Timer]
OnStartupSec=30
OnUnitActiveSec=1h
AccuracySec=1m
Persistent=true

[Install]
WantedBy=timers.target
EOF

  systemctl --user daemon-reload
  systemctl --user enable --now dot-theme-ambient.timer
  ui_ok "Ambient" "systemd timer enabled — will re-check hourly"
}

ambient_disable() {
  systemctl --user disable --now dot-theme-ambient.timer 2>/dev/null || true
  local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  rm -f "$unit_dir/dot-theme-ambient.service" "$unit_dir/dot-theme-ambient.timer"
  systemctl --user daemon-reload
  ui_ok "Ambient" "systemd timer disabled and removed"
}

# =============================================================================
# Main
# =============================================================================

case "${1:-}" in
  list)
    list_themes
    ;;
  set)
    shift
    set_theme "$@"
    ;;
  toggle)
    toggle_theme
    ;;
  sync)
    sync_theme
    ;;
  ambient)
    shift
    case "${1:-run}" in
      run|"") ambient_theme ;;
      enable) ambient_enable ;;
      disable) ambient_disable ;;
      status)
        state_file="${XDG_STATE_HOME:-$HOME/.local/state}/dot/theme-ambient.conf"
        ui_info "Sunrise" "${DOT_THEME_SUNRISE:-$(grep -h '^sunrise=' "$state_file" 2>/dev/null | cut -d= -f2 || echo '07:00 (default)')}"
        ui_info "Sunset" "${DOT_THEME_SUNSET:-$(grep -h '^sunset=' "$state_file" 2>/dev/null | cut -d= -f2 || echo '19:00 (default)')}"
        if systemctl --user is-active dot-theme-ambient.timer >/dev/null 2>&1; then
          ui_ok "Timer" "active"
          systemctl --user list-timers dot-theme-ambient.timer --no-pager 2>&1 | grep -v '^$' | tail -3
        else
          ui_info "Timer" "inactive — run 'dot theme ambient enable'"
        fi
        ;;
      *)
        ui_err "Unknown" "ambient subcommand '$1' (use: run|enable|disable|status)"
        exit 1
        ;;
    esac
    ;;
  family)
    switch_family
    ;;
  current)
    show_current
    ;;
  undo)
    # Step back one entry in the theme-history stack. Applied theme goes
    # to the top so a second `undo` returns to it (toggle behaviour).
    hist="${XDG_STATE_HOME:-$HOME/.local/state}/dot/theme-history"
    if [[ ! -s "$hist" ]]; then
      ui_err "History" "empty — no previous theme recorded"
      exit 1
    fi
    prev="$(head -1 "$hist")"
    current="$(current_theme)"
    rest="$(tail -n +2 "$hist" 2>/dev/null | grep -Fxv -- "$current" || true)"
    tmp="$(mktemp)"
    {
      printf '%s\n' "$current"
      [[ -n "$rest" ]] && printf '%s\n' "$rest"
    } > "$tmp"
    mv "$tmp" "$hist"
    set_theme "$prev"
    ;;
  history)
    hist="${XDG_STATE_HOME:-$HOME/.local/state}/dot/theme-history"
    if [[ ! -s "$hist" ]]; then
      ui_info "History" "empty — apply a theme to start tracking"
      exit 0
    fi
    ui_header "Recent themes (newest first)"
    n=1
    while IFS= read -r line; do
      printf '  %2d  %s\n' "$n" "$line"
      n=$((n + 1))
    done < "$hist"
    ui_info "Current" "$(current_theme)"
    ;;
  reset)
    # Restore sane defaults: Adwaita GTK, default cursor/font, remove
    # accent + shell theme. Wallpaper stays — we don't clobber user
    # media choices. Use --force so DE handlers actually re-apply.
    if command -v gsettings >/dev/null 2>&1; then
      gsettings reset org.gnome.desktop.interface accent-color 2>/dev/null || true
      gsettings reset org.gnome.desktop.interface cursor-theme 2>/dev/null || true
      gsettings reset org.gnome.desktop.interface monospace-font-name 2>/dev/null || true
      gsettings reset org.gnome.desktop.interface font-name 2>/dev/null || true
      gsettings reset org.gnome.desktop.interface document-font-name 2>/dev/null || true
      gsettings set org.gnome.shell.extensions.user-theme name "" 2>/dev/null || true
    fi
    ui_ok "Reset" "GNOME accent / cursor / fonts / shell-theme restored to defaults"
    ui_info "Note" "wallpaper untouched — re-run 'dot theme set <name>' to apply a theme"
    ;;
  status)
    # Comprehensive dashboard: recorded theme, live gsettings/kwriteconfig
    # state, wallpaper file existence, detected DE. Great for diagnosing
    # "why doesn't my theme match my terminal?" moments.
    ui_header "dot theme status"
    current="$(current_theme)"
    current_family="${current%-dark}"
    [[ "$current_family" != "$current" ]] || current_family="${current%-light}"
    ui_info "Recorded" "$current"
    ui_info "Family" "$current_family"

    # Live wallpaper (GNOME family)
    if command -v gsettings >/dev/null 2>&1; then
      live_dark="$(gsettings get org.gnome.desktop.background picture-uri-dark 2>/dev/null | tr -d "'" | sed 's|.*/||')"
      live_light="$(gsettings get org.gnome.desktop.background picture-uri 2>/dev/null | tr -d "'" | sed 's|.*/||')"
      live_accent="$(gsettings get org.gnome.desktop.interface accent-color 2>/dev/null | tr -d "'")"
      live_scheme="$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")"
      live_cursor="$(gsettings get org.gnome.desktop.interface cursor-theme 2>/dev/null | tr -d "'")"
      ui_info "Color scheme" "$live_scheme"
      ui_info "Accent" "$live_accent"
      ui_info "Cursor" "$live_cursor"
      ui_info "Wallpaper (light)" "$live_light"
      ui_info "Wallpaper (dark)" "$live_dark"
    fi
    # KDE side (harmless on non-KDE — kreadconfig6 will just fail)
    if command -v kreadconfig6 >/dev/null 2>&1; then
      kde_scheme="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)"
      kde_accent="$(kreadconfig6 --file kdeglobals --group General --key AccentColor 2>/dev/null)"
      [[ -n "$kde_scheme" ]] && ui_info "KDE scheme" "$kde_scheme"
      [[ -n "$kde_accent" ]] && ui_info "KDE accent" "$kde_accent"
    fi
    # Detected DE (matches dot-theme-sync's _detect_linux_de logic).
    if [[ "$(uname -s)" == "Linux" ]]; then
      raw="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}"
      raw="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
      case "$raw" in
        *budgie*) de=budgie ;;
        *cinnamon*) de=cinnamon ;;
        *mate*) de=mate ;;
        *unity*) de=unity ;;
        *lxqt*) de=lxqt ;;
        *kde*|*plasma*) de=kde ;;
        *xfce*) de=xfce ;;
        *sway*) de=sway ;;
        *hyprland*) de=hyprland ;;
        *niri*) de=niri ;;
        *gnome*) de=gnome ;;
        *) de=unknown ;;
      esac
      ui_info "Detected DE" "$de"
    fi
    ;;
  rebuild)
    shift
    bash "$SCRIPT_DIR/rebuild-themes.sh" "$@"
    ;;
  preview)
    shift
    preview="${1:-}"
    if [[ -z "$preview" ]]; then
      ui_err "Usage" "dot theme preview <name>"
      exit 1
    fi
    prev="$(current_theme)"
    ui_info "Preview" "$preview (was $prev)"
    # Revert on Ctrl-C. Trap fires before exit so the shell prompt
    # returns with the original theme active.
    trap 'echo; dot-theme-sync --force "'"$prev"'" >/dev/null 2>&1; ui_info "Reverted" "'"$prev"'"; exit 130' INT
    if ! dot-theme-sync --force "$preview"; then
      ui_err "Preview" "apply failed — reverting"
      dot-theme-sync --force "$prev" >/dev/null 2>&1
      exit 1
    fi
    echo ""
    read -r -p "  Press ENTER to keep '$preview' or Ctrl-C to revert to '$prev': " _
    trap - INT
    ui_ok "Kept" "$preview"
    ;;
  random)
    # Pick a random paired family and apply it in the current mode.
    # Great for wallpaper-rotation cron jobs / systemd timers.
    current="$(current_theme)"
    mode="dark"
    is_dark_theme "$current" 2>/dev/null || mode="light"
    current_family="${current%-dark}"
    [[ "$current_family" != "$current" ]] || current_family="${current%-light}"
    mapfile -t families < <(paired_families)
    if [[ ${#families[@]} -eq 0 ]]; then
      ui_err "No themes" "run 'dot theme rebuild' first"
      exit 1
    fi
    # Filter out the current family so `random` always changes something.
    picks=()
    for f in "${families[@]}"; do
      [[ "$f" != "$current_family" ]] && picks+=("$f")
    done
    [[ ${#picks[@]} -eq 0 ]] && picks=("${families[@]}")
    pick="${picks[RANDOM % ${#picks[@]}]}"
    set_theme "${pick}-${mode}"
    ;;
  help | --help | -h)
    ui_header "Usage"
    ui_info "dot theme" "[command]"
    echo ""
    ui_header "Commands"
    ui_ok "(no args)" "Interactive theme picker (fzf)"
    ui_ok "list" "Show all available themes"
    ui_ok "set [NAME]" "Set theme (interactive if no name)"
    ui_ok "toggle" "Toggle between light/dark within current family"
    ui_ok "family" "Cycle to the next family"
    ui_ok "random" "Pick a random family, keep current mode"
    ui_ok "preview [NAME]" "Try a theme, ENTER to keep or Ctrl-C to revert"
    ui_ok "undo" "Step back to the previous theme (re-run to toggle)"
    ui_ok "history" "Show recently-applied themes"
    ui_ok "reset" "Restore GNOME defaults (accent/cursor/fonts/shell theme)"
    ui_ok "current" "Show current theme info"
    ui_ok "status" "Dashboard: recorded vs applied theme state"
    ui_ok "sync" "Sync dotfiles with system dark/light mode"
    ui_ok "ambient" "Time-based mode switch (run|enable|disable|status)"
    ui_ok "rebuild" "Regenerate themes from system + custom wallpapers"
    echo ""
    show_current
    ;;
  "")
    pick_theme
    ;;
  *)
    # Treat unknown args as theme names for quick switching: dot theme macos-sequoia-dark
    if grep -q "^\[themes\.${1}\]" "$THEMES_FILE" 2>/dev/null; then
      dot-theme-sync "$1"
    else
      ui_err "Unknown command or theme" "$1"
      ui_info "Usage" "dot theme [list|set <name>|toggle|family|current|help]"
      exit 1
    fi
    ;;
esac
