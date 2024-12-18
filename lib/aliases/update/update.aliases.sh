#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Cross-Platform System Update Script
#
# Author: Sebastien Rousseau
# Description:
#   A comprehensive cross-platform system update script for macOS, Linux, and
#   Windows. It updates system software, programming tools, and cleans up resources.
#
# Usage:
#   1. Source it: source update.sh && upd
#
################################################################################

#-------------------------------#
# Color Variables               #
#-------------------------------#
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
RESET='\033[0m'

#-------------------------------#
# Utility Functions             #
#-------------------------------#

# print_step: Prints a step message
function print_step() {
    local step_msg="$1"
    echo
    echo -e "${GREEN}❯ ${step_msg}${RESET}"
}

# print_note: Prints a note message
function print_note() {
    local note_msg="$1"
    echo -e "${BLUE}${note_msg}${RESET}"
}

# print_error: Prints an error message
function print_error() {
    local error_msg="$1"
    echo -e "${RED}❯ ERROR: ${error_msg}${RESET}" >&2
}

# detect_os: Detects the operating system
function detect_os() {
    case "$(uname -s)" in
        Darwin*) echo "macOS" ;;
        Linux*) echo "Linux" ;;
        MINGW*|MSYS*) echo "Windows" ;;
        *) echo "Unknown" ;;
    esac
}

# cmd_exists: Checks if a command exists
function cmd_exists() {
    command -v "$1" >/dev/null 2>&1
}

#-------------------------------#
# macOS Update Functions        #
#-------------------------------#

function update_mac() {
    print_step "Updating macOS system software"
    if sudo /usr/sbin/softwareupdate -i -a | grep -q "No updates are available" || true; then
        print_note "macOS is up-to-date."
    else
        print_note "macOS updates installed successfully."
    fi

    if cmd_exists brew; then
        print_step "Updating Homebrew packages"
        brew update >/dev/null
        if brew upgrade | grep -q "already up-to-date" || true; then
            print_note "Homebrew packages are already up-to-date."
        else
            print_note "Homebrew packages updated successfully."
        fi
        brew cleanup || print_note "Cleaning up Homebrew."
    else
        print_note "Homebrew not installed. Skipping package updates."
    fi

    # Update App Store apps
    if cmd_exists mas; then
        print_step "Updating App Store apps"
        if mas upgrade | grep -q "No updates available" || true; then
            print_note "No App Store updates available."
        else
            print_note "App Store apps updated successfully."
        fi
    fi
}

#-------------------------------#
# Linux Update Functions        #
#-------------------------------#

function update_linux() {
    if cmd_exists apt-get; then
        print_step "Updating Linux packages with apt"
        sudo apt-get update
        sudo apt-get upgrade -y
        sudo apt-get dist-upgrade -y
        sudo apt-get autoremove -y
        sudo apt-get clean
    elif cmd_exists dnf; then
        print_step "Updating Linux packages with dnf"
        sudo dnf check-update
        sudo dnf upgrade -y
        sudo dnf autoremove -y
        sudo dnf clean all
    elif cmd_exists pacman; then
        print_step "Updating Linux packages with pacman"
        sudo pacman -Syu --noconfirm
        sudo pacman -Sc --noconfirm
    elif cmd_exists zypper; then
        print_step "Updating Linux packages with zypper"
        sudo zypper refresh
        sudo zypper update -y
        sudo zypper clean
    else
        print_note "No supported Linux package manager found. Skipping updates."
    fi

    # Flatpak updates if available
    if cmd_exists flatpak; then
        print_step "Updating Flatpak applications"
        flatpak update -y
        flatpak uninstall --unused -y
    fi

    # Snap updates if available
    if cmd_exists snap; then
        print_step "Updating Snap packages"
        sudo snap refresh
    fi
}

#-------------------------------#
# Windows Update Functions      #
#-------------------------------#

function update_windows() {
    print_step "Updating Windows packages"

    if cmd_exists choco; then
        print_step "Updating Chocolatey packages"
        choco upgrade all -y || print_error "Chocolatey update encountered issues."
        choco cleanup -y
    elif cmd_exists winget; then
        print_step "Updating Winget packages"
        winget upgrade --all || print_error "Winget update encountered issues."
    else
        print_note "No supported package manager found. Skipping updates."
    fi

    # Scoop updates if available
    if cmd_exists scoop; then
        print_step "Updating Scoop packages"
        scoop update
        scoop update '*'
        scoop cleanup '*'
    fi
}

