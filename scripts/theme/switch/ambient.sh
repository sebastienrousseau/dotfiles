#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck shell=bash
# Sourced by switch.sh; inherits set -euo pipefail
# Light/dark following for dot theme: system appearance, sync, the ambient
# (sunrise/sunset) timer, manual mode and wallpaper rotation.
# Sourced by scripts/theme/switch.sh.

# Detect system appearance. KDE Plasma's color scheme is included so KDE
# users get the same auto-sync as GNOME and macOS users.
system_appearance_mode() {
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
      # GNOME family via gsettings
      if command -v gsettings >/dev/null 2>&1; then
        local scheme
        scheme=$(gsettings get org.gnome.desktop.interface color-scheme 2>/dev/null | tr -d "'")
        if [[ "$scheme" == "prefer-light" ]]; then
          os_mode="light"
        elif [[ "$scheme" == "prefer-dark" || "$scheme" == "default" ]]; then
          os_mode="dark"
        fi
      fi
      # KDE — kreadconfig6 wins on KDE sessions
      if command -v kreadconfig6 >/dev/null 2>&1; then
        local kde_scheme
        kde_scheme="$(kreadconfig6 --file kdeglobals --group General --key ColorScheme 2>/dev/null)"
        case "$kde_scheme" in
          *Light* | *light*) os_mode="light" ;;
          *Dark* | *dark*) os_mode="dark" ;;
        esac
      fi
      ;;
  esac

  printf '%s\n' "$os_mode"
}

# Resolve the selected family to the system appearance and retain auto mode.
# `--if-auto` is used by the macOS LaunchAgent so a manual dark/light choice
# is never overridden in the background.
sync_theme() {
  local condition="${1:-}"
  if [[ "$condition" == "--if-auto" && "$(theme_mode_preference)" != "auto" ]]; then
    ui_info "Sync" "manual mode active — automatic sync skipped"
    return 0
  fi

  local os_mode
  os_mode="$(system_appearance_mode)"

  local current
  current="$(current_theme)"
  local current_mode="dark"
  is_dark_theme "$current" 2>/dev/null || current_mode="light"

  if [[ "$current_mode" == "$os_mode" ]]; then
    if [[ "$(theme_mode_preference)" == "auto" ]]; then
      ui_ok "Sync" "Dotfiles already match system ($os_mode mode, auto)"
      return 0
    fi
  fi
  ui_info "Sync" "System is $os_mode — switching from $current_mode..."
  local family
  family="${current%-dark}"
  [[ "$family" != "$current" ]] || family="${current%-light}"
  set_theme "${family}-${os_mode}" --auto
}

