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

  # Preview helper: awk-extracts the theme's accent + wallpaper + full
  # 16-colour ANSI palette, then renders live swatches using 24-bit
  # terminal escapes. Fast — one awk pass, no forks-per-swatch, no
  # image decoding.
  local preview_cmd
  preview_cmd='family={2}; mode='"$current_mode"'; f="'"$THEMES_FILE"'"; awk -v F="$family" -v M="$mode" '"'"'
BEGIN {
  root = "[themes." F "-" M "]"
  ui   = "[themes." F "-" M ".ui]"
  term = "[themes." F "-" M ".term]"
  esc  = sprintf("%c[", 27)
}
function hex2int(h,   n, i, c, digits) {
  digits = "0123456789abcdef"
  n = 0
  h = tolower(h)
  for (i = 1; i <= length(h); i++) {
    c = index(digits, substr(h, i, 1))
    if (c == 0) return 0
    n = n * 16 + (c - 1)
  }
  return n
}
function swatch(hex,   clean, r, g, b) {
  clean = hex
  sub(/^#/, "", clean)
  r = hex2int(substr(clean, 1, 2))
  g = hex2int(substr(clean, 3, 2))
  b = hex2int(substr(clean, 5, 2))
  return esc "48;2;" r ";" g ";" b "m    " esc "0m"
}
$0 == root { in_root=1; in_ui=0; in_term=0; next }
$0 == ui   { in_ui=1; in_root=0; in_term=0; next }
$0 == term { in_term=1; in_root=0; in_ui=0; next }
/^\[/ { in_root=0; in_ui=0; in_term=0; next }
in_root && /^wallpaper /   { sub(/.*= *"?/,""); sub(/"$/,""); wallpaper=$0 }
in_root && /^macos_accent/ { sub(/.*= */,"");   accent_int=$0 }
in_ui && /^accent /        { sub(/.*= *"?/,""); sub(/"$/,""); accent=$0 }
in_term && /^bg /          { sub(/.*= *"?/,""); sub(/"$/,""); bg=$0 }
in_term && /^fg /          { sub(/.*= *"?/,""); sub(/"$/,""); fg=$0 }
in_term && match($0, /^c([0-9]+) *= *"([^"]+)"/, m) { term_c[m[1]+0] = m[2] }
END {
  print "family:    " F " (" M ")"
  print "wallpaper: " wallpaper
  print "accent:    " swatch(accent) " " accent " (macos=" accent_int ")"
  print "bg:        " swatch(bg) " " bg
  print "fg:        " swatch(fg) " " fg
  print ""
  # 16-colour ANSI palette, laid out 8 wide × 2 rows.
  line1 = ""; line2 = ""
  for (i = 0; i <= 7; i++)  line1 = line1 swatch(term_c[i])
  for (i = 8; i <= 15; i++) line2 = line2 swatch(term_c[i])
  print "palette:"
  print "  " line1
  print "  " line2
}'"'"' "$f"'

  local selected_family
  selected_family="$(echo "$theme_list" | fzf \
    --header "Select wallpaper theme (current: $current_family [$current_mode], TAB = preview)" \
    --prompt "Theme > " \
    --height 30 \
    --reverse \
    --no-sort \
    --ansi \
    --preview "$preview_cmd" \
    --preview-window "right:45%:wrap" |
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

# Detect system appearance (Dark/Light) and sync dotfiles. Also picks up
# KDE Plasma's color scheme (BreezeLight vs BreezeDark), so KDE users get
# the same auto-sync as GNOME users.
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
          *Light*|*light*) os_mode="light" ;;
          *Dark*|*dark*) os_mode="dark" ;;
        esac
      fi
      ;;
  esac

  local current
  current="$(current_theme)"
  local current_mode="dark"
  is_dark_theme "$current" 2>/dev/null || current_mode="light"

  if [[ "$current_mode" == "$os_mode" ]]; then
    ui_ok "Sync" "Dotfiles already match system ($os_mode mode)"
    return 0
  fi
  ui_info "Sync" "System is $os_mode — switching from $current_mode..."
  local family
  family="${current%-dark}"
  [[ "$family" != "$current" ]] || family="${current%-light}"
  set_theme "${family}-${os_mode}"
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
  mode)
    shift
    want="${1:-}"
    case "$want" in
      dark|light) : ;;
      *) ui_err "Usage" "dot theme mode <dark|light>"; exit 1 ;;
    esac
    current="$(current_theme)"
    family="${current%-dark}"
    [[ "$family" != "$current" ]] || family="${current%-light}"
    target="${family}-${want}"
    if [[ "$current" == "$target" ]]; then
      ui_ok "Mode" "$current — already in $want mode"
    else
      set_theme "$target"
    fi
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
  diff)
    shift
    if [[ $# -lt 2 ]]; then
      ui_err "Usage" "dot theme diff <theme-a> <theme-b>"
      exit 1
    fi
    a="$1"; b="$2"
    if ! grep -q "^\[themes\.${a}\]$" "$THEMES_FILE"; then
      ui_err "Unknown" "theme '$a'"; exit 1
    fi
    if ! grep -q "^\[themes\.${b}\]$" "$THEMES_FILE"; then
      ui_err "Unknown" "theme '$b'"; exit 1
    fi
    ui_header "Theme diff: $a  vs  $b"
    awk -v A="$a" -v B="$b" '
      BEGIN {
        esc = sprintf("%c[", 27)
        for (side in slot) delete slot[side]
      }
      function set_slot(name, section, key, value) {
        # `section` is "" for root, "app" or "ui" or "term"
        slot[name "." section "." key] = value
      }
      function get(name, section, key) {
        return slot[name "." section "." key]
      }
      function hex2int(h,   n,i,c,d) {
        d="0123456789abcdef"; n=0; h=tolower(h)
        for(i=1;i<=length(h);i++){c=index(d,substr(h,i,1)); if(c==0)return 0; n=n*16+(c-1)}
        return n
      }
      function swatch(hex,  s,r,g,b) {
        if (hex == "" || hex !~ /^#/) return "    "
        s = substr(hex, 2)
        r = hex2int(substr(s,1,2)); g = hex2int(substr(s,3,2)); b = hex2int(substr(s,5,2))
        return esc "48;2;" r ";" g ";" b "m    " esc "0m"
      }
      function val(line,   v) { v=line; sub(/^[^=]*= *"?/,"",v); sub(/"?[[:space:]]*$/,"",v); return v }
      {
        if ($0 == "[themes." A "]")      { name=A; section=""; next }
        else if ($0 == "[themes." A ".ui]")   { name=A; section="ui"; next }
        else if ($0 == "[themes." A ".term]") { name=A; section="term"; next }
        else if ($0 == "[themes." B "]")      { name=B; section=""; next }
        else if ($0 == "[themes." B ".ui]")   { name=B; section="ui"; next }
        else if ($0 == "[themes." B ".term]") { name=B; section="term"; next }
        else if (/^\[/) { name=""; section=""; next }
      }
      name != "" && /=/ {
        key = $0; sub(/ *=.*/, "", key)
        set_slot(name, section, key, val($0))
      }
      function row(label, left, right) {
        mark = (left == right ? " " : "≠")
        printf "  %s  %-14s  %-24s  %-24s\n", mark, label, left, right
      }
      function row_sw(label, left, right) {
        mark = (left == right ? " " : "≠")
        printf "  %s  %-14s  %s %-18s  %s %-18s\n", mark, label, swatch(left), left, swatch(right), right
      }
      END {
        row("family",       get(A,"","family"),        get(B,"","family"))
        row("mode",         get(A,"","mode"),          get(B,"","mode"))
        row("macos_accent", get(A,"","macos_accent"),  get(B,"","macos_accent"))
        row("wallpaper",    get(A,"","wallpaper"),     get(B,"","wallpaper"))
        row_sw("ui.accent", get(A,"ui","accent"),      get(B,"ui","accent"))
        row_sw("term.bg",   get(A,"term","bg"),        get(B,"term","bg"))
        row_sw("term.fg",   get(A,"term","fg"),        get(B,"term","fg"))
      }
    ' "$THEMES_FILE"
    ;;
  wallpaper)
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
      ui_err "Wallpaper" "file not found: $wp"; exit 1
    fi
    # Detect DE (inlined mini-detector matching dot-theme-sync).
    raw="$(printf '%s' "${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-}}" | tr '[:upper:]' '[:lower:]')"
    case "$raw" in
      *kde*|*plasma*) de=kde ;;
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
    ;;
  accent)
    # Live-tweak the desktop accent colour without changing the theme
    # or the wallpaper. Accepts either a GNOME accent enum name
    # (blue|teal|green|yellow|orange|red|pink|purple|slate) or an
    # int 0-6 / -1 matching the macos_accent scale. Applies via the
    # detected DE handler; skips silently on DEs without native accent.
    shift
    want="${1:-}"
    if [[ -z "$want" ]]; then
      ui_info "Current" "accent"
      command -v gsettings >/dev/null 2>&1 \
        && ui_info "GNOME" "$(gsettings get org.gnome.desktop.interface accent-color 2>/dev/null | tr -d "'")"
      command -v kreadconfig6 >/dev/null 2>&1 \
        && ui_info "KDE" "$(kreadconfig6 --file kdeglobals --group General --key AccentColor 2>/dev/null)"
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
      blue|teal|green|yellow|orange|red|pink|purple|slate) : ;;
      *) ui_err "Usage" "dot theme accent <int -1..6 | blue|teal|green|yellow|orange|red|pink|purple|slate>"; exit 1 ;;
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
    # Pick a random paired family and apply it. Default mode = current
    # mode; override with `--mode dark|light`.
    shift
    _rand_mode=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --mode)
          shift
          case "${1:-}" in
            dark|light) _rand_mode="$1" ;;
            *) ui_err "Usage" "--mode dark|light"; exit 1 ;;
          esac
          shift
          ;;
        --mode=*) _rand_mode="${1#--mode=}"; shift ;;
        *) ui_err "Usage" "dot theme random [--mode dark|light]"; exit 1 ;;
      esac
    done
    current="$(current_theme)"
    if [[ -z "$_rand_mode" ]]; then
      _rand_mode="dark"
      is_dark_theme "$current" 2>/dev/null || _rand_mode="light"
    fi
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
    set_theme "${pick}-${_rand_mode}"
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
    ui_ok "mode <dark|light>" "Idempotently force a mode (no-op if already there)"
    ui_ok "family" "Cycle to the next family"
    ui_ok "random" "Pick a random family, keep current mode"
    ui_ok "preview [NAME]" "Try a theme, ENTER to keep or Ctrl-C to revert"
    ui_ok "undo" "Step back to the previous theme (re-run to toggle)"
    ui_ok "history" "Show recently-applied themes"
    ui_ok "reset" "Restore GNOME defaults (accent/cursor/fonts/shell theme)"
    ui_ok "current" "Show current theme info"
    ui_ok "status" "Dashboard: recorded vs applied theme state"
    ui_ok "diff <a> <b>" "Side-by-side comparison of two themes"
    ui_ok "accent [color]" "Tweak accent live (no wallpaper/theme change)"
    ui_ok "wallpaper [path]" "Set an arbitrary wallpaper without theme swap"
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
