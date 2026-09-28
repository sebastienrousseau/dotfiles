# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
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
print_step() {
  local step_msg="$1"
  echo
  printf '%b\n' "${GREEN} ${step_msg}${RESET}"
}

# print_note: Prints a note message
print_note() {
  local note_msg="$1"
  printf '%b\n' "${BLUE}${note_msg}${RESET}"
}

# print_error: Prints an error message
print_error() {
  local error_msg="$1"
  printf '%b\n' "${RED} ERROR: ${error_msg}${RESET}" >&2
}

# detect_os: Detects the operating system
detect_os() {
  case "$(uname -s)" in
    Darwin*) echo "macOS" ;;
    Linux*) echo "Linux" ;;
    MINGW* | MSYS*) echo "Windows" ;;
    *) echo "Unknown" ;;
  esac
}

# cmd_exists: Checks if a command exists
cmd_exists() {
  command -v "$1" >/dev/null 2>&1
}

#-------------------------------#
# macOS Update Functions        #
#-------------------------------#

update_mac() {
  print_step "Updating macOS system software"
  if sudo /usr/sbin/softwareupdate -i -a | grep -q "No updates are available"; then
    print_note "macOS is up-to-date."
  else
    print_note "macOS updates installed successfully."
  fi

  if cmd_exists brew; then
    print_step "Updating Homebrew packages"
    brew update >/dev/null
    if brew upgrade | grep -q "already up-to-date"; then
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
    if mas upgrade | grep -q "No updates available"; then
      print_note "No App Store updates available."
    else
      print_note "App Store apps updated successfully."
    fi
  fi
}

#-------------------------------#
# Linux Update Functions        #
#-------------------------------#

update_linux() {
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

update_windows() {
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

# _upt_report: note whether <output> says the tool was already current.
# Usage: _upt_report <output> <up-to-date pattern> <same msg> <updated msg>
_upt_report() {
  if echo "$1" | grep -q "$2"; then
    print_note "$3"
  else
    print_note "$4"
  fi
}

# _upt_update: when <tool> is installed, run <command...> and report.
# Usage: _upt_update <tool> <step> <pattern> <same msg> <updated msg> <command...>
_upt_update() {
  local tool="$1" step="$2" pattern="$3" same="$4" updated="$5" output
  shift 5
  cmd_exists "${tool}" || return 0
  print_step "${step}"
  output=$("$@" 2>&1)
  _upt_report "${output}" "${pattern}" "${same}" "${updated}"
}

_upt_gem() {
  cmd_exists gem || return 0
  print_step "Updating RubyGems and installed gems"
  gem update --system >/dev/null 2>&1 && print_note "RubyGems system updated successfully."
  _upt_report "$(gem update 2>&1)" "Nothing to update" \
    "All Ruby gems are already up to date." "Ruby gems updated successfully."
  gem cleanup && print_note "Ruby gems cleanup completed."
}

_upt_brew() {
  cmd_exists brew || return 0
  print_step "Updating Homebrew packages"
  brew update >/dev/null
  _upt_report "$(brew upgrade 2>&1)" "already up-to-date" \
    "Homebrew packages are already up to date." "Homebrew packages updated successfully."
  brew cleanup && print_note "Homebrew cleanup completed."
}

_upt_go() {
  local go_output
  cmd_exists go || return 0
  print_step "Checking for Go module updates"
  go_output=$(go list -u -m all 2>&1)
  if echo "${go_output}" | grep -q "no updates"; then
    print_note "All Go modules are already up to date."
  else
    go get -u all && print_note "Go modules updated successfully."
  fi
}

# Last step of update_programming_tools, so its status is the caller's.
_upt_vscode() {
  local vscode_output
  cmd_exists code || return 0
  print_step "Updating Visual Studio Code extensions"
  vscode_output=$(code --list-extensions --show-versions 2>&1)
  if echo "${vscode_output}" | grep -q "No updates available"; then
    print_note "All Visual Studio Code extensions are already up to date."
  else
    code --update-extensions && print_note "Visual Studio Code extensions updated successfully."
  fi
}

update_programming_tools() {
  _upt_update npm "Updating npm global packages" "up to date" \
    "npm global packages are already up to date." "npm global packages updated successfully." \
    npm update -g
  _upt_update pnpm "Updating pnpm global packages" "Nothing to update" \
    "pnpm global packages are already up to date." "pnpm global packages updated successfully." \
    pnpm up -g
  _upt_update rustup "Updating Rust toolchain" "unchanged" \
    "Rust toolchain is already up to date." "Rust toolchain updated successfully." \
    rustup update stable
  _upt_update cargo "Updating Cargo binaries" "All packages are up to date" \
    "Cargo binaries are already up to date." "Cargo binaries updated successfully." \
    cargo install-update -a
  _upt_gem
  _upt_brew
  _upt_go
  _upt_update deno "Updating Deno runtime" "already up to date" \
    "Deno is already up to date." "Deno updated successfully." \
    deno upgrade
  _upt_vscode
}

#-------------------------------#
# Main Update Function          #
#-------------------------------#

upd() {
  local os_name
  os_name="$(detect_os)"
  printf '%b\n' "${GREEN} Detected OS: ${os_name}${RESET}"

  # Run OS-specific updates
  case "${os_name}" in
    macOS) update_mac ;;
    Linux) update_linux ;;
    Windows) update_windows ;;
    *)
      print_note "Unsupported operating system. Exiting..."
      return 1
      ;;
  esac

  # Update development tools
  update_programming_tools

  echo " Installation complete – you're all set."
}

# Run Topgrade if available, otherwise fall back to upd.
update() {
  if cmd_exists topgrade; then
    print_step "Running Topgrade"
    topgrade "$@"
    return $?
  fi

  print_note "Topgrade not found. Falling back to 'upd'."
  upd "$@"
}

#-------------------------------#
# Script Entry Point            #
#-------------------------------#

# If the script is executed directly, inform the user about sourcing
if [[ "${BASH_SOURCE[0]}" = "${0}" ]]; then
  printf '%b\n' "${GREEN} Source this script and run 'upd' to start the update process.${RESET}"
fi
