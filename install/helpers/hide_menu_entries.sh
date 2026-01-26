#!/usr/bin/env bash
# Hide duplicate/unwanted menu entries
# Strategy: Prefer Native (.deb) over Flatpak (com.*) to avoid duplicates.
set -euo pipefail

# Apps to HIDE (Flatpaks/Snaps/Other duplicates)
HIDDEN_APPS=(
    "vim.desktop"                # Prefer Neovim
    "com.google.Chrome.desktop"  # Hide Flatpak Chrome, keep Native
    "com.brave.Browser.desktop"  # Hide Flatpak Brave, keep Native
    "org.gnome.Tour.desktop"     # Zorin Tour
    "yelp.desktop"               # Help
    "webapp-manager.desktop"     # Web App Manager (often redundant)
    "avahi-discover.desktop"
    "bssh.desktop"
    "bvnc.desktop"
)

# Apps to RESTORE (Unhide Native versions if previously hidden)
RESTORE_APPS=(
    "google-chrome.desktop"
    "brave-browser.desktop"
)

mkdir -p ~/.local/share/applications

echo "--- Hiding Duplicates ---"
for app in "${HIDDEN_APPS[@]}"; do
    # Check if the app exists in system path (ignore if not installed)
    if [ -f "/usr/share/applications/$app" ] || [ -f "/var/lib/flatpak/exports/share/applications/$app" ]; then
        echo "Hiding $app..."
        # Copy from system to local if not already there, OR just overwrite to be sure
        if [ -f "/usr/share/applications/$app" ]; then
            cp "/usr/share/applications/$app" ~/.local/share/applications/
        elif [ -f "/var/lib/flatpak/exports/share/applications/$app" ]; then
            cp "/var/lib/flatpak/exports/share/applications/$app" ~/.local/share/applications/
        fi
        
        # Ensure NoDisplay is true in the [Desktop Entry] section
        if grep -q "NoDisplay=" "$HOME/.local/share/applications/$app"; then
             sed -i 's/^NoDisplay=false/NoDisplay=true/g' "$HOME/.local/share/applications/$app"
        else
             # Insert NoDisplay=true after [Desktop Entry]
             sed -i '/^\[Desktop Entry\]/a NoDisplay=true' "$HOME/.local/share/applications/$app"
        fi
    fi
done

echo "--- Restoring Native Apps ---"
for app in "${RESTORE_APPS[@]}"; do
    if [ -f "$HOME/.local/share/applications/$app" ]; then
        echo "Restoring $app (Removing hidden override)..."
        rm "$HOME/.local/share/applications/$app"
    fi
done

update-desktop-database ~/.local/share/applications
echo "Menu cleanup complete."