# Ambient auto-switch: pick light|dark based on time of day.
# Sunrise/sunset resolution ladder:
#   1. DOT_THEME_SUNRISE / DOT_THEME_SUNSET env vars
#   2. sunwait if installed AND DOT_THEME_LOCATION="lat,lon" is set
#      (e.g. DOT_THEME_LOCATION="51.5N,0.13W")
#   3. State file at ~/.local/state/dot/theme-ambient.conf
#   4. Fixed defaults: 07:00 / 19:00
# Applies to the current wallpaper family — never changes wallpaper choice.
ambient_theme() {
  local sunrise sunset now hour minute now_min sunrise_min sunset_min desired
  local state_file="${XDG_STATE_HOME:-$HOME/.local/state}/dot/theme-ambient.conf"
  local resolved_source="defaults"

  # Priority 1: env vars
  sunrise="${DOT_THEME_SUNRISE:-}"
  sunset="${DOT_THEME_SUNSET:-}"
  [[ -n "$sunrise$sunset" ]] && resolved_source="env"

  # Priority 2: sunwait + location
  if [[ (-z "$sunrise" || -z "$sunset") && -n "${DOT_THEME_LOCATION:-}" ]] && command -v sunwait >/dev/null 2>&1; then
    IFS=',' read -r lat lon <<<"$DOT_THEME_LOCATION"
    if [[ -n "$lat" && -n "$lon" ]]; then
      # sunwait "list rise/set civil <lat> <lon>" prints HH:MM
      local computed_rise computed_set
      computed_rise="$(sunwait list rise "$lat" "$lon" 2>/dev/null | head -1)"
      computed_set="$(sunwait list set "$lat" "$lon" 2>/dev/null | head -1)"
      if [[ "$computed_rise" =~ ^[0-9]{2}:[0-9]{2}$ && "$computed_set" =~ ^[0-9]{2}:[0-9]{2}$ ]]; then
        sunrise="${sunrise:-$computed_rise}"
        sunset="${sunset:-$computed_set}"
        resolved_source="sunwait($DOT_THEME_LOCATION)"
      fi
    fi
  fi

  # Priority 3: state file
  if [[ (-z "$sunrise" || -z "$sunset") && -f "$state_file" ]]; then
    # shellcheck disable=SC1090
    source "$state_file"
    sunrise="${sunrise:-${DOT_THEME_SUNRISE:-}}"
    sunset="${sunset:-${DOT_THEME_SUNSET:-}}"
    [[ -n "$sunrise$sunset" ]] && resolved_source="state-file"
  fi

  # Priority 4: defaults
  sunrise="${sunrise:-07:00}"
  sunset="${sunset:-19:00}"

  # Convert HH:MM strings to minutes since midnight for cheap comparison.
  IFS=':' read -r hour minute <<<"$sunrise"
  sunrise_min=$((10#$hour * 60 + 10#$minute))
  IFS=':' read -r hour minute <<<"$sunset"
  sunset_min=$((10#$hour * 60 + 10#$minute))
  now="$(date +%H:%M)"
  IFS=':' read -r hour minute <<<"$now"
  now_min=$((10#$hour * 60 + 10#$minute))

  if ((now_min >= sunrise_min && now_min < sunset_min)); then
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
    ui_ok "Ambient" "$current — already matches (${resolved_source} sunrise=$sunrise sunset=$sunset now=$now)"
    return 0
  fi
  ui_info "Ambient" "$current -> $target (${resolved_source} sunrise=$sunrise sunset=$sunset now=$now)"
  set_theme "$target"
}

# Install/uninstall systemd user timer that runs `dot theme ambient` hourly.
ambient_enable() {
  local unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  mkdir -p "$unit_dir"
  local dot_path
  dot_path="$(command -v dot 2>/dev/null || echo "$HOME/.local/bin/dot")"

  cat >"$unit_dir/dot-theme-ambient.service" <<EOF
[Unit]
Description=Ambient theme switch (dot theme ambient)
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=${dot_path} theme ambient
EOF

  cat >"$unit_dir/dot-theme-ambient.timer" <<EOF
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

# dot theme mode
_theme_cmd_mode() {
  shift
  want="${1:-}"
  case "$want" in
    dark | light) : ;;
    auto)
      sync_theme "" # no condition: always sync
      exit 0
      ;;
    *)
      ui_err "Usage" "dot theme mode <dark|light|auto>"
      exit 1
      ;;
  esac
  current="$(current_theme)"
  family="${current%-dark}"
  [[ "$family" != "$current" ]] || family="${current%-light}"
  target="${family}-${want}"
  if [[ "$current" == "$target" && "$(theme_mode_preference)" == "$want" ]]; then
    ui_ok "Mode" "$current — already in $want mode"
  else
    set_theme "$target"
  fi
}

# dot theme rotate
# Periodic wallpaper rotator built on the same timer pattern as
# `dot theme ambient`. Applies `dot theme random --mode <current>`
# on the requested interval so the wallpaper family cycles while
# the ambient timer independently drives light/dark.
_theme_cmd_rotate() {
  shift
  case "${1:-}" in
    enable | "")
      interval="${2:-30m}"
      # Accept 5m / 1h / 30s / 3600 (raw seconds also fine — systemd
      # OnUnitActiveSec is quite forgiving).
      unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
      mkdir -p "$unit_dir"
      dot_path="$(command -v dot 2>/dev/null || echo "$HOME/.local/bin/dot")"
      cat >"$unit_dir/dot-theme-rotate.service" <<EOF
[Unit]
Description=Rotate wallpaper family (dot theme random)
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=${dot_path} theme random
EOF
      cat >"$unit_dir/dot-theme-rotate.timer" <<EOF
[Unit]
Description=Rotate wallpaper family on interval

[Timer]
OnStartupSec=1m
OnUnitActiveSec=${interval}
AccuracySec=30s
Persistent=true

[Install]
WantedBy=timers.target
EOF
      systemctl --user daemon-reload
      systemctl --user enable --now dot-theme-rotate.timer
      ui_ok "Rotate" "timer enabled — will fire every $interval"
      ;;
    disable)
      systemctl --user disable --now dot-theme-rotate.timer 2>/dev/null || true
      unit_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
      rm -f "$unit_dir/dot-theme-rotate.service" "$unit_dir/dot-theme-rotate.timer"
      systemctl --user daemon-reload
      ui_ok "Rotate" "timer disabled and removed"
      ;;
    status)
      if systemctl --user is-active dot-theme-rotate.timer >/dev/null 2>&1; then
        ui_ok "Timer" "active"
        systemctl --user list-timers dot-theme-rotate.timer --no-pager 2>&1 | grep -v '^$' | tail -3
      else
        ui_info "Timer" "inactive — run 'dot theme rotate enable [interval]'"
      fi
      ;;
    *)
      ui_err "Usage" "dot theme rotate [enable [interval]|disable|status]"
      exit 1
      ;;
  esac
}

# dot theme ambient
_theme_cmd_ambient() {
  shift
  case "${1:-run}" in
    run | "") ambient_theme ;;
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
}
