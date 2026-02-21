#!/usr/bin/env bash
## Apply GNOME Theme — Apply Catppuccin themes to GNOME desktop.
##
## Configures GTK theme, icon theme, cursor theme, shell theme,
## fonts, and wallpaper using gsettings.
##
## # Requirements
## - gsettings: GNOME settings tool
## - gnome-extensions (optional): For shell themes
## - User Themes extension (optional): For custom shell themes
##
## # Usage
## apply-gnome-theme.sh catppuccin-mocha     # Apply dark theme
## apply-gnome-theme.sh catppuccin-latte     # Apply light theme
## apply-gnome-theme.sh current              # Show current theme
## apply-gnome-theme.sh backup               # Backup current settings
##
## # Platform Notes
## - GNOME 42+: Full color-scheme support
## - Older GNOME: Color scheme setting skipped

set -euo pipefail

THEME_NAME="${1:-}"

if [ -z "$THEME_NAME" ]; then
  echo "Usage: $0 <theme-name>"
  echo "Available themes: catppuccin-latte, catppuccin-frappe, catppuccin-macchiato, catppuccin-mocha"
  exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  echo -e "${BLUE}[GNOME]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Check if we're running GNOME
if [ "$XDG_CURRENT_DESKTOP" != "GNOME" ] && [ "$XDG_SESSION_DESKTOP" != "gnome" ]; then
  warn "Not running GNOME desktop. Some settings may not apply."
fi

# Function to check if gsettings is available
check_gsettings() {
  if ! command -v gsettings &>/dev/null; then
    error "gsettings command not found. Please install GLib development tools."
    exit 1
  fi
}

# Function to apply Catppuccin theme settings
apply_catppuccin_theme() {
  local theme="$1"
  local gtk_theme=""
  local shell_theme=""
  local icon_theme=""
  local cursor_theme="Adwaita"
  local color_scheme="prefer-light"

  case "$theme" in
    catppuccin-latte)
      gtk_theme="Catppuccin-Latte-Standard-Blue-Light"
      shell_theme="Catppuccin-Latte"
      icon_theme="Papirus-Light"
      cursor_theme="Catppuccin-Latte-Blue"
      color_scheme="prefer-light"
      ;;
    catppuccin-frappe)
      gtk_theme="Catppuccin-Frappe-Standard-Blue-Dark"
      shell_theme="Catppuccin-Frappe"
      icon_theme="Papirus-Dark"
      cursor_theme="Catppuccin-Frappe-Blue"
      color_scheme="prefer-dark"
      ;;
    catppuccin-macchiato)
      gtk_theme="Catppuccin-Macchiato-Standard-Blue-Dark"
      shell_theme="Catppuccin-Macchiato"
      icon_theme="Papirus-Dark"
      cursor_theme="Catppuccin-Macchiato-Blue"
      color_scheme="prefer-dark"
      ;;
    catppuccin-mocha)
      gtk_theme="Catppuccin-Mocha-Standard-Blue-Dark"
      shell_theme="Catppuccin-Mocha"
      icon_theme="Papirus-Dark"
      cursor_theme="Catppuccin-Mocha-Blue"
      color_scheme="prefer-dark"
      ;;
    *)
      # Non-Catppuccin themes - use fallback
      if [[ "$theme" == *"-dark"* ]] || [[ "$theme" == *"-night"* ]] || [[ "$theme" == *"-storm"* ]] || [[ "$theme" == *"-moon"* ]] || [[ "$theme" == *"-mocha"* ]]; then
        gtk_theme="Adwaita-dark"
        shell_theme=""
        icon_theme="Papirus-Dark"
        color_scheme="prefer-dark"
      else
        gtk_theme="Adwaita"
        shell_theme=""
        icon_theme="Papirus"
        color_scheme="prefer-light"
      fi
      ;;
  esac

  log "Applying GNOME theme: $theme"

  # Apply GTK theme
  log "Setting GTK theme to: $gtk_theme"
  gsettings set org.gnome.desktop.interface gtk-theme "$gtk_theme"

  # Apply icon theme
  log "Setting icon theme to: $icon_theme"
  gsettings set org.gnome.desktop.interface icon-theme "$icon_theme"

  # Apply cursor theme
  log "Setting cursor theme to: $cursor_theme"
  gsettings set org.gnome.desktop.interface cursor-theme "$cursor_theme"

  # Apply color scheme (GNOME 42+)
  if gsettings list-keys org.gnome.desktop.interface | grep -q "color-scheme"; then
    log "Setting color scheme to: $color_scheme"
    gsettings set org.gnome.desktop.interface color-scheme "$color_scheme"
  fi

  # Apply window manager theme
  log "Setting window manager theme"
  gsettings set org.gnome.desktop.wm.preferences theme "$gtk_theme"

  # Apply shell theme (requires User Themes extension)
  if [ -n "$shell_theme" ]; then
    # Check if user-theme extension is enabled
    if command -v gnome-extensions &>/dev/null; then
      if gnome-extensions list --enabled | grep -q "user-theme"; then
        log "Setting GNOME Shell theme to: $shell_theme"
        gsettings set org.gnome.shell.extensions.user-theme name "$shell_theme"
      else
        warn "User Themes extension is not enabled. Shell theme not applied."
        warn "Enable it with: gnome-extensions enable user-theme@gnome-shell-extensions.gcampax.github.com"
      fi
    else
      # Fallback: try to set it anyway
      log "Setting GNOME Shell theme to: $shell_theme"
      gsettings set org.gnome.shell.extensions.user-theme name "$shell_theme" 2>/dev/null ||
        warn "Could not set shell theme. User Themes extension may not be installed."
    fi
  fi

  # Apply font settings
  log "Setting font preferences"
  gsettings set org.gnome.desktop.interface font-name 'Inter 10'
  gsettings set org.gnome.desktop.interface document-font-name 'Inter 10'
  gsettings set org.gnome.desktop.interface monospace-font-name 'JetBrains Mono 10'
  gsettings set org.gnome.desktop.wm.preferences titlebar-font 'Inter Bold 10'

  # Apply cursor size
  gsettings set org.gnome.desktop.interface cursor-size 24

  # Apply other interface settings
  gsettings set org.gnome.desktop.interface enable-animations true
  gsettings set org.gnome.desktop.interface enable-hot-corners true
  gsettings set org.gnome.desktop.interface text-scaling-factor 1.0

  # Apply window manager preferences
  gsettings set org.gnome.desktop.wm.preferences button-layout 'close,minimize,maximize:'
  gsettings set org.gnome.mutter dynamic-workspaces true
  gsettings set org.gnome.mutter edge-tiling true

  # Apply wallpaper if available
  apply_wallpaper "$theme"

  success "GNOME theme '$theme' applied successfully!"
}

