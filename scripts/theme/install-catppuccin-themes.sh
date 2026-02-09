#!/bin/bash
# Catppuccin GNOME Theme Installation Script
# Installs Catppuccin GTK themes, icon themes, and shell themes

set -e

THEME_DIR="$HOME/.themes"
ICON_DIR="$HOME/.icons"
TEMP_DIR="/tmp/catppuccin-install"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[INFO]${NC} $1"
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

# Create directories
mkdir -p "$THEME_DIR" "$ICON_DIR" "$TEMP_DIR"

# Check if git is available
if ! command -v git &> /dev/null; then
    error "git is required but not installed."
    exit 1
fi

# Function to install GTK themes
install_gtk_themes() {
    log "Installing Catppuccin GTK themes..."

    cd "$TEMP_DIR"

    if [ ! -d "catppuccin-gtk" ]; then
        git clone https://github.com/catppuccin/gtk.git catppuccin-gtk
    else
        cd catppuccin-gtk && git pull && cd ..
    fi

    cd catppuccin-gtk

    # Install all variants
    for variant in Latte Frappe Macchiato Mocha; do
        for accent in Blue; do  # Focus on blue accent for consistency
            theme_name="Catppuccin-$variant-Standard-$accent"
            if [ "$variant" = "Latte" ]; then
                theme_name="$theme_name-Light"
            else
                theme_name="$theme_name-Dark"
            fi

            log "Installing $theme_name..."
            if [ -d "themes/$theme_name" ]; then
                cp -r "themes/$theme_name" "$THEME_DIR/"
                success "Installed $theme_name"
            else
                warn "Theme $theme_name not found in repository"
            fi
        done
    done
}

# Function to install Papirus icon theme
install_papirus_icons() {
    log "Installing Papirus icon themes..."

    cd "$TEMP_DIR"

    if [ ! -d "papirus-icon-theme" ]; then
        git clone https://github.com/PapirusDevelopmentTeam/papirus-icon-theme.git
    else
        cd papirus-icon-theme && git pull && cd ..
    fi

    cd papirus-icon-theme

    # Install Papirus variants
    for variant in Papirus Papirus-Dark Papirus-Light; do
        if [ -d "$variant" ]; then
            log "Installing $variant icons..."
            cp -r "$variant" "$ICON_DIR/"
            success "Installed $variant"
        fi
    done
}

# Function to install Catppuccin cursors
install_catppuccin_cursors() {
    log "Installing Catppuccin cursor themes..."

    cd "$TEMP_DIR"

    if [ ! -d "catppuccin-cursors" ]; then
        git clone https://github.com/catppuccin/cursors.git catppuccin-cursors
    else
        cd catppuccin-cursors && git pull && cd ..
    fi

    cd catppuccin-cursors

    # Install cursor themes for each variant
    for variant in Catppuccin-Latte-* Catppuccin-Frappe-* Catppuccin-Macchiato-* Catppuccin-Mocha-*; do
        if [ -d "cursors/$variant" ]; then
            log "Installing cursor theme $variant..."
            cp -r "cursors/$variant" "$ICON_DIR/"
            success "Installed cursor theme $variant"
        fi
    done
}

# Function to install GNOME Shell themes
install_shell_themes() {
    log "Installing GNOME Shell themes..."

    # Check if user-themes extension is available
    if command -v gnome-extensions &> /dev/null; then
        if ! gnome-extensions list | grep -q "user-theme"; then
            warn "User Themes extension not found. Install it from GNOME Extensions."
            warn "Run: gnome-extensions install user-theme@gnome-shell-extensions.gcampax.github.com"
        fi
    fi

    cd "$TEMP_DIR"

    if [ ! -d "catppuccin-gnome-shell" ]; then
        git clone https://github.com/catppuccin/gnome.git catppuccin-gnome-shell
    else
        cd catppuccin-gnome-shell && git pull && cd ..
    fi

    cd catppuccin-gnome-shell

    # Install shell themes (use explicit names for portability)
    for variant in Latte Frappe Macchiato Mocha; do
        theme_name="Catppuccin-${variant}"
        if [ -d "themes/$theme_name" ]; then
            log "Installing GNOME Shell theme $theme_name..."
            cp -r "themes/$theme_name" "$THEME_DIR/"
            success "Installed GNOME Shell theme $theme_name"
        fi
    done
}

