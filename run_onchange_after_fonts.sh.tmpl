#!/bin/sh
# Universal Nerd Font checker/installer
# Inspired by 2026 terminal aesthetics

if [ -t 1 ] && command -v gum >/dev/null 2>&1; then
    gum style --foreground 212 --border double --align center --width 50 "Font Check"
    if ! fc-list | grep -qi "Nerd Font"; then
        gum confirm "Nerd Font not found. Install 'FiraCode Nerd Font'?" && {
            gum spin --spinner dot --title "Installing font..." -- \
              bash -c 'curl -fLo "FiraCode.zip" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip && unzip -o FiraCode.zip -d ~/.local/share/fonts && fc-cache -f && rm FiraCode.zip'
        }
    else
        gum style --foreground 82 "󰄬 Nerd Fonts are present"
    fi
fi