# Function to apply wallpaper
apply_wallpaper() {
  local theme="$1"
  local wallpaper_path=""

  # Check for system wallpapers first
  if [ -d "/usr/share/backgrounds/catppuccin" ]; then
    case "$theme" in
      catppuccin-latte)
        wallpaper_path="/usr/share/backgrounds/catppuccin/cat_latte.png"
        ;;
      catppuccin-frappe)
        wallpaper_path="/usr/share/backgrounds/catppuccin/cat_frappe.png"
        ;;
      catppuccin-macchiato)
        wallpaper_path="/usr/share/backgrounds/catppuccin/cat_macchiato.png"
        ;;
      catppuccin-mocha)
        wallpaper_path="/usr/share/backgrounds/catppuccin/cat_mocha.png"
        ;;
    esac
  fi

  # Fallback to user wallpapers
  if [ ! -f "$wallpaper_path" ] && [ -d "$HOME/.local/share/backgrounds/catppuccin" ]; then
    case "$theme" in
      catppuccin-latte)
        wallpaper_path="$HOME/.local/share/backgrounds/catppuccin/cat_latte.png"
        ;;
      catppuccin-frappe)
        wallpaper_path="$HOME/.local/share/backgrounds/catppuccin/cat_frappe.png"
        ;;
      catppuccin-macchiato)
        wallpaper_path="$HOME/.local/share/backgrounds/catppuccin/cat_macchiato.png"
        ;;
      catppuccin-mocha)
        wallpaper_path="$HOME/.local/share/backgrounds/catppuccin/cat_mocha.png"
        ;;
    esac
  fi

  if [ -f "$wallpaper_path" ]; then
    log "Setting wallpaper: $wallpaper_path"
    gsettings set org.gnome.desktop.background picture-uri "file://$wallpaper_path"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$wallpaper_path"
    gsettings set org.gnome.desktop.screensaver picture-uri "file://$wallpaper_path"
    success "Wallpaper set to Catppuccin theme wallpaper"
  else
    warn "Catppuccin wallpaper not found for theme: $theme"
    log "Install wallpapers with: $HOME/.dotfiles/scripts/theme/install-catppuccin-themes.sh wallpapers"
  fi
}

# Function to backup current settings
backup_settings() {
  local backup_file
  backup_file="$HOME/.config/gnome-theme-backup-$(date +%Y%m%d-%H%M%S).dconf"

  log "Backing up current GNOME settings to: $backup_file"

  dconf dump /org/gnome/desktop/interface/ >"$backup_file.interface" 2>/dev/null || true
  dconf dump /org/gnome/desktop/wm/preferences/ >"$backup_file.wm" 2>/dev/null || true
  dconf dump /org/gnome/shell/extensions/user-theme/ >"$backup_file.shell" 2>/dev/null || true

  if [ -f "$backup_file.interface" ]; then
    success "Settings backed up successfully"
  else
    warn "Could not create backup. Continuing without backup."
  fi
}

# Function to show current theme
show_current_theme() {
  echo "Current GNOME theme settings:"
  echo "  GTK Theme: $(gsettings get org.gnome.desktop.interface gtk-theme)"
  echo "  Icon Theme: $(gsettings get org.gnome.desktop.interface icon-theme)"
  echo "  Cursor Theme: $(gsettings get org.gnome.desktop.interface cursor-theme)"
  echo "  Shell Theme: $(gsettings get org.gnome.shell.extensions.user-theme name 2>/dev/null || echo "'Not set or extension not available'")"
  if gsettings list-keys org.gnome.desktop.interface | grep -q "color-scheme"; then
    echo "  Color Scheme: $(gsettings get org.gnome.desktop.interface color-scheme)"
  fi
}

# Main execution
main() {
  check_gsettings

  case "$THEME_NAME" in
    current)
      show_current_theme
      ;;
    backup)
      backup_settings
      ;;
    *)
      # Check if theme files exist
      theme_exists=false

      case "$THEME_NAME" in
        catppuccin-*)
          for _d in "$HOME/.themes/Catppuccin-"*; do
            if [ -d "$_d" ]; then
              theme_exists=true
              break
            fi
          done
          ;;
        *)
          theme_exists=true # Assume Adwaita and other system themes exist
          ;;
      esac

      if [ "$theme_exists" = "false" ]; then
        warn "Catppuccin themes not found. Installing them first..."
        "$HOME/.dotfiles/scripts/theme/install-catppuccin-themes.sh"
      fi

      backup_settings
      apply_catppuccin_theme "$THEME_NAME"
      ;;
  esac
}

main