# Function to install wallpapers
install_wallpapers() {
    log "Installing Catppuccin wallpapers..."

    local wallpaper_dir="/usr/share/backgrounds/catppuccin"
    local user_wallpaper_dir="$HOME/.local/share/backgrounds/catppuccin"

    # Try system directory first, fallback to user directory
    if [ -w "/usr/share/backgrounds" ] || sudo -n true 2>/dev/null; then
        sudo mkdir -p "$wallpaper_dir" 2>/dev/null || {
            warn "Cannot create system wallpaper directory, using user directory"
            wallpaper_dir="$user_wallpaper_dir"
            mkdir -p "$wallpaper_dir"
        }
    else
        wallpaper_dir="$user_wallpaper_dir"
        mkdir -p "$wallpaper_dir"
    fi

    cd "$TEMP_DIR"

    if [ ! -d "catppuccin-wallpapers" ]; then
        git clone https://github.com/catppuccin/wallpapers.git catppuccin-wallpapers
    else
        cd catppuccin-wallpapers && git pull && cd ..
    fi

    cd catppuccin-wallpapers

    # Copy wallpapers
    for variant in latte frappe macchiato mocha; do
        for image in os/*.png misc/*.png; do
            if [[ "$image" == *"$variant"* ]]; then
                log "Installing wallpaper: $(basename "$image")"
                if [ -w "$wallpaper_dir" ]; then
                    cp "$image" "$wallpaper_dir/cat_$variant.png"
                else
                    sudo cp "$image" "$wallpaper_dir/cat_$variant.png"
                fi
            fi
        done
    done

    success "Installed Catppuccin wallpapers to $wallpaper_dir"
}

# Function to apply GTK theme refresh
refresh_gtk() {
    log "Refreshing GTK theme cache..."

    # Update GTK icon cache
    if command -v gtk-update-icon-cache &> /dev/null; then
        for theme_dir in "$ICON_DIR"/*; do
            if [ -d "$theme_dir" ] && [ -f "$theme_dir/index.theme" ]; then
                gtk-update-icon-cache -f "$theme_dir" 2>/dev/null || true
            fi
        done
    fi

    # Reload GNOME Shell (if running)
    if [ "$XDG_CURRENT_DESKTOP" = "GNOME" ] && command -v gnome-shell &> /dev/null; then
        log "Reloading GNOME Shell..."
        # Alt+F2, r, Enter - but we'll use dbus for safety
        if command -v busctl &> /dev/null; then
            busctl --user call org.gnome.Shell /org/gnome/Shell org.gnome.Shell Eval s 'Meta.restart("Themes updated")' 2>/dev/null || true
        fi
    fi

    success "GTK theme cache refreshed"
}

# Function to provide installation summary
show_summary() {
    echo ""
    echo "=== Installation Summary ==="
    echo ""
    echo "Installed themes are now available in:"
    echo "  GTK Themes: $THEME_DIR"
    echo "  Icon Themes: $ICON_DIR"
    echo "  Wallpapers: $wallpaper_dir"
    echo ""
    echo "To apply themes:"
    echo "  1. Use GNOME Tweaks or Extensions app"
    echo "  2. Or use the dot theme switcher:"
    echo "     dot theme set catppuccin-mocha"
    echo "     dot theme set catppuccin-latte"
    echo ""
    echo "Available Catppuccin themes:"
    echo "  - catppuccin-latte (light)"
    echo "  - catppuccin-frappe (dark - muted)"
    echo "  - catppuccin-macchiato (dark - balanced)"
    echo "  - catppuccin-mocha (dark - rich)"
    echo ""
}

# Function to check dependencies
check_dependencies() {
    local missing_deps=()

    # Check required commands
    for cmd in git; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    # Check optional commands
    for cmd in gnome-tweaks gnome-extensions; do
        if ! command -v "$cmd" &> /dev/null; then
            warn "Optional dependency missing: $cmd"
        fi
    done

    if [ ${#missing_deps[@]} -gt 0 ]; then
        error "Missing required dependencies: ${missing_deps[*]}"
        echo "Please install them and run this script again."
        exit 1
    fi
}

# Main execution
main() {
    echo "=== Catppuccin GNOME Theme Installer ==="
    echo ""

    check_dependencies

    log "Starting Catppuccin theme installation..."

    install_gtk_themes
    install_papirus_icons
    install_catppuccin_cursors
    install_shell_themes
    install_wallpapers
    refresh_gtk

    show_summary

    success "Catppuccin theme installation completed!"

    # Cleanup
    log "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
}

# Handle script arguments
case "${1:-install}" in
    install|"")
        main
        ;;
    gtk)
        install_gtk_themes
        refresh_gtk
        ;;
    icons)
        install_papirus_icons
        refresh_gtk
        ;;
    cursors)
        install_catppuccin_cursors
        ;;
    shell)
        install_shell_themes
        ;;
    wallpapers)
        install_wallpapers
        ;;
    refresh)
        refresh_gtk
        ;;
    help)
        echo "Usage: $0 [install|gtk|icons|cursors|shell|wallpapers|refresh|help]"
        echo ""
        echo "  install     Install all Catppuccin theme components (default)"
        echo "  gtk         Install only GTK themes"
        echo "  icons       Install only icon themes"
        echo "  cursors     Install only cursor themes"
        echo "  shell       Install only GNOME Shell themes"
        echo "  wallpapers  Install only wallpapers"
        echo "  refresh     Refresh theme cache"
        echo "  help        Show this help message"
        ;;
    *)
        error "Unknown option: $1"
        echo "Use '$0 help' for usage information."
        exit 1
        ;;
esac