#-------------------------------#
# Programming Environment Tools #
#-------------------------------#

function update_programming_tools() {
    # npm
    if cmd_exists npm; then
        print_step "Updating npm global packages"
        npm_output=$(npm update -g 2>&1)
        if echo "${npm_output}" | grep -q "up to date" || true; then
            print_note "npm global packages are already up to date."
        else
            print_note "npm global packages updated successfully."
        fi
    fi

    # pnpm
    if cmd_exists pnpm; then
        print_step "Updating pnpm global packages"
        pnpm_output=$(pnpm up -g 2>&1)
        if echo "${pnpm_output}" | grep -q "Nothing to update" || true; then
            print_note "pnpm global packages are already up to date."
        else
            print_note "pnpm global packages updated successfully."
        fi
    fi

    # Rust toolchain
    if cmd_exists rustup; then
        print_step "Updating Rust toolchain"
        rust_output=$(rustup update stable 2>&1)
        if echo "${rust_output}" | grep -q "unchanged" || true; then
            print_note "Rust toolchain is already up to date."
        else
            print_note "Rust toolchain updated successfully."
        fi
    fi

    # Cargo binaries
    if cmd_exists cargo; then
        print_step "Updating Cargo binaries"
        cargo_output=$(cargo install-update -a 2>&1)
        if echo "${cargo_output}" | grep -q "All packages are up to date" || true; then
            print_note "Cargo binaries are already up to date."
        else
            print_note "Cargo binaries updated successfully."
        fi
    fi

    # Ruby Gems
    if cmd_exists gem; then
        print_step "Updating RubyGems and installed gems"
        gem update --system >/dev/null 2>&1 && print_note "RubyGems system updated successfully."
        gem_output=$(gem update 2>&1)
        if echo "${gem_output}" | grep -q "Nothing to update" || true; then
            print_note "All Ruby gems are already up to date."
        else
            print_note "Ruby gems updated successfully."
        fi
        gem cleanup && print_note "Ruby gems cleanup completed."
    fi

    # Homebrew
    if cmd_exists brew; then
        print_step "Updating Homebrew packages"
        brew update >/dev/null
        brew_output=$(brew upgrade 2>&1)
        if echo "${brew_output}" | grep -q "already up-to-date" || true; then
            print_note "Homebrew packages are already up to date."
        else
            print_note "Homebrew packages updated successfully."
        fi
        brew cleanup && print_note "Homebrew cleanup completed."
    fi

    # Go modules
    if cmd_exists go; then
        print_step "Checking for Go module updates"
        go_output=$(go list -u -m all 2>&1)
        if echo "${go_output}" | grep -q "no updates" || true; then
            print_note "All Go modules are already up to date."
        else
            go get -u all && print_note "Go modules updated successfully."
        fi
    fi

    # Deno
    if cmd_exists deno; then
        print_step "Updating Deno runtime"
        deno_output=$(deno upgrade 2>&1)
        if echo "${deno_output}" | grep -q "already up to date" || true; then
            print_note "Deno is already up to date."
        else
            print_note "Deno updated successfully."
        fi
    fi

    # VS Code extensions
    if cmd_exists code; then
        print_step "Updating Visual Studio Code extensions"
        vscode_output=$(code --list-extensions --show-versions 2>&1)
        if echo "${vscode_output}" | grep -q "No updates available" || true; then
            print_note "All Visual Studio Code extensions are already up to date."
        else
            code --update-extensions && print_note "Visual Studio Code extensions updated successfully."
        fi
    fi
}


#-------------------------------#
# Main Update Function          #
#-------------------------------#

function upd() {
    local os_name
    os_name="$(detect_os)"
    echo -e "${GREEN}❯ Detected OS: ${os_name}${RESET}"

    # Run OS-specific updates
    case "${os_name}" in
        macOS) update_mac ;;
        Linux) update_linux ;;
        Windows) update_windows ;;
        *) print_note "Unsupported operating system. Exiting..."; return 1 ;;
    esac

    # Update development tools
    update_programming_tools

    echo "✅ Installation complete – you're all set."
}

#-------------------------------#
# Script Entry Point            #
#-------------------------------#

# If the script is executed directly, inform the user about sourcing
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo -e "${GREEN}❯ Source this script and run 'upd' to start the update process.${RESET}"
fi