# shellcheck shell=bash
# 🆂🆄🅱🆅🅴🆁🆂🅸🅾🅽 🅰🅻🅸🅰🆂🅴🆂
if command -v 'svn' >/dev/null; then
  alias sad='svn add'        # sad: Put new files and directories under version control.
  alias sau='svn auth'       # sau: Manage cached authentication credentials.
  alias sbl='svn blame'      # sbl: Show when each line of a file was last (or next) changed.
  alias scg='svn changelist' # scg: Associate (or dissociate) changelist CLNAME with the named files.
  alias sci='svn commit'     # sci: Send changes from your working copy to the repository.
  alias scl='svn cleanup'    # scl: Either recover from an interrupted operation that left the working copy locked, or remove unwanted files.
  alias sco='svn checkout'   # sco: Check out a working copy from a repository.
  alias scp='svn copy'       # scp: Copy files and directories in a working copy or repository.
  alias sct='svn cat'        # sct: Output the content of specified files or URLs.
  alias sdi='svn diff'       # sdi: Display local changes or differences between two revisions or paths.
  alias sdl='svn delete'     # sdl: Remove files and directories from version control.
  alias shp='svn help'       # shp: Describe the usage of this program or its subcommands.
  alias sin='svn info'       # sin: Display information about a local or remote item.
  alias sip='svn import'     # sip: Commit an unversioned file or tree into the repository.
  alias slg='svn log'        # slg: Show the log messages for a set of revision(s) and/or path(s).
  alias slk='svn lock'       # slock: Lock working copy paths or URLs in the repository, so that no other user can commit changes to them.
  alias sls='svn list'       # sls: List directory entries in the repository.
  alias smd='svn mkdir'      # smd: Create a new directory under version control.
  alias smg='svn merge'      # smg: Merge changes into a working copy.
  alias smgi='svn mergeinfo' # smgi: Display merge-related information.
  alias smv='svn move'       # smv: Move (rename) an item in a working copy or repository.
  alias sp='svn propset'     # sp: Set the value of a property on files, dirs, or revisions.
  alias spdl='svn propdel'   # spdl: Remove a property from files, dirs, or revisions.
  alias spdt='svn propedit'  # spdt: Edit a property with an external editor.
  alias spgt='svn propget'   # spgt: Print the value of a property on files, dirs, or revisions.
  alias sph='svn patch'      # sph: Apply a patch to a working copy.
  alias spls='svn proplist'  # spls: List all properties on files, dirs, or revisions.
  alias srl='svn relocate'   # srl: Relocate the working copy to point to a different repository root URL.
  alias srs='svn resolve'    # srs: Resolve conflicts on working copy files or directories.
  alias srsd='svn resolved'  # srsd: Remove 'conflicted' state on working copy files or directories.
  alias srv='svn revert'     # srv: Restore pristine working copy state (undo local changes).
  alias sst='svn status'     # sst: Print the status of working copy files and directories.
  alias ssw='svn switch'     # ssw: Update the working copy to a different URL within the same repository.
  alias sulk='svn unlock'    # sulk: Unlock working copy paths or URLs.
  alias sup='svn update'     # sup: Bring changes from the repository into the working copy.
  alias supg='svn upgrade'   # supg: Upgrade the metadata storage format for a working copy.
  alias sxp='svn export'     # sxp: Create an unversioned copy of a tree.
fi
#!/usr/bin/env bash
# Installer & Teleport Aliases

# Run the local installer (self-update/bootstrap)
alias dot-install='bash $HOME/.local/share/chezmoi/install.sh'

# Teleport config to a remote host
# Usage: dot-teleport user@host
alias telegram='bash $HOME/.local/share/chezmoi/scripts/teleport.sh'
alias dot-teleport='telegram'
# shellcheck shell=bash
# 🆂🆄🅳🅾 🅰🅻🅸🅰🆂🅴🆂

# Execute a command as the superuser.
root() { command sudo -i; }

# Execute a command as the superuser.
s() { command sudo -i; }

# Execute a command as the superuser.
alias su='sudo su'

# shellcheck shell=bash
#!/usr/bin/env bash
# Modern Tooling Aliases (Rust Replacements) & Listing

# Eza (Replacement for ls) OR Fallback
# Disabled because .zshrc handles this explicitly with better defaults
if command -v eza >/dev/null; then
  : # alias ls="eza --icons --group-directories-first"
  : # alias ll="eza -alF --icons --group-directories-first"
  : # alias la="eza -a --icons --group-directories-first"
  : # alias lt="eza -aT --icons --group-directories-first"
else
  # Fallback to ls
  : # alias ls='ls'
  : # alias l='ls'
  : # alias ll='ls -lA'
  : # alias llm='ls -ltA'
  : # alias la='ls -a'
  : # alias lx='ls -la'
fi

# Tree (or fallback)
if command -v tree >/dev/null; then
    alias tree='tree'
else
    alias tree='ls -R'
fi

# Bat (Replacement for cat)
if command -v bat >/dev/null; then
  alias cat="bat"
fi

# Ripgrep (Replacement for grep)
if command -v rg >/dev/null; then
  # alias grep="rg" # Disabled: Breaks scripts
  alias rg="rg"
fi

# Zoxide (Replacement for cd)
# Initialized in .zshrc via query
# shellcheck shell=bash
# Version: 0.2.472
# Website: https://dotfiles.io

# 🅳🅸🅶 🅰🅻🅸🅰🆂🅴🆂
if command -v dig &>/dev/null; then
  # d: Run the dig command with the default options.
  alias d='$(which dig)'

  # d4: Perform a DNS lookup for an IPv4 address.
  alias d4='$(which dig) +short -4'

  # d6: Perform a DNS lookup for an IPv6 address.
  alias d6='$(which dig) +short -6'

  # dga: Perform a DNS lookup for all records.
  alias dga='$(which dig) +all ANY'

  # dgs: Perform a DNS lookup for a short answer.
  alias dgs='$(which dig) +short'

  # digg: Dig with Google's DNS.
  alias digg='$(which dig) @8.8.8.8 +nocmd any +multiline +noall +answer'

  # ip4: Get your public IPv4 address.
  alias ip4='$(which dig) +short myip.opendns.com @resolver1.opendns.com -4'

  # ip6: Get your public IPv6 address.
  alias ip6='$(which dig) -6 AAAA +short myip.opendns.com. @resolver1.opendns.com.'

  # ips: Get your public IPv4 and IPv6 addresses.
  alias ips='ip4; ip6'

  # wip: Get your public IP address.
  alias wip='$(which dig) +short myip.opendns.com @resolver1.opendns.com'

fi
# shellcheck shell=bash
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
fi# shellcheck shell=bash
# Git Aliases
#
# Sections:
# 1. Core
# 2. Working Area (add, checkout, etc.)
# 3. History (log, diff, show)
# 4. Branches & Remotes
# 5. Advanced (submodules, stashing, etc.)

if command -v git &>/dev/null; then

  # --- Core ---
  alias g='git'
  alias gconfdiff='git config alias.dcolor "diff --color-words"'
  alias gconfl='git config --list'
  alias gconfr='git config --local --get remote.origin.url'
  alias gtp='git rev-parse --show-toplevel'
  alias grpa='git rev-parse --abbrev-ref HEAD'

  # --- Working Area ---
  alias ga='git add'
  alias gaa='git add --all'
  alias gad='git add .'
  alias gau='git add --update'
  
  alias gcl='git clone'
  alias gin='git init'
  
  alias gco='git checkout'
  alias gcb='git checkout -b'
  alias gdis='git checkout --' # changed from checkout to git checkout for safety checking
  alias grs='git restore'
  alias gmv='git mv'
  alias grm='git rm'
  alias grmc='git rm --cached'
  
  alias gst='git status'
  alias gsts='git status --short'
  alias gstsb='git status --short --branch'

  alias gsta='git stash save '
  alias gstp='git stash pop'
  alias gstd='git stash drop'

  alias gclout='git clean -df && git checkout -- .'

  # --- Commits ---
  alias gc='git commit -a'
  alias gca='git commit --amend'
  alias gcall='git add -A && git commit -av'
  alias gcam='git commit --amend --message '
  alias gcane='git commit --amend --no-edit'
  alias gcm='git commit --message '
  
  # --- Diff & History ---
  alias gd='git diff'
  alias gdch='git diff --name-status'
  alias gdh='git diff HEAD'
  alias gdstaged='git diff --staged'
  alias gdcached='git diff --cached'
  alias gdstat='git diff --stat --ignore-space-change -r'
  
  alias gl='git log --since="last month" --oneline'
  alias glg='git log --graph --all --oneline --decorate'
  alias glgg='git log --oneline --graph --full-history --all --color --decorate'
  alias glc='git log --oneline --reverse'
  alias gld='git log --since=1-day-ago'
  alias gldc='git log -1 --date-order --format=%cI'
  alias gldl='git log --date=local'
  alias glf='git log ORIG_HEAD.. --stat --no-merges'
  alias gll='git log --graph --topo-order --date=short --abbrev-commit --decorate --all --boundary --pretty=format:"%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn]%Creset %Cblue%G?%Creset"'
  
  # --- Branches ---
  alias gb='git branch'
  alias gbd='git branch -d'
  alias gbl='git branch -l'
  alias gbr='git branch -r'
  alias gbrd='git branch -d -r'
  alias gbrsb='git show-branch'
  alias gswb='git switch'
  
  alias gcode='git checkout main && git branch --merged | xargs git branch --delete'
  alias gcom='git checkout main && git fetch origin --prune && git reset --hard origin/main'

  # --- Remotes & Comparison ---
  alias gf='git fetch'
  alias gp='git pull'
  alias gph='git push'
  alias gpo='git push origin'
  alias gpb='git push --set-upstream origin $(git branch --show-current)'
  alias gpoll='git push origin --all'
  alias gpull='git pull'
  alias gpush='git push'
  
  alias gr='git remote'
  alias gra='git remote add'
  alias grall='git remote | xargs -L1 git push --all'
  alias grao='git remote add origin'
  alias grv='git remote -v'

  # --- Revert & Reset ---
  alias grev='git revert'
  alias grevnc='git revert --no-commit'
  alias grb='git rebase'
  alias grbk='git reset --soft HEAD^'
  
  alias grescl='git reset --hard HEAD~1 && git clean -fd'
  alias gresh='git reset --hard HEAD~1'
  alias gresp='git reset --hard && git clean -ffdx'
  alias gress='git reset --soft HEAD~1'

  # --- Submodules ---
  alias gsm='git submodule'
  alias gsmi='git submodule init'
  alias gsma='git submodule add'
  alias gsms='git submodule sync'
  alias gsmu='git submodule update'
  alias gsmui='git submodule update --init'
  alias gsmuir='git submodule update --init --recursive'

  # --- Tools ---
  alias gg='git grep'
  alias gbs='git bisect'
  alias undopush="git push -f origin HEAD^:master"

fi
#!/usr/bin/env bash
# Git Signing & Security Aliases
# Simplifies GPG/SSH signing configuration.

# Enable Git Signing (Wizard)
enable_signing_fn() {
    echo "🔐 Git Signing Configuration Wizard"
    echo "-------------------------------------"
    echo "1) GPG (Standard)"
    echo "2) SSH (Modern/GitHub)"
    echo "3) Cancel"
    
    read -r -p "Select signing method [1-3]: " choice
    
    case "$choice" in
        1)
            local key_id
            read -r -p "Enter GPG Key ID: " key_id
            if [[ -n "$key_id" ]]; then
                git config --global user.signingkey "$key_id"
                git config --global commit.gpgsign true
                echo "✅ GPG signing enabled globally for key: $key_id"
            else
                echo "❌ No key ID provided."
            fi
            ;;
        2)
            local key_path
            read -r -p "Enter path to SSH public key (default: ~/.ssh/id_ed25519.pub): " key_path
            key_path="${key_path:-$HOME/.ssh/id_ed25519.pub}"
            if [[ -f "$key_path" ]]; then
                git config --global gpg.format ssh
                git config --global user.signingkey "$key_path"
                git config --global commit.gpgsign true
                echo "✅ SSH signing enabled globally using: $key_path"
            else
                echo "❌ Key file not found: $key_path"
            fi
            ;;
        *)
            echo "Operation cancelled."
            ;;
    esac
}
alias enable-signing=enable_signing_fn

# Verify signatures of latest commits
alias verify-signatures='git log --show-signature -n 10'

# Check if current config has signing enabled
alias check-signing='git config --list | grep "gpg\|signing"'
# shellcheck shell=bash
# 🅸🅽🆃🅴🆁🅰🅲🆃🅸🆅🅴 🅰🅻🅸🅰🆂🅴🆂

# File manipulation aliases

# cp: Copy files and directories interactively (ask before overwrite) with verbose output.
alias cp="cp -vi"

# del: Remove files or directories interactively (ask before each removal) with verbose output, recursively.
alias del="rm -rfvi"

# ln: Create symbolic links interactively (ask before overwrite) with verbose output.
alias ln='ln -vi'

# mv: Move or rename files interactively (ask before overwrite) with verbose output.
alias mv='mv -vi'

# rm: Remove files or directories interactively (ask before each removal) with verbose output.
alias rm='rm -vi'

# zap: Alias for 'rm', removes files or directories interactively (ask before each removal) with verbose output.
alias zap='rm -vi'

# Trash manipulation alias

# bin: Remove all files in the trash directory (user's .Trash) forcefully and recursively.
alias bin='rm -fr ${HOME}/.Trash'

# Other interactive aliases

# diff: Compare and show differences between two files in unified format.
alias diff='diff -u'

# mkdir: Create a new directory, making parent directories as needed, with verbose output.
alias mkdir='mkdir -pv'
# shellcheck shell=bash
# Copyright (c) 2015-2025. All rights reserved
# Description: Enhances terminal interaction with aliases for clearing the screen,
# navigating directories, and displaying directory contents in an organized manner.
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Configurable paths
WORKSPACE_DIR="${HOME}/workspace"

# Validate directory existence
function validate_dir() {
    if [[ ! -d "$1" ]]; then
        echo "Directory $1 not found."
        return 1
    fi
    return 0
}

# Functions for aliases
function cd_workspace() {
    validate_dir "${WORKSPACE_DIR}" && cd "${WORKSPACE_DIR}" || return
}

function clear_screen() {
    clear
}

function clear_list_current() {
    clear && ls -a
}

function clear_pwd_list() {
    clear && pwd && echo '' && ls -a && echo ''
}

function clear_pwd_tree() {
    clear && pwd && echo '' && tree ./ && echo ''
}

function clear_history() {
    clear && history
}

function print_working_dir() {
    pwd
}

function clear_print_tree() {
    clear && tree
}

# 🅲🅻🅴🅰🆁 🅰🅻🅸🅰🆂🅴🆂

# Alias definitions
alias cdw='cd_workspace'
alias c='clear_screen'
alias clc='clear_list_current'
alias cpl='clear_pwd_list'
alias cplt='clear_pwd_tree'
alias clh='clear_history'
alias cl='clear_screen'
alias clp='print_working_dir'
alias clt='clear_print_tree'
# shellcheck shell=bash
# 🅿🅽🅿🅼 🅰🅻🅸🅰🆂🅴🆂
if command -v 'pnpm' >/dev/null; then
  # Add a dependency to the project.
  alias pna='pnpm add'
  # Add a dev dependency to the project.
  alias pnad='pnpm add --save-dev'
  # Add a peer dependency to the project.
  alias pnap='pnpm add --save-peer'
  # Audit the project.
  alias pnau='pnpm audit'
  # Build the project.
  alias pnb='pnpm run build'
  # Create a new project.
  alias pnc='pnpm create'
  # Run the project in dev mode.
  alias pnd='pnpm run dev'
  # Generate the project documentation.
  alias pndoc='pnpm run doc'
  # Add a global dependency.
  alias pnga='pnpm add --global'
  # List all global dependencies.
  alias pngls='pnpm list --global'
  # Remove a global dependency.
  alias pngrm='pnpm remove --global'
  # Update a global dependency.
  alias pngu='pnpm update --global'
  # Show the help.
  alias pnh='pnpm help'
  # Initialize a new project.
  alias pni='pnpm init'
  # Install the project dependencies.
  alias pnin='pnpm install'
  # Lint the project.
  alias pnln='pnpm run lint'
  # List all dependencies.
  alias pnls='pnpm list'
  # Check for outdated dependencies.
  alias pnout='pnpm outdated'
  # Shortcut to pnpm.
  alias pnp='pnpm'
  # Publish the project.
  alias pnpub='pnpm publish'
  # Remove a dependency from the project.
  alias pnrm='pnpm remove'
  # Run a script from the project.
  alias pnrun='pnpm run'
  # Run the project in serve mode.
  alias pns='pnpm run serve'
  # Start the project.
  alias pnst='pnpm start'
  # Run the project in server mode.
  alias pnsv='pnpm server'
  # Test the project.
  alias pnt='pnpm test'
  # Test the project with coverage.
  alias pntc='pnpm test --coverage'
  # Update a dependency interactively.
  alias pnui='pnpm update --interactive'
  # Update a dependency interactively to the latest version.
  alias pnuil='pnpm update --interactive --latest'
  # Uninstall the project dependencies.
  alias pnun='pnpm uninstall'
  # Update a dependency.
  alias pnup='pnpm update'
  # Check why a dependency is installed.
  alias pnwhy='pnpm why'
  # Shortcut to pnpx.
  alias pnx='pnpx'
fi
# shellcheck shell=bash
# Copyright (c) 2015-2025. All rights reserved
# Description: Script containing default shell aliases
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Function: set_default_aliases
#
# Description:
#   Sets default shell aliases for enhanced shell usage.
#
# Arguments:
#   None
#
# Notes:
#   - Some aliases are designed for enhanced shell navigation and utility.
#   - Ensure to validate that all aliases work as expected in the bash shell.

set_default_aliases() {
    fc -W

    ## General aliases

    # Display the current date and time.
    alias da='date "+%Y-%m-%d %A %T %Z"'

    # Shortcut for `pwd` which returns working directory name.
    alias p='pwd'

    # Display the $PATH variable on newlines.
    alias path='echo ${PATH//:/\\n}'

    # Reload the shell.
    alias r='reload'

    # Prints the last 10 lines of a text or log file, and then waits for new
    # additions to the file to print it in real time.
    alias t='tail -f'

    # Show the current week number.
    alias wk='date +%V'

    ## Exit/shutdown aliases
    # Shortcut for the `exit` command.
    alias ':q'='quit'

    # Shortcut for the `exit` command.
    alias bye='quit'

    # Shortcut for the `exit` command.
    alias q='quit'

    # Shortcut for the `exit` command.
    alias quit='exit'

    # Shutdown the system.
    alias halt='sudo /sbin/halt'

    # Alias to view history
    alias h='history'
    alias history='fc -il 1' # Show history with ISO 8601 timestamps

    # Poweroff the system.
    alias poweroff='sudo /sbin/shutdown'

    # Reboot the system.
    alias reboot='sudo /sbin/reboot'

    ## Network aliases
    # Append sudo to ifconfig (configure network interface parameters)
    # command.
    alias ifconfig='sudo ifconfig'

    # Get network interface parameters for en0.
    alias ipinfo='ipconfig getpacket en0'

    # Show only active network listeners.
    alias nls='sudo lsof -i -P | grep LISTEN'

    # List of open ports.
    alias op='sudo lsof -i -P'

    # Limit Ping to 5 ECHO_REQUEST packets.
    alias ping='ping -c 5'

    # List all listening ports.
    alias ports='netstat -tulan'

    ## System monitoring aliases
    # Allows the user to interactively monitor the system's vital resources
    # or server's processes in real time.
    alias top='sudo btop'

    # Remove all log files in /private/var/log/asl/.
    alias spd='sudo rm -rf /private/var/log/asl/*'

    ## Utility aliases
    # Count the number of files in the current directory.
    alias ctf='echo $(ls -1 | wc -l)'

    # Quickly search for file.
    alias qfind='find . -name '

    # Reload the shell.
    alias reload='exec $SHELL -l'

    # Get the weather.
    alias wth='curl -s "wttr.in/?format=3"'

    ## File system navigation aliases
}

set_default_aliases
# shellcheck shell=bash

if command -v chmod &>/dev/null; then

  # Set permissions to no read, write, or execute for user, group, and
  # others.
  alias 000='chmod -R 000'

  # Set permissions to no read or write, but allow execute for user
  # only.
  alias 400='chmod -R 400'

  # Set permissions to no write or execute, but allow read for all.
  alias 444='chmod -R 444'

  # Set permissions to read and write for user only.
  alias 600='chmod -R 600'

  # Set permissions to read for all, but write only for user.
  alias 644='chmod -R 644'

  # Set permissions to read and write for all.
  alias 666='chmod -R 666'

  # Set permissions to read, write, and execute for user, but only read
  # and execute for group and others.
  alias 755='chmod -R 755'

  # Set permissions to read and write for user and group, but only read
  #  for others.
  alias 764='chmod -R 764'

  # Set permissions to read, write, and execute for all.
  alias 777='chmod -R 777'

  # Change group ownership of files or directories.
  alias chgrp='chgrp -v'

  # Change group ownership of files or directories recursively.
  alias chgrpr='chgrp -Rv'

  # Change group ownership of files or directories recursively to the
  #  current user.
  alias chgrpu='chgrp -Rv ${USER}'

  # Change file mode bits.
  alias chmod='chmod -v'

  # Change file mode bits recursively.
  alias chmodr='chmod -Rv'

  # Change file mode bits recursively to the current user.
  alias chmodu='chmod -Rv u+rwX'

  # Make a file executable.
  alias chmox='chmod +x'

  # Change file owner and group.
  alias chown='chown -v'

  # Change file owner and group recursively.
  alias chownr='chown -Rv'

  # Change file owner and group recursively to the current user.
  alias chownu='chown -Rv ${USER}'

fi
# shellcheck shell=bash
# 🆃🅼🆄🆇 🅰🅻🅸🅰🆂🅴🆂

if command -v 'tmux' >/dev/null; then
  # Basic commands
  tm() {
    if ! tmux has-session 2>/dev/null; then
      # Start tmux and immediately source the config
      tmux new-session -d \; source-file ~/.dotfiles/lib/configurations/tmux/tmux
      tmux attach
    else
      tmux "$@"
    fi
  } # Start tmux

  alias tma='tmux attach-session'     # Attach to last session
  alias tmat='tmux attach-session -t' # Attach to specific session

  # Session management
  alias tmks='tmux kill-session -a'   # Kill all sessions except current
  alias tmka='tmux kill-server'       # Kill all sessions (server)
  alias tml='tmux list-sessions'      # List all sessions

  # Creating sessions
  alias tmn='tmux new-session'        # New unnamed session
  alias tms='tmux new-session -s'     # New named session

  # Configuration
  alias tmr='tmux source ~/.dotfiles/lib/configurations/tmux/tmux' # Reload config

  # Windows and panes
  alias tmls='tmux list-windows'      # List windows
  alias tmlp='tmux list-panes'        # List panes

  # Status information
  alias tmi='tmux info'               # Show tmux info
fi
# shellcheck shell=bash
# AI & Intelligent Assistance Aliases

# GitHub Copilot CLI
if command -v gh &>/dev/null; then
  alias ghcp='gh copilot'
  alias ghs='gh copilot suggest'
  alias ghe='gh copilot explain'
fi

# Fabric (AI Helper)
if command -v fabric &>/dev/null; then
  alias fab='fabric'
fi

# Ollama (Local LLM)
if command -v ollama &>/dev/null; then
  alias ol='ollama'
  alias olr='ollama run'
  alias oll='ollama list'
fi
#!/usr/bin/env bash
# Compliance & Privacy Aliases

# Privacy Mode: Disables telemetry for common CLI tools
privacy_mode_fn() {
    export DOTNET_CLI_TELEMETRY_OPTOUT=1
    export HOMEBREW_NO_ANALYTICS=1
    export AZURE_CORE_COLLECT_TELEMETRY=0
    export FUNCTIONS_CORE_TOOLS_TELEMETRY_OPTOUT=1
    export SAM_CLI_TELEMETRY=0
    export STRIPE_TELEMETRY_OPTOUT=1
    export GATSBY_TELEMETRY_DISABLED=1
    export NEXT_TELEMETRY_DISABLED=1
    
    echo "🔒 Privacy Mode Enabled: Telemetry disabled for active session."
    echo "   (Dotnet, Homebrew, Azure, Stripe, Gatsby, Next.js)"
}

alias privacy-mode=privacy_mode_fn

# Audit Trail: View chezmoi application logs
# (Assuming chezmoi logs are piped or we verify git history as the audit trail)
audit_fn() {
    echo "📜 Configuration Audit Trail (Recent Changes)"
    echo "---------------------------------------------"
    if [[ -f "$HOME/.dotfiles_audit.log" ]]; then
        tail -n 20 "$HOME/.dotfiles_audit.log"
    else
        # Fallback to git log if custom audit log doesn't exist
        git -C "$HOME/.local/share/chezmoi" log --oneline -n 10 --format="%C(auto)%h %C(blue)%ad %C(reset)%s (%an)" --date=short
    fi
}

alias dot-audit=audit_fn
# shellcheck shell=bash
#-----------------------------------------------------------------------------
# Archive and Compression Management

extract() {
    if [ -z "$1" ]; then
        echo "Usage: extract <archive_file>"
        return 1
    fi

    if [ ! -f "$1" ]; then
        echo "Error: '$1' is not a valid file" | tee -a "$LOG_FILE"
        return 1
    fi

    # Create a log file if logging is enabled
    LOG_FILE=${ARCHIVE_LOG_FILE:-"$HOME/.archive_operations.log"}

    # Handle filenames with spaces correctly
    local filename="$1"
    # shellcheck disable="SC2034,SC2155"
    local dirname=$(dirname "$filename")
    # shellcheck disable="SC2034,SC2155"
    local basename=$(basename "$filename")

    # Create extract directory for archives with multiple files
    if [ "$2" = "-d" ] && [ ! -z "$3" ]; then
        mkdir -p "$3"
        cd "$3" || return 1
    fi

    case "$filename" in
        *.tar.bz2|*.tbz2) tar xvjf "$filename" ;;
        *.tar.gz|*.tgz)   tar xvzf "$filename" ;;
        *.tar.xz)         tar xvJf "$filename" ;;
        *.tar.zst)        tar --zstd -xvf "$filename" ;;
        *.tar)            tar xvf "$filename" ;;
        *.bz2)            bunzip2 "$filename" ;;
        *.gz)             gunzip "$filename" ;;
        *.rar)            unrar x "$filename" ;;
        *.zip)            unzip "$filename" ;;
        *.Z)              uncompress "$filename" ;;
        *.7z)             7z x "$filename" ;;
        *.zst)            unzstd "$filename" ;;
        *.xz)             unxz "$filename" ;;
        *.lz4)            lz4 -d "$filename" ;;
        *.lha|*.lzh)      lha e "$filename" ;;
        *.arj)            arj x "$filename" ;;
        *.arc)            arc e "$filename" ;;
        *.dms)            xdms u "$filename" ;;
        *)                echo "Error: '$filename' cannot be extracted - unknown format" | tee -a "$LOG_FILE" && return 1 ;;
    esac

    # Log successful extraction
    # shellcheck disable=SC2181
    if [ $? -eq 0 ]; then
        echo "Successfully extracted $filename" | tee -a "$LOG_FILE"
    else
        echo "Failed to extract $filename" | tee -a "$LOG_FILE"
    fi
}

#-----------------------------------------------------------------------------
# List Archive Contents Function
#-----------------------------------------------------------------------------
list_archive() {
    if [ -z "$1" ]; then
        echo "Usage: list_archive <archive_file>"
        return 1
    fi

    if [ ! -f "$1" ]; then
        echo "Error: '$1' is not a valid file"
        return 1
    fi

    case "$1" in
        *.tar.bz2|*.tbz2) tar tjf "$1" ;;
        *.tar.gz|*.tgz)   tar tzf "$1" ;;
        *.tar.xz)         tar tJf "$1" ;;
        *.tar.zst)        tar --zstd -tvf "$1" ;;
        *.tar)            tar tf "$1" ;;
        *.rar)            unrar l "$1" ;;
        *.zip)            unzip -l "$1" ;;
        *.7z)             7z l "$1" ;;
        *.lha|*.lzh)      lha l "$1" ;;
        *.arj)            arj l "$1" ;;
        *)                echo "Error: Cannot list contents of '$1' - unknown format" ;;
    esac
}

#-----------------------------------------------------------------------------
# Compress Function with Progress
#-----------------------------------------------------------------------------
compress() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: compress <format> <input_files...> [output_file]"
        echo "Formats: tar, tgz, tbz2, txz, tzst, zip, 7z, gz, bz2, xz, zst, lz4, rar"
        echo "Options: -l <1-9> compression level (if supported by format)"
        return 1
    fi

    local format="$1"
    shift

    # Check for compression level option
    local level=6  # Default compression level
    if [ "$1" = "-l" ]; then
        level="$2"
        shift 2
    fi

    # The last argument might be the output file if it doesn't exist as a file or directory
    local inputs=("$@")
    local num_inputs=${#inputs[@]}
    local output=""

    # If the last argument doesn't exist as a file or directory and has more than 1 argument
    if [ "$num_inputs" -gt 1 ] && [ ! -e "${inputs[$num_inputs-1]}" ]; then
        output="${inputs[$num_inputs-1]}"
        # shellcheck disable="SC2184,2086"
        unset inputs[$num_inputs-1]
    else
        # Default output name based on the first input
        case "$format" in
            tar)    output="${inputs[0]}.tar" ;;
            tgz)    output="${inputs[0]}.tar.gz" ;;
            tbz2)   output="${inputs[0]}.tar.bz2" ;;
            txz)    output="${inputs[0]}.tar.xz" ;;
            tzst)   output="${inputs[0]}.tar.zst" ;;
            zip)    output="${inputs[0]}.zip" ;;
            7z)     output="${inputs[0]}.7z" ;;
            gz)     output="${inputs[0]}.gz" ;;
            bz2)    output="${inputs[0]}.bz2" ;;
            xz)     output="${inputs[0]}.xz" ;;
            zst)    output="${inputs[0]}.zst" ;;
            lz4)    output="${inputs[0]}.lz4" ;;
            rar)    output="${inputs[0]}.rar" ;;
            *)      echo "Error: Unsupported format '$format'" && return 1 ;;
        esac
    fi

    # Check if we have pv installed for progress indication
    local has_pv=0
    if command -v pv >/dev/null 2>&1; then
        has_pv=1
    fi

    # Log file for operations
    LOG_FILE=${ARCHIVE_LOG_FILE:-"$HOME/.archive_operations.log"}

    echo "Compressing to $output..."
    case "$format" in
        tar)
            tar -cf "$output" "${inputs[@]}"
            ;;
        tgz)
            if [ $has_pv -eq 1 ] && [ ${#inputs[@]} -eq 1 ] && [ -f "${inputs[0]}" ]; then
                pv "${inputs[0]}" | tar -cz -f "$output" -C "$(dirname "${inputs[0]}")" "$(basename "${inputs[0]}")"
            else
                tar -czf "$output" "${inputs[@]}"
            fi
            ;;
        tbz2)
            tar -cjf "$output" -C "$(dirname "${inputs[0]}")" "${inputs[@]}"
            ;;
        txz)
            XZ_OPT="-$level" tar -cJf "$output" "${inputs[@]}"
            ;;
        tzst)
            ZSTD_CLEVEL="$level" tar --zstd -cf "$output" "${inputs[@]}"
            ;;
        zip)
            zip -r "$output" "${inputs[@]}" "-$level"
            ;;
        7z)
            7z a "-mx=$level" "$output" "${inputs[@]}"
            ;;
        gz)
            if [ ${#inputs[@]} -eq 1 ] && [ -f "${inputs[0]}" ]; then
                if [ $has_pv -eq 1 ]; then
                    pv "${inputs[0]}" | gzip "-$level" > "$output"
                else
                    gzip -c "-$level" "${inputs[0]}" > "$output"
                fi
            else
                echo "Error: gzip compression requires a single input file" | tee -a "$LOG_FILE"
                return 1
            fi
            ;;
        bz2)
            if [ ${#inputs[@]} -eq 1 ] && [ -f "${inputs[0]}" ]; then
                if [ $has_pv -eq 1 ]; then
                    pv "${inputs[0]}" | bzip2 "-$level" > "$output"
                else
                    bzip2 -c "-$level" "${inputs[0]}" > "$output"
                fi
            else
                echo "Error: bzip2 compression requires a single input file" | tee -a "$LOG_FILE"
                return 1
            fi
            ;;
        xz)
            if [ ${#inputs[@]} -eq 1 ] && [ -f "${inputs[0]}" ]; then
                if [ $has_pv -eq 1 ]; then
                    pv "${inputs[0]}" | xz "-$level" > "$output"
                else
                    xz -c "-$level" "${inputs[0]}" > "$output"
                fi
            else
                echo "Error: xz compression requires a single input file" | tee -a "$LOG_FILE"
                return 1
            fi
            ;;
        zst)
            if [ ${#inputs[@]} -eq 1 ] && [ -f "${inputs[0]}" ]; then
                if [ $has_pv -eq 1 ]; then
                    pv "${inputs[0]}" | zstd "-$level" > "$output"
                else
                    zstd -c "-$level" "${inputs[0]}" > "$output"
                fi
            else
                echo "Error: zstd compression requires a single input file" | tee -a "$LOG_FILE"
                return 1
            fi
            ;;
        lz4)
            if [ ${#inputs[@]} -eq 1 ] && [ -f "${inputs[0]}" ]; then
                if [ $has_pv -eq 1 ]; then
                    pv "${inputs[0]}" | lz4 "-$level" > "$output"
                else
                    lz4 -c "-$level" "${inputs[0]}" > "$output"
                fi
            else
                echo "Error: lz4 compression requires a single input file" | tee -a "$LOG_FILE"
                return 1
            fi
            ;;
        rar)
            rar a "-m$level" "$output" "${inputs[@]}"
            ;;
        *)
            echo "Error: Unsupported format '$format'" | tee -a "$LOG_FILE"
            return 1
            ;;
    esac

    # Log result
    # shellcheck disable=SC2181
    if [ $? -eq 0 ]; then
        echo "Successfully compressed to $output" | tee -a "$LOG_FILE"
    else
        echo "Failed to compress to $output" | tee -a "$LOG_FILE"
        return 1
    fi
}

#-----------------------------------------------------------------------------
# Compress Large Files Function (Preserved for backward compatibility)
#-----------------------------------------------------------------------------
compress_large() {
    if [ -z "$1" ] || [ -z "$2" ]; then
        echo "Usage: compress_large <format> <input_file> [output_file]"
        echo "Note: Consider using the more powerful 'compress' function instead"
        return 1
    fi

    local format="$1"
    local input="$2"
    local output="${3:-${input}.${format}}"

    if [ ! -f "$input" ]; then
        echo "Error: '$input' is not a valid file"
        return 1
    fi

    case "$format" in
        gz)     gzip -c "$input" > "$output" ;;
        bz2)    bzip2 -c "$input" > "$output" ;;
        xz)     xz -c "$input" > "$output" ;;
        zst)    zstd -c "$input" > "$output" ;;
        lz4)    lz4 -c "$input" > "$output" ;;
        *)      echo "Error: Unsupported format '$format'" && return 1 ;;
    esac
    echo "Compressed '$input' to '$output'"
}

#-----------------------------------------------------------------------------
# Quick Backup Function
#-----------------------------------------------------------------------------
backup() {
    local target="$1"
    local format="${2:-tgz}"  # Default to tar.gz
    # shellcheck disable=SC2155
    local timestamp=$(date +%Y%m%d-%H%M%S)

    if [ -z "$target" ]; then
        echo "Usage: backup <file_or_directory> [format]"
        echo "Available formats: tgz (default), tbz2, txz, tzst, zip, 7z"
        return 1
    fi

    if [ ! -e "$target" ]; then
        echo "Error: '$target' does not exist"
        return 1
    fi

    # shellcheck disable=SC2155
    local basename=$(basename "$target")
    local output="${basename}-backup-${timestamp}"

    case "$format" in
        tgz)  compress tgz "$target" "$output.tar.gz" ;;
        tbz2) compress tbz2 "$target" "$output.tar.bz2" ;;
        txz)  compress txz "$target" "$output.tar.xz" ;;
        tzst) compress tzst "$target" "$output.tar.zst" ;;
        zip)  compress zip "$target" "$output.zip" ;;
        7z)   compress 7z "$target" "$output.7z" ;;
        *)    echo "Error: Unsupported backup format '$format'" && return 1 ;;
    esac

    # shellcheck disable=SC2181
    if [ $? -eq 0 ]; then
        echo "Backup created: $output"
    fi
}

#-----------------------------------------------------------------------------
# Aliases
#-----------------------------------------------------------------------------
# Extract Aliases
alias x='extract'                    # Extract any supported archive

# List Content Aliases
alias l7z='7z l'                     # List 7z archive contents
alias ltar='tar -tvf'                # List tar archive contents
alias ltgz='tar -tzvf'               # List tar.gz archive contents
alias ltbz='tar -tjvf'               # List tar.bz2 archive contents
alias ltxz='tar -tJvf'               # List tar.xz archive contents
alias ltzst='tar --zstd -tvf'        # List tar.zst archive contents
alias lzip='unzip -l'                # List zip archive contents
alias lrar='unrar l'                 # List rar archive contents
alias lar='list_archive'             # Generic list archive contents

# 7-Zip Aliases
alias c7z='7z a'                     # Create 7z archive
alias x7z='7z x'                     # Extract 7z archive

# Tar Aliases
alias ctar='tar -cvf'                # Create tar archive
alias xtar='tar -xvf'                # Extract tar archive
alias ctgz='tar -zcvf'               # Create tar.gz archive
alias xtgz='tar -zxvf'               # Extract tar.gz archive
alias ctbz='tar -jcvf'               # Create tar.bz2 archive
alias xtbz='tar -jxvf'               # Extract tar.bz2 archive
alias ctxz='tar -Jcvf'               # Create tar.xz archive
alias xtxz='tar -Jxvf'               # Extract tar.xz archive
alias ctzst='tar --zstd -cvf'        # Create tar.zst archive
alias xtzst='tar --zstd -xvf'        # Extract tar.zst archive

# Zip Aliases
alias czip='zip -r'                  # Create zip archive
alias xzip='unzip'                   # Extract zip archive

# RAR Aliases
alias crar='rar a'                   # Create rar archive
alias xrar='unrar x'                 # Extract rar archive

# Gzip Aliases
alias cgz='gzip -cv'                 # Compress with gzip
alias xgz='gzip -dv'                 # Extract gzip

# Bzip2 Aliases
alias cbz='bzip2 -zk'                # Compress with bzip2
alias xbz='bzip2 -dk'                # Extract bzip2

# XZ Aliases
alias cxz='xz -z'                    # Compress with xz
alias xxz='xz -d'                    # Extract xz

# Zstd Aliases
alias czst='zstd -z'                 # Compress with zstd
alias xzst='zstd -d'                 # Extract zstd

# LZ4 Aliases
alias clz4='lz4 -zc'                 # Compress with lz4
alias xlz4='lz4 -dc'                 # Extract lz4

# Combined Aliases
alias ac='compress'                  # Generic compression (Archive Create)
alias acl='compress_large'           # Legacy compress_large
alias bak='backup'                   # Quick backup function
# shellcheck shell=bash
# 🅽🅿🅼 🅰🅻🅸🅰🆂🅴🆂
if command -v npm &>/dev/null; then
  # Audit npm packages.
  alias npa='npm audit'

  # Build npm script.
  alias npb='npm build'

  # Cache npm package.
  alias npc='npm cache'

  # Dev npm script.
  alias npd='npm dev'

  # Global npm package.
  alias npg='npm global'

  # Install npm package.
  alias npi='npm install'

  # List npm packages.
  alias npl='npm list'

  # Publish npm package.
  alias npp='npm publish'

  # Remove npm package.
  alias nprm='npm uninstall'

  # Run npm script.
  alias npr='npm run'

  # Run npm script watch.
  alias nprw='npm run watch'

  # Start npm script.
  alias nps='npm start'

  # Serve npm script.
  alias npsv='npm serve'

  # Test npm script.
  alias npt='npm test'

  # Update npm package.
  alias npu='npm update'

  # Exec npm package.
  alias npx='npm exec'

  # Why npm package.
  alias npy='npm why'

fi
# shellcheck shell=bash
# 🅼🅰🅺🅴🅳🅸🆁 🅰🅻🅸🅰🆂🅴🆂

# Make example directory with current date.
alias mde='mkdir -pv "$(date +%Y%m%d)-example"'

# Make directory.
alias md='mkdir -v'

# Make directory with date.
alias mdd='mkdir -pv $(date +%Y%m%d) && cd $(date +%Y%m%d)'

# Make notes directory with current date.
alias mdn='mkdir -pv "$(date +%Y%m%d)-notes"'

# Make work directory with current date.
alias mdw='mkdir -pv "$(date +%Y%m%d)-work"'

# Make directory with time.
alias mdt='mkdir -pv $(date +%H%M%S)'
# shellcheck shell=bash
# Yarn Aliases

if command -v yarn &>/dev/null; then
  alias y='yarn'
  alias ya='yarn add'
  alias yad='yarn add --dev'
  alias yga='yarn global add'
  alias yi='yarn install'
  alias yin='yarn init'
  alias yls='yarn list'
  alias yout='yarn outdated'
  alias yp='yarn pack'
  alias yrm='yarn remove'
  alias yrun='yarn run'
  alias ys='yarn serve'
  alias yst='yarn start'
  alias yt='yarn test'
  alias ytc='yarn test --coverage'
  alias yuc='yarn global upgrade && yarn cache clean'
  alias yui='yarn upgrade-interactive'
  alias yup='yarn upgrade'
  alias yv='yarn version'
  alias yw='yarn workspace'
  alias yws='yarn workspaces'
fi
#!/usr/bin/env bash
# Legal & Licensing Aliases
# Tools for license compliance, headers, and attribution.

# -----------------------------------------------------------------------------
# FOSSology & License Scanning
# -----------------------------------------------------------------------------

# Start a local FOSSology instance for deep scan
if command -v docker &>/dev/null; then
  alias fossology-start='docker run -d -p 8081:80 --name fossology fossology/fossology && echo "FOSSology started at http://localhost:8081"'
  alias fossology-stop='docker stop fossology && docker rm fossology'
fi

# Lightweight license check (using trivy as a modern proxy for compliance scanning)
if command -v trivy &>/dev/null; then
  alias scan-licenses='trivy fs . --scanners license'
else
  alias scan-licenses='echo "trivy not found. Installing via homebrew..." && brew install trivy && trivy fs . --scanners license'
fi

# -----------------------------------------------------------------------------
# Copyright Headers (add-headers)
# -----------------------------------------------------------------------------

# Using google/addlicense (Go) via Docker to avoid local deps
# Usage: add-headers
add_headers_fn() {
  local holder="${GIT_AUTHOR_NAME:-Sebastien Rousseau}"
  echo "Adding MIT license headers for: $holder"
  docker run --rm -v "$(pwd):/src" -w /src ghcr.io/google/addlicense \
    -c "$holder" \
    -l mit \
    -v \
    .
}
alias add-headers=add_headers_fn

# -----------------------------------------------------------------------------
# NOTICE generation (`gen-notice`)
# -----------------------------------------------------------------------------

# Generate attribution report for Go projects (expandable to others)
gen_notice_fn() {
    echo "Generating NOTICE file for dependencies..."
    if [ -f "go.mod" ]; then
        docker run --rm -v "$(pwd):/src" -w /src golang:latest \
            sh -c "go install github.com/google/go-licenses@latest && go-licenses report . --template /src/NOTICE.tpl > NOTICE"
    else
        echo "⚠️  No supported package manager found for automatic NOTICE generation."
    fi
}
alias gen-notice=gen_notice_fn

# -----------------------------------------------------------------------------
# CLA Checking
# -----------------------------------------------------------------------------

# Check CLA status for the current branch's PR
check_cla_fn() {
  if command -v gh &>/dev/null; then
    echo "Checking PR checks for CLA status..."
    gh pr checks --watch
  else
    echo "❌ GitHub CLI (gh) not found."
  fi
}
alias check-cla=check_cla_fn
# shellcheck shell=bash
################################################################################


# Ensure chmod exists before proceeding
if command -v chmod >/dev/null; then

  #-----------------------------------------------------------------------------
  # Function: Validate input
  # Description: Checks permission format and path validity.
  #-----------------------------------------------------------------------------
  validate_input() {
    local permission="$1"
    local path="$2"

    # Check permission format (supports both 3-digit and 4-digit octal)
    if ! [[ ${permission} =~ ^[0-7]{3,4}$ ]]; then
      echo "Error: Invalid permission format '${permission}'. Expected format: ### or #### (e.g., 644 or 2755)."
      return 1
    fi

    # Check if the path exists
    if ! [[ -e "${path}" ]]; then
      echo "Error: Path does not exist: '${path}'."
      return 1
    fi

    return 0
  }

  #-----------------------------------------------------------------------------
  # Function: Create backup
  # Description: Creates a backup of the target file/directory before modification.
  #-----------------------------------------------------------------------------
  create_backup() {
    local path="$1"
    local backup_path
    backup_path="${path}.bak.$(date +%Y%m%d%H%M%S)"

    # Only backup files, not directories
    if [[ -f "${path}" ]]; then
      cp -p "${path}" "${backup_path}" 2>/dev/null && \
        echo "Backup created at '${backup_path}'"
    fi
  }

  #-----------------------------------------------------------------------------
  # Function: Change permissions
  # Description: Applies chmod with validation and optional recursive handling.
  #-----------------------------------------------------------------------------
  change_permission() {
    local permission="$1"
    local path="$2"
    local recursive="${3:-}"
    local backup="${4:-false}"

    # Validate input
    if ! validate_input "${permission}" "${path}"; then
      return 1
    fi

    # Create backup if requested
    if [[ "${backup}" == "true" ]]; then
      create_backup "${path}"
    fi

    # Handle recursive changes with confirmation
    if [[ "${recursive}" == "-R" ]]; then
      local count
      count=$(find "${path}" 2>/dev/null | wc -l)
      read -rp "Confirm recursive change to '${permission}' for '${path}' (${count} items)? (y/N): " confirm
      if [[ ${confirm} != [yY] ]]; then
        echo "Operation cancelled."
        return 1
      fi
    fi

    # Apply permissions
    chmod "${recursive}" "${permission}" "${path}" && \
      echo "Permissions set to '${permission}' on '${path}'"
  }

  #-----------------------------------------------------------------------------
  # Function: Symbolic permission change with validation
  # Description: Wrapper for symbolic chmod with path validation.
  #-----------------------------------------------------------------------------
  symbolic_permission() {
    local permission="$1"
    local path="$2"
    local recursive="${3:-}"
    local backup="${4:-false}"

    # Check if the path exists
    if ! [[ -e "${path}" ]]; then
      echo "Error: Path does not exist: '${path}'."
      return 1
    fi

    # Create backup if requested
    if [[ "${backup}" == "true" ]]; then
      create_backup "${path}"
    fi

    # Handle recursive changes with confirmation
    if [[ "${recursive}" == "-R" ]]; then
      local count
      count=$(find "${path}" 2>/dev/null | wc -l)
      read -rp "Confirm recursive symbolic change '${permission}' for '${path}' (${count} items)? (y/N): " confirm
      if [[ ${confirm} != [yY] ]]; then
        echo "Operation cancelled."
        return 1
      fi
    fi

    # Apply permissions
    chmod "${recursive}" "${permission}" "${path}" && \
      echo "Applied '${permission}' on '${path}'"
  }

  #-----------------------------------------------------------------------------
  # Common Permission Aliases - Numeric Format
  #-----------------------------------------------------------------------------
  # No permissions
  alias chmod_000='change_permission 000'

  # Read-only permissions
  alias chmod_400='change_permission 400'  # Read-only for owner
  alias chmod_444='change_permission 444'  # Read-only for all

  # Read/write permissions
  alias chmod_600='change_permission 600'  # Read/write for owner
  alias chmod_644='change_permission 644'  # Read/write for owner, read for others
  alias chmod_664='change_permission 664'  # Read/write for owner and group, read for others
  alias chmod_666='change_permission 666'  # Read/write for all

  # Execute permissions
  alias chmod_700='change_permission 700'  # Full for owner only
  alias chmod_744='change_permission 744'  # Full for owner, read for others
  alias chmod_755='change_permission 755'  # Full for owner, read/execute for others
  alias chmod_764='change_permission 764'  # Full for owner, read/write for group, read for others
  alias chmod_775='change_permission 775'  # Full for owner and group, read/execute for others
  alias chmod_777='change_permission 777'  # Full permissions for all

  # Special permission bits
  alias chmod_1755='change_permission 1755'  # Sticky bit + 755
  alias chmod_2755='change_permission 2755'  # Setgid + 755
  alias chmod_4755='change_permission 4755'  # Setuid + 755

  #-----------------------------------------------------------------------------
  # Recursive Permission Functions
  #-----------------------------------------------------------------------------
  chmod_r_644() {
    change_permission 644 "$1" -R
  }  # Recursive 644

  chmod_r_755() {
    change_permission 755 "$1" -R
  }  # Recursive 755

  chmod_r_775() {
    change_permission 775 "$1" -R
  }  # Recursive 775

  #-----------------------------------------------------------------------------
  # Backup + Change Permission Functions
  #-----------------------------------------------------------------------------
  chmod_b_644() {
    change_permission 644 "$1" "" true
  }  # 644 with backup

  chmod_b_755() {
    change_permission 755 "$1" "" true
  }  # 755 with backup

  chmod_rb_644() {
    change_permission 644 "$1" -R true
  }  # Recursive 644 with backup

  chmod_rb_755() {
    change_permission 755 "$1" -R true
  }  # Recursive 755 with backup

  #-----------------------------------------------------------------------------
  # User, Group, and Other Symbolic Permission Functions
  #-----------------------------------------------------------------------------
  # User permissions
  chmod_u+x() { symbolic_permission u+x "$1"; }  # Add execute for owner
  chmod_u-x() { symbolic_permission u-x "$1"; }  # Remove execute for owner
  chmod_u+w() { symbolic_permission u+w "$1"; }  # Add write for owner
  chmod_u-w() { symbolic_permission u-w "$1"; }  # Remove write for owner
  chmod_u+r() { symbolic_permission u+r "$1"; }  # Add read for owner
  chmod_u-r() { symbolic_permission u-r "$1"; }  # Remove read for owner

  # Group permissions
  chmod_g+x() { symbolic_permission g+x "$1"; }  # Add execute for group
  chmod_g-x() { symbolic_permission g-x "$1"; }  # Remove execute for group
  chmod_g+w() { symbolic_permission g+w "$1"; }  # Add write for group
  chmod_g-w() { symbolic_permission g-w "$1"; }  # Remove write for group
  chmod_g+r() { symbolic_permission g+r "$1"; }  # Add read for group
  chmod_g-r() { symbolic_permission g-r "$1"; }  # Remove read for group

  # Others permissions
  chmod_o+x() { symbolic_permission o+x "$1"; }  # Add execute for others
  chmod_o-x() { symbolic_permission o-x "$1"; }  # Remove execute for others
  chmod_o+w() { symbolic_permission o+w "$1"; }  # Add write for others
  chmod_o-w() { symbolic_permission o-w "$1"; }  # Remove write for others
  chmod_o+r() { symbolic_permission o+r "$1"; }  # Add read for others
  chmod_o-r() { symbolic_permission o-r "$1"; }  # Remove read for others

  # Combined permissions
  chmod_a+x() { symbolic_permission a+x "$1"; }  # Add execute for all
  chmod_a-x() { symbolic_permission a-x "$1"; }  # Remove execute for all
  chmod_a+w() { symbolic_permission a+w "$1"; }  # Add write for all
  chmod_a-w() { symbolic_permission a-w "$1"; }  # Remove write for all
  chmod_a+r() { symbolic_permission a+r "$1"; }  # Add read for all
  chmod_a-r() { symbolic_permission a-r "$1"; }  # Remove read for all

  # Recursive symbolic permissions
  chmod_ru+x() { symbolic_permission u+x "$1" -R; }  # Recursive add execute for owner
  chmod_rg+x() { symbolic_permission g+x "$1" -R; }  # Recursive add execute for group
  chmod_ro+x() { symbolic_permission o+x "$1" -R; }  # Recursive add execute for others
  chmod_ra+x() { symbolic_permission a+x "$1" -R; }  # Recursive add execute for all

  #-----------------------------------------------------------------------------
  # Helper functions and aliases
  #-----------------------------------------------------------------------------
  # Show permissions in octal format for a file/directory
  # Minimalist version using built-in shell features only
  show_permissions() {
    local path="$1"
    if [[ -e "${path}" ]]; then
      echo "Permissions for: ${path}"

      # Check basic permissions using test operators
      echo "Read:    $(if [[ -r "${path}" ]]; then echo "Yes"; else echo "No"; fi)"
      echo "Write:   $(if [[ -w "${path}" ]]; then echo "Yes"; else echo "No"; fi)"
      echo "Execute: $(if [[ -x "${path}" ]]; then echo "Yes"; else echo "No"; fi)"

      # Check file type
      if [[ -f "${path}" ]]; then
        echo "Type: Regular file"
      elif [[ -d "${path}" ]]; then
        echo "Type: Directory"
      elif [[ -L "${path}" ]]; then
        echo "Type: Symbolic link"
      elif [[ -b "${path}" ]]; then
        echo "Type: Block device"
      elif [[ -c "${path}" ]]; then
        echo "Type: Character device"
      elif [[ -p "${path}" ]]; then
        echo "Type: Named pipe"
      elif [[ -S "${path}" ]]; then
        echo "Type: Socket"
      else
        echo "Type: Unknown"
      fi
    else
      echo "Error: Path does not exist: '${path}'."
      return 1
    fi
  }

  alias permissions='show_permissions'

fi

# Usage information
chmod_help() {
  cat << EOF
CHMOD ALIASES USAGE:

  Numeric Permission Aliases:
    chmod_000, chmod_400, chmod_444, chmod_600, chmod_644, chmod_664, chmod_666,
    chmod_700, chmod_744, chmod_755, chmod_764, chmod_775, chmod_777,
    chmod_1755, chmod_2755, chmod_4755

  Recursive Permission Functions:
    chmod_r_644, chmod_r_755, chmod_r_775

  Backup + Change Permission Functions:
    chmod_b_644, chmod_b_755, chmod_rb_644, chmod_rb_755

  Symbolic Permission Functions:
    User:   chmod_u+x, chmod_u-x, chmod_u+w, chmod_u-w, chmod_u+r, chmod_u-r
    Group:  chmod_g+x, chmod_g-x, chmod_g+w, chmod_g-w, chmod_g+r, chmod_g-r
    Others: chmod_o+x, chmod_o-x, chmod_o+w, chmod_o-w, chmod_o+r, chmod_o-r
    All:    chmod_a+x, chmod_a-x, chmod_a+w, chmod_a-w, chmod_a+r, chmod_a-r

  Recursive Symbolic Permissions:
    chmod_ru+x, chmod_rg+x, chmod_ro+x, chmod_ra+x

  Helper Functions:
    permissions <path>   - Show permissions in octal format for a file/directory
    chmod_help           - Display this help message
EOF
}
#!/usr/bin/env bash
# Diagnostics & Self-Healing Aliases

# Health Check
alias doc='bash $HOME/.local/share/chezmoi/scripts/doctor.sh'
alias dot-doctor='doc'

# Drift Detection
alias drift='chezmoi verify'
alias dot-drift='drift'

# Auto-Repair (Sync)
alias heal='chezmoi apply --verbose'
alias dot-heal='heal'

# Detailed Doctor (with debug info)
alias doc-full='bash $HOME/.local/share/chezmoi/scripts/doctor.sh && echo "\n--- Path Info ---" && echo $PATH | tr ":" "\n"'
# shellcheck shell=bash
# 🅿🆂 🅰🅻🅸🅰🆂🅴🆂
if command -v 'ps' >/dev/null; then

  # Display the uid, pid, parent pid, recent CPU usage, process start
  # time, controlling tty, elapsed CPU usage, and the associated command
  alias pid='ps -f'

  # Display all processes.
  alias ps='ps -ef'

  # List all processes.
  alias psa='ps aux'
fi
#!/usr/bin/env bash
# Immutability Aliases
# Wrappers for the lock-configs script.

script_path="${HOME}/.local/share/chezmoi/scripts/lock-configs.sh"

if [[ -f "$script_path" ]]; then
    alias lock-configs="bash $script_path lock"
    alias unlock-configs="bash $script_path unlock"
    alias check-locks="bash $script_path check" # Script needs to handle check or default triggers it
fi
# shellcheck shell=bash
###############################################################################
# 🅾🅿🅴🅽🆂🆂🅻 (openssl) Aliases & Functions
###############################################################################
if command -v openssl >/dev/null 2>&1; then
    # Basic Aliases
    alias ssl='openssl'                # OpenSSL shortcut
    alias sslv='openssl version'       # Show OpenSSL version
    alias sslhelp='openssl help'       # Show OpenSSL help

    #-----------------------------------------------------------------------------
    # Certificate Operations
    #-----------------------------------------------------------------------------
    alias sslx509='openssl x509'       # X.509 certificate utility

    function sslx509info() {
        [[ -z "$1" ]] && {
            echo "Usage: sslx509info <certificate_file>"
            return 1
        }
        openssl x509 -in "$1" -text -noout
    }

    function sslx509fp() {
        [[ -z "$1" ]] && {
            echo "Usage: sslx509fp <certificate_file>"
            return 1
        }
        openssl x509 -in "$1" -fingerprint -noout
    }

    function sslx509dates() {
        [[ -z "$1" ]] && {
            echo "Usage: sslx509dates <certificate_file>"
            return 1
        }
        openssl x509 -in "$1" -dates -noout
    }

    function sslx509subject() {
        [[ -z "$1" ]] && {
            echo "Usage: sslx509subject <certificate_file>"
            return 1
        }
        openssl x509 -in "$1" -subject -noout
    }

    function sslx509issuer() {
        [[ -z "$1" ]] && {
            echo "Usage: sslx509issuer <certificate_file>"
            return 1
        }
        openssl x509 -in "$1" -issuer -noout
    }

    function sslx509check() {
        [[ -z "$1" ]] && {
            echo "Usage: sslx509check <certificate_file>"
            return 1
        }
        openssl x509 -purpose -in "$1" -noout
    }

    function sslx509extract() {
        [[ -z "$1" || -z "$2" || -z "$3" ]] && {
            echo "Usage: sslx509extract <in_cert> <out_format> <out_file>"
            echo "Example: sslx509extract cert.pem DER cert.der"
            return 1
        }
        openssl x509 -in "$1" -outform "$2" -out "$3"
    }

    #-----------------------------------------------------------------------------
    # CSR (Certificate Signing Request) Operations
    #-----------------------------------------------------------------------------
    alias sslreq='openssl req'

    function sslreqnew() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: sslreqnew <key_out> <csr_out>"
            return 1
        }
        openssl req -new -nodes -keyout "$1" -out "$2"
    }

    function sslreqinfo() {
        [[ -z "$1" ]] && {
            echo "Usage: sslreqinfo <csr_file>"
            return 1
        }
        openssl req -in "$1" -text -noout
    }

    function sslreqverify() {
        [[ -z "$1" ]] && {
            echo "Usage: sslreqverify <csr_file>"
            return 1
        }
        openssl req -verify -in "$1"
    }

    #-----------------------------------------------------------------------------
    # Key Operations
    #-----------------------------------------------------------------------------
    function sslgenrsa() {
        [[ -z "$1" ]] && {
            echo "Usage: sslgenrsa <key_file> [size]"
            echo "Default size: 2048"
            return 1
        }
        openssl genrsa -out "$1" "${2:-2048}"
    }

    function sslgenpkey() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: sslgenpkey <algorithm> <key_out>"
            echo "Example: sslgenpkey RSA mykey.pem"
            return 1
        }
        openssl genpkey -algorithm "$1" -out "$2"
    }

    function sslecparam() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: sslecparam <curve_name> <out_key>"
            echo "Example: sslecparam prime256v1 eckey.pem"
            return 1
        }
        openssl ecparam -name "$1" -genkey -out "$2"
    }

    function sslrsa() {
        [[ -z "$1" ]] && {
            echo "Usage: sslrsa <rsa_private_key_file>"
            return 1
        }
        openssl rsa -in "$1" -check
    }

    function sslrsainfo() {
        [[ -z "$1" ]] && {
            echo "Usage: sslrsainfo <rsa_private_key_file>"
            return 1
        }
        openssl rsa -in "$1" -text -noout
    }

    function sslrsapub() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: sslrsapub <rsa_private_key_file> <pub_key_out>"
            return 1
        }
        openssl rsa -in "$1" -pubout -out "$2"
    }

    function sslpkey() {
        [[ -z "$1" ]] && {
            echo "Usage: sslpkey <key_file> [additional_params]"
            return 1
        }
        openssl pkey -in "$1" "${@:2}"
    }

    #-----------------------------------------------------------------------------
    # Conversion Operations
    #-----------------------------------------------------------------------------
    function sslpkcs12() {
        [[ -z "$1" || -z "$2" || -z "$3" ]] && {
            echo "Usage: sslpkcs12 <cert_in> <key_in> <p12_out>"
            return 1
        }
        openssl pkcs12 -export -in "$1" -inkey "$2" -out "$3"
    }

    function sslpkcs12extract() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: sslpkcs12extract <p12_file> <out_file>"
            return 1
        }
        openssl pkcs12 -in "$1" -nodes -out "$2"
    }

    function sslpkcs8() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: sslpkcs8 <key_in> <key_out>"
            return 1
        }
        openssl pkcs8 -in "$1" -topk8 -out "$2"
    }

    #-----------------------------------------------------------------------------
    # Connection Testing
    #-----------------------------------------------------------------------------
    function sslconnect() {
        [[ -z "$1" ]] && {
            echo "Usage: sslconnect <host> [port]"
            return 1
        }
        openssl s_client -connect "$1:${2:-443}"
    }

    function sslconnectsni() {
        [[ -z "$1" ]] && {
            echo "Usage: sslconnectsni <host> [port]"
            return 1
        }
        openssl s_client -connect "$1:${2:-443}" -servername "$1"
    }

    function sslciphers() {
        [[ -z "$1" || -z "$3" ]] && {
            echo "Usage: sslciphers <host> <port> <cipher_list>"
            return 1
        }
        openssl s_client -connect "$1:${2:-443}" -cipher "$3"
    }

    function sslshowcerts() {
        [[ -z "$1" ]] && {
            echo "Usage: sslshowcerts <host> [port]"
            return 1
        }
        openssl s_client -connect "$1:${2:-443}" -showcerts
    }

    function sslprotocol() {
        [[ -z "$1" || -z "$3" ]] && {
            echo "Usage: sslprotocol <host> <port> <protocol>"
            echo "Example: sslprotocol example.com 443 tls1_2"
            return 1
        }
        openssl s_client -connect "$1:${2:-443}" -"$3"
    }

    #-----------------------------------------------------------------------------
    # Certificate Verification
    #-----------------------------------------------------------------------------
    function sslverify() {
        [[ -z "$1" ]] && {
            echo "Usage: sslverify <certificate_file> [more_files]"
            return 1
        }
        openssl verify "$@"
    }

    function sslverifycapath() {
        [[ -z "$1" ]] && {
            echo "Usage: sslverifycapath <certificate_file> [more_files]"
            return 1
        }
        openssl verify -CApath /etc/ssl/certs/ "$@"
    }

    function sslcrl() {
        [[ -z "$1" ]] && {
            echo "Usage: sslcrl <crl_file>"
            return 1
        }
        openssl crl -in "$1" -text -noout
    }

    #-----------------------------------------------------------------------------
    # Hash and Digest Functions
    #-----------------------------------------------------------------------------
    function ssldigest() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: ssldigest <algorithm> <file>"
            echo "Example: ssldigest sha256 file.txt"
            return 1
        }
        openssl dgst -"$1" "$2"
    }

    alias sslsha1='openssl dgst -sha1'
    alias sslsha256='openssl dgst -sha256'
    alias sslsha384='openssl dgst -sha384'
    alias sslsha512='openssl dgst -sha512'
    alias sslmd5='openssl dgst -md5'  # Not recommended for security

    #-----------------------------------------------------------------------------
    # Random Generation
    #-----------------------------------------------------------------------------
    # Default to hex output for readability
    function sslrand() {
        [[ -z "$1" ]] && {
            echo "Usage: sslrand <size>"
            return 1
        }
        openssl rand -hex "$1"
    }

    function sslrandraw() {
        [[ -z "$1" ]] && {
            echo "Usage: sslrandraw <size>"
            return 1
        }
        openssl rand "$1"
    }

    function sslrandhex() {
        [[ -z "$1" ]] && {
            echo "Usage: sslrandhex <size>"
            return 1
        }
        openssl rand -hex "$1"
    }

    function sslrandbase64() {
        [[ -z "$1" ]] && {
            echo "Usage: sslrandbase64 <size>"
            return 1
        }
        openssl rand -base64 "$1"
    }

    #-----------------------------------------------------------------------------
    # Encryption and Decryption
    #-----------------------------------------------------------------------------
    function sslenc() {
        if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
            echo "Usage: sslenc <cipher> <in_file> <out_file> [additional_params]"
            echo "Example: sslenc aes-256-cbc secret.txt secret.enc -pbkdf2 -iter 10000"
            return 1
        fi
        openssl enc -"$1" -e -in "$2" -out "$3" "${@:4}"
    }

    function ssldec() {
        if [[ -z "$1" || -z "$2" || -z "$3" ]]; then
            echo "Usage: ssldec <cipher> <in_file> <out_file> [additional_params]"
            echo "Example: ssldec aes-256-cbc secret.enc secret.dec -pbkdf2 -iter 10000"
            return 1
        fi
        openssl enc -"$1" -d -in "$2" -out "$3" "${@:4}"
    }

    function sslaesenc() {
        if [[ -z "$1" || -z "$2" ]]; then
            echo "Usage: sslaesenc <in_file> <out_file>"
            return 1
        fi
        openssl enc -aes-256-cbc -salt -in "$1" -out "$2" -iter 10000 -pbkdf2
    }

    function sslaesdec() {
        if [[ -z "$1" || -z "$2" ]]; then
            echo "Usage: sslaesdec <in_file> <out_file>"
            return 1
        fi
        openssl enc -aes-256-cbc -d -in "$1" -out "$2" -iter 10000 -pbkdf2
    }

    #-----------------------------------------------------------------------------
    # CA Operations
    #-----------------------------------------------------------------------------
    function sslca() {
        # Typically requires a CA config file. Adjust as needed.
        openssl ca "$@"
    }

    #-----------------------------------------------------------------------------
    # Speed Testing
    #-----------------------------------------------------------------------------
    alias sslspeed='openssl speed'

    #-----------------------------------------------------------------------------
    # Server Testing and Setup
    #-----------------------------------------------------------------------------
    function sslserver() {
        if [[ -z "$1" || -z "$2" ]]; then
            echo "Usage: sslserver <cert_file> <key_file> [port]"
            echo "Default port: 4433"
            return 1
        fi
        openssl s_server -cert "$1" -key "$2" -port "${3:-4433}"
    }
fi

###############################################################################
# 🅶🅿🅶 (GnuPG) Aliases & Functions
###############################################################################
if command -v gpg >/dev/null 2>&1; then
    # Key Management
    alias gpgk='gpg --list-keys'
    alias gpgka='gpg --list-keys --with-colons'
    alias gpgks='gpg --list-secret-keys'
    alias gpgksa='gpg --list-secret-keys --with-colons'
    alias gpggen='gpg --full-generate-key'
    alias gpgexport='gpg --export --armor'
    alias gpgexports='gpg --export-secret-keys --armor'
    alias gpgimp='gpg --import'
    alias gpgdel='gpg --delete-key'
    alias gpgdels='gpg --delete-secret-key'
    alias gpgrenew='gpg --edit-key'

    # Encryption & Decryption
    function gpgencrypt() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: gpgencrypt <recipient> <file>"
            return 1
        }
        gpg --encrypt --recipient "$1" "$2"
    }

    function gpgesign() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: gpgesign <recipient> <file>"
            return 1
        }
        gpg --encrypt --sign --recipient "$1" "$2"
    }

    alias gpgsym='gpg --symmetric'
    alias gpgdec='gpg --decrypt'
    alias gpgdecfiles='gpg --decrypt-files'

    # Signing & Verification
    alias gpgsign='gpg --sign'
    alias gpgclear='gpg --clearsign'
    alias gpgdetach='gpg --detach-sign'
    alias gpgdetacha='gpg --detach-sign --armor'
    alias gpgverify='gpg --verify'
    alias gpgverifyf='gpg --verify-files'

    # Key Server Operations
    alias gpgsearch='gpg --search-keys'
    alias gpgserver='gpg --keyserver hkps://keys.openpgp.org'
    function gpgkrecv() {
        [[ -z "$1" ]] && {
            echo "Usage: gpgkrecv <key_id>"
            return 1
        }
        gpg --keyserver hkps://keys.openpgp.org --recv-keys "$1"
    }
    function gpgksend() {
        [[ -z "$1" ]] && {
            echo "Usage: gpgksend <key_id>"
            return 1
        }
        gpg --keyserver hkps://keys.openpgp.org --send-keys "$1"
    }
    alias gpgkrefresh='gpg --keyserver hkps://keys.openpgp.org --refresh-keys'

    # Fingerprints & Trust
    alias gpgfp='gpg --fingerprint'
    alias gpgcheck='gpg --check-signatures'
    alias gpgsig='gpg --list-signatures'
    function gpgtrust() {
        [[ -z "$1" ]] && {
            echo "Usage: gpgtrust <key_id>"
            return 1
        }
        gpg --edit-key "$1" trust quit
    }

    # Miscellaneous
    alias gpgconf='gpg --list-config'
    alias gpgver='gpg --version'
    alias gpgminexp='gpg --export-options export-minimal --export'

    function gpgclean() {
        # Deletes expired keys from keyring
        # NOTE: Ensure your grep/awk usage aligns with your local gpg output format
        local EXPIRED
        EXPIRED="$(gpg --list-keys 2>/dev/null | grep expired | awk '{print $2}')"
        [[ -z "$EXPIRED" ]] && {
            echo "No expired keys found."
            return 0
        }
        sudo gpg --batch --yes --delete-keys "$EXPIRED"
    }
fi

###############################################################################
# 🆂🆂🅷 (Secure Shell) Aliases & Functions
###############################################################################
if command -v ssh >/dev/null 2>&1; then
    # Key Management
    function sshkeyed25519() {
        [[ -z "$1" ]] && {
            echo "Usage: sshkeyed25519 <comment/email>"
            return 1
        }
        ssh-keygen -t ed25519 -C "$1"
    }

    function sshkeyrsa() {
        [[ -z "$1" ]] && {
            echo "Usage: sshkeyrsa <comment/email>"
            return 1
        }
        ssh-keygen -t rsa -b 4096 -C "$1"
    }

    alias sshkeylist='ls -la ~/.ssh'
    alias sshkeycp='ssh-copy-id'
    alias sshagent='eval "$(ssh-agent -s)" && ssh-add'
    alias sshagentls='ssh-add -l'
    alias sshagentdel='ssh-add -d'
    alias sshagentdelall='ssh-add -D'

    # Configuration & Connections
    alias sshedit='${EDITOR:-vi} ~/.ssh/config'
    alias sshconfig='cat ~/.ssh/config'
    alias sshls='grep "^Host " ~/.ssh/config | sed "s/Host //"'
    alias sshcheck='ssh -T git@github.com'
    alias sshv='ssh -v'
    alias sshvv='ssh -vv'
    alias sshvvv='ssh -vvv'

    # Tunnels & Forwarding
    function sshtunl() {
        [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]] && {
            echo "Usage: sshtunl <local_port:host:remote_port> <ssh_host>"
            echo "Example: sshtunl 8080:127.0.0.1:80 user@server"
            return 1
        }
        ssh -L "$1:$2:$3" "$4"
    }

    function sshtunr() {
        [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]] && {
            echo "Usage: sshtunr <remote_port:host:local_port> <ssh_host>"
            echo "Example: sshtunr 8080:127.0.0.1:80 user@server"
            return 1
        }
        ssh -R "$1:$2:$3" "$4"
    }

    function sshtund() {
        [[ -z "$1" ]] && {
            echo "Usage: sshtund <ssh_host>"
            return 1
        }
        ssh -D 8080 "$1"
    }

    function sshtunnel() {
        [[ -z "$1" || -z "$2" || -z "$3" ]] && {
            echo "Usage: sshtunnel <local_port> <remote_port> <ssh_host>"
            echo "Example: sshtunnel 8000 8080 user@server"
            return 1
        }
        ssh -N -L "$1:localhost:$2" "$3"
    }

    # Security Checks
    function sshfp() {
        [[ -z "$1" ]] && {
            echo "Usage: sshfp <key_file>"
            return 1
        }
        ssh-keygen -l -f "$1"
    }

    function sshfpsha256() {
        [[ -z "$1" ]] && {
            echo "Usage: sshfpsha256 <key_file>"
            return 1
        }
        ssh-keygen -l -E sha256 -f "$1"
    }

    alias sshkeyaudit='ssh-audit'  # 3rd-party tool
    alias sshscan='nmap -p 22 --script ssh-auth-methods'
fi

###############################################################################
# 🆄🅵🆆 (Uncomplicated Firewall) Aliases & Functions
###############################################################################
if command -v ufw >/dev/null 2>&1; then
    # Basic Commands
    alias fws='sudo ufw status'
    alias fwsv='sudo ufw status verbose'
    alias fwsn='sudo ufw status numbered'
    alias fwe='sudo ufw enable'
    alias fwdis='sudo ufw disable'
    alias fwds='sudo ufw default deny incoming'
    alias fwda='sudo ufw default allow outgoing'

    # Rule Management
    function fwallow() {
        [[ -z "$1" ]] && {
            echo "Usage: fwallow <service_or_port>"
            return 1
        }
        sudo ufw allow "$1"
    }

    function fwallowproto() {
        [[ -z "$1" || -z "$2" || -z "$3" ]] && {
            echo "Usage: fwallowproto <protocol> <from_IP> <to_IP>"
            return 1
        }
        sudo ufw allow proto "$1" from "$2" to "$3"
    }

    function fwdeny() {
        [[ -z "$1" ]] && {
            echo "Usage: fwdeny <service_or_port>"
            return 1
        }
        sudo ufw deny "$1"
    }

    function fwdenyproto() {
        [[ -z "$1" || -z "$2" || -z "$3" ]] && {
            echo "Usage: fwdenyproto <protocol> <from_IP> <to_IP>"
            return 1
        }
        sudo ufw deny proto "$1" from "$2" to "$3"
    }

    function fwdelete() {
        [[ -z "$1" ]] && {
            echo "Usage: fwdelete <rule>"
            return 1
        }
        sudo ufw delete "$1"
    }

    function fwdeln() {
        [[ -z "$1" ]] && {
            echo "Usage: fwdeln <rule_number>"
            return 1
        }
        sudo ufw delete "$1"
    }

    function fwlog() {
        [[ -z "$1" ]] && {
            echo "Usage: fwlog <off|low|medium|high|full>"
            return 1
        }
        sudo ufw logging "$1"
    }

    alias fwreset='sudo ufw reset'

    # Common Rules
    alias fwassh='sudo ufw allow ssh'
    alias fwdssh='sudo ufw deny ssh'
    alias fwahttp='sudo ufw allow http'
    alias fwahttps='sudo ufw allow https'
    alias fwamysql='sudo ufw allow mysql'
    alias fwasftp='sudo ufw allow sftp'
    alias fwamongo='sudo ufw allow 27017'
    alias fwaredis='sudo ufw allow 6379'
    alias fwasmtp='sudo ufw allow smtp'
    alias fwaimaps='sudo ufw allow imaps'
    alias fwapop3s='sudo ufw allow pop3s'
fi

###############################################################################
# 🅲🆁🆈🅿🆃🅾🅶🆁🅰🅿🅷🅸🅲 Tools (Checksums, Encryption, etc.)
###############################################################################
# Hashing Utilities (with fallback for macOS)
if command -v sha256sum >/dev/null 2>&1; then
    alias sha256='sha256sum'
    alias sha1='sha1sum'
    alias sha512='sha512sum'
    alias md5='md5sum'
elif command -v shasum >/dev/null 2>&1; then
    # macOS default
    alias sha256='shasum -a 256'
    alias sha1='shasum -a 1'
    alias sha512='shasum -a 512'
    alias md5='md5'  # macOS has `md5` by default
fi

# Password Generation
if command -v pwgen >/dev/null 2>&1; then
    alias pwgen8='pwgen -s 8 1'
    alias pwgen12='pwgen -s 12 1'
    alias pwgen16='pwgen -s 16 1'
    alias pwgen20='pwgen -s 20 1'
    alias pwgen32='pwgen -s 32 1'
    alias pwgen64='pwgen -s 64 1'
fi

# File Encryption with ccrypt
if command -v ccrypt >/dev/null 2>&1; then
    alias cce='ccrypt -e'
    alias ccd='ccrypt -d'
    alias ccc='ccrypt -c'
fi

###############################################################################
# 🆅🆄🅻🅽🅴🆁🅰🅱🅸🅻🅸🆃🆈 / 🆂🅲🅰🅽🅽🅸🅽🅶 Tools
###############################################################################
# Nmap
if command -v nmap >/dev/null 2>&1; then
    alias nms='nmap -sS'
    alias nma='nmap -A'
    alias nmv='nmap -sV'
    alias nmo='nmap -O'
    alias nmp='nmap -Pn'
    alias nmfast='nmap -F'
    alias nmping='nmap -sn'

    function nmscript() {
        [[ -z "$1" || -z "$2" ]] && {
            echo "Usage: nmscript <script_name> <target>"
            return 1
        }
        nmap --script "$1" "$2"
    }

    alias nmvuln='nmap --script vuln'
    alias nmall='nmap -A -T4 -p-'
fi

# Lynis
if command -v lynis >/dev/null 2>&1; then
    alias lyna='sudo lynis audit system'
    alias lynr='sudo lynis show reports'
    alias lyns='sudo lynis update info'
    alias lynsu='sudo lynis update release'
fi

###############################################################################
# 🆂🅴🅲🆄🆁🅸🆃🆈 🅼🅸🆂🅲 (fail2ban, etc.)
###############################################################################
if command -v fail2ban-client >/dev/null 2>&1; then
    alias f2b='sudo fail2ban-client'
    alias f2bs='sudo fail2ban-client status'
    alias f2bsa='sudo fail2ban-client status all'
    alias f2bssh='sudo fail2ban-client status sshd'
    alias f2br='sudo fail2ban-client reload'

    function f2bunban() {
        [[ -z "$1" ]] && {
            echo "Usage: f2bunban <IP>"
            return 1
        }
        sudo fail2ban-client unban "$1"
    }
fi
# shellcheck shell=bash
# 🅷🅴🆁🅾🅺🆄 🅰🅻🅸🅰🆂🅴🆂 - Heroku aliases.
if command -v heroku &>/dev/null; then
  # Sections:
  #
  #   1. Heroku aliases.
  #      1.1 Heroku Access aliases.
  #      1.2 Heroku Addons aliases.
  #      1.3 Heroku Apps aliases.
  #      1.4 Heroku Auth aliases.
  #      1.5 Heroku Authorizations aliases.
  #      1.6 Heroku Authorizations aliases.
  #      1.7 Heroku Certs aliases.
  #      1.8 Heroku ci aliases.
  #      1.9 Heroku config aliases.
  #
  #   2. Heroku Container aliases.
  #      2.1 Heroku Domains aliases.
  #      2.2 Heroku Drains aliases.
  #      2.3 Heroku Dyno aliases.
  #      2.4 Heroku Features aliases.
  #      2.5 Heroku Git aliases.
  #      2.6 Heroku Keys aliases.
  #      2.7 Heroku Maintenance aliases.
  #      2.8 Heroku Members aliases.
  #      2.9 Heroku pg aliases.
  #
  #   3. Heroku Pipelines aliases.
  #      3.1 Heroku ps aliases.
  #      3.2 Heroku redis aliases.
  #      3.3 Heroku Spaces aliases.
  #      3.4 Heroku Webhooks aliases.
  #
  ##  ------------------------------------------------------------------
  ##  1. Heroku Core aliases
  ##  ------------------------------------------------------------------

  ##  ------------------------------------------------------------------
  ##  1.1 Heroku Access aliases.
  ##  ------------------------------------------------------------------

  # hk: Heroku CLI command shortcut.
  alias hkk='heroku'

  # hka: Add new users to your app.
  alias hka='heroku access:add'

  # hkau: Update existing collaborators on an team app.
  alias hkau='heroku access:update'

  # hkh: Display help for heroku.
  alias hkh='heroku help'

  # hkj: Add yourself to a team app.
  alias hkj='heroku join'

  # hkl: List all the commands.
  alias hkl='heroku commands'

  # hkla: List who has access to an app.
  alias hkla='heroku access'

  # hklg: Display recent log output.
  alias hklg='heroku logs'

  # hkn: Display notifications.
  alias hkn='heroku notifications'

  # hko: List the teams that you are a member of.
  alias hko='heroku orgs'

  # hkoo: Open the team interface in a browser.
  alias hkoo='heroku orgs:open'

  # hkp: Open a psql shell to the database.
  alias hkp='heroku psql'

  # hkq: Remove yourself from a team app.
  alias hkq='heroku leave'

  # hkr: Remove users from a team app.
  alias hkr='heroku access:remove'

  # hkrg: List available regions for deployment.
  alias hkrg='heroku regions'

  # hks: Display current status of the Heroku platform.
  alias hks='heroku status'

  # hkt: List the teams that you are a member of.
  alias hkt='heroku teams'

  # hku: Update the heroku CLI.
  alias hku='heroku update'

  # hkulk: Unlock an app so any team member can join.
  alias hkulk='heroku unlock'

  # hkw: Show which plugin a command is in.
  alias hkw='heroku which'

  ##  ------------------------------------------------------------------
  ##  1.2 Heroku Add-ons aliases
  ##  ------------------------------------------------------------------

  # Attach an existing add-on resource to an app.
  alias hkada='heroku addons:attach'

  # Create a new add-on resource.
  alias hkadc='heroku addons:create'

  # Detach an existing add-on resource from an app.
  alias hkadd='heroku addons:detach'

  # Open an add-on's Dev Center documentation in your browser.
  alias hkaddoc='heroku addons:docs'

  # Change add-on plan.
  alias hkaddown='heroku addons:downgrade'

  # Show detailed add-on resource and attachment information.
  alias hkadi='heroku addons:info'

  # Permanently destroy an add-on resource.
  alias hkadk='heroku addons:destroy'

  # Lists your add-ons and attachments.
  alias hkadl='heroku addons'

  # Open an add-on's dashboard in your browser.
  alias hkado='heroku addons:open'

  # List all available plans for an add-on services.
  alias hkadp='heroku addons:plans'

  # Rename an add-on.
  alias hkadr='heroku addons:rename'

  # List all available add-on services.
  alias hkads='heroku addons:services'

  # Change add-on plan.
  alias hkadu='heroku addons:upgrade '

  # Show provisioning status of the add-ons on the app.
  alias hkadw='heroku addons:wait'

  ##  ------------------------------------------------------------------
  ##  1.3 Heroku Apps aliases
  ##  ------------------------------------------------------------------

  # hkapc: Creates a new app.
  alias hkapc='heroku apps:create'

  # hkape: View app errors.
  alias hkape='heroku apps:errors'

  # hkapfav: List favorites apps.
  alias hkapfav='heroku apps:favorites'

  # hkapfava: Favorites an app.
  alias hkapfava='heroku apps:favorites:add'

  # hkapunfav: Unfavorite an app.
  alias hkapunfav='heroku apps:favorites:remove'

  # hkapi: Show detailed app information.
  alias hkapi='heroku apps:info'

  # hkapj: Add yourself to a team app.
  alias hkapj='heroku apps:join'

  # hkapk: Permanently destroy an app.
  alias hkapk='heroku apps:destroy'

  # hkapl: List your apps.
  alias hkapl='heroku apps'

  # hkaplk: Prevent team members from joining an app.
  alias hkaplk='heroku apps:lock'

  # hkapo: Open the app in a web browser.
  alias hkapo='heroku apps:open'

  # hkapq: Remove yourself from a team app.
  alias hkapq='heroku apps:leave'

  # hkapr: Rename an app.
  alias hkapr='heroku apps:rename'

  # hkaps: Show the list of available stacks.
  alias hkaps='heroku apps:stacks'

  # hkapss: Set the stack of an app.
  alias hkapss='heroku apps:stacks:set'

  # hkapt: Transfer applications to another user or team.
  alias hkapt='heroku apps:transfer'

  # hkapulk: Unlock an app so any team member can join.
  alias hkapulk='heroku apps:unlock'

  ##  ------------------------------------------------------------------
  ##  1.4 Heroku Auth 2fa aliases
  ##  ------------------------------------------------------------------

  # hk2fa: Display the current logged in user.
  alias hk2fa='heroku auth:whoami'

  # hk2fad: Disables 2fa on account.
  alias hk2fad='heroku auth:2fa:disable'

  # hk2fain: Login with your Heroku credentials.
  alias hk2fain='heroku auth:login'

  # hk2faout: Clears local login credentials and invalidates API session
  alias hk2faout='heroku auth:logout'

  # hk2fas: Check 2fa status.
  alias hk2fas='heroku auth:2fa'

  # hk2fat: Outputs current CLI authentication token.
  alias hk2fat='heroku auth:token'

  ##  ------------------------------------------------------------------
  ##  1.5 Heroku Authorizations aliases
  ##  ------------------------------------------------------------------

  # hkauc: Create a new OAuth authorization.
  alias hkauc='heroku authorizations:create'

  # hkaui: Show an existing OAuth authorization.
  alias hkaui='heroku authorizations:info'

  # hkaul: List OAuth authorizations.
  alias hkaul='heroku authorizations'

  # hkaur: Revoke OAuth authorization.
  alias hkaur='heroku authorizations:revoke'

  # hkauro: Updates an OAuth authorization token.
  alias hkauro='heroku authorizations:rotate'

  # hkauu: Updates an OAuth authorization.
  alias hkauu='heroku authorizations:update'

  ##  ------------------------------------------------------------------
  ##  1.6 Heroku Build packs aliases
  ##  ------------------------------------------------------------------

  # hkbpac: Display autocomplete installation instructions.
  alias hkbpac='heroku autocomplete'

  # hkbpad: Add new app build-pack, inserting into list of build-packs
  # if necessary.
  alias hkbpad='heroku buildpacks:add'

  # hkbpcl: Clear all build-packs set on the app.
  alias hkbpcl='heroku buildpacks:clear'

  # hkbpi: Fetch info about a build-pack.
  alias hkbpi='heroku buildpacks:info'

  # hkbpl: Display the build-packs for an app.
  alias hkbpl='heroku buildpacks'

  # hkbpr: Remove a build-pack set on the app.
  alias hkbpr='heroku buildpacks:remove'

  # hkbps: Search for build-packs.
  alias hkbps='heroku buildpacks:search'

  # hkbpv: List versions of a build-pack.
  alias hkbpv='heroku buildpacks:versions'

  ##  ------------------------------------------------------------------
  ##  1.7 Heroku Certs aliases
  ##  ------------------------------------------------------------------

  # hkca: Show ACM status for an app.
  alias hkca='heroku certs:auto'

  # hkcad: Add an SSL certificate to an app.
  alias hkcad='heroku certs:add'

  # hkcae: Enable ACM status for an app.
  alias hkcae='heroku certs:auto:enable'

  # hkcak: Disable ACM for an app.
  alias hkcak='heroku certs:auto:disable'

  # hkcar: Refresh ACM for an app.
  alias hkcar='heroku certs:auto:refresh'

  # hkcc: Print an ordered & complete chain for a certificate.
  alias hkcc='heroku certs:chain'

  # hkcg: Generate a key and a CSR or self-signed certificate.
  alias hkcg='heroku certs:generate'

  # hkci: Show certificate information for an SSL certificate.
  alias hkci='heroku certs:info'

  # hkck: Print the correct key for the given certificate.
  alias hkck='heroku certs:key'

  # hkcl: List SSL certificates for an app.
  alias hkcl='heroku certs'

  # hkcr: Remove an SSL certificate from an app.
  alias hkcr='heroku certs:remove'

  # hkcu: Update an SSL certificate on an app.
  alias hkcu='heroku certs:update'

  ##  ------------------------------------------------------------------
  ##  1.8 Heroku ci aliases
  ##  ------------------------------------------------------------------

  # hkcicg: Get a CI config var.
  alias hkcicg='heroku ci:config:get'

  # hkcics: Set CI config vars.
  alias hkcics='heroku ci:config:set'

  # hkcicu: Unset CI config vars.
  alias hkcicu='heroku ci:config:unset'

  # hkcicv: Display CI config vars.
  alias hkcicv=' ci:config'

  # hkcid: Opens an interactive test debugging session with the contents
  # of the current directory.
  alias hkcid='heroku ci:debug'

  # hkcie: Looks for the most recent run and returns the output of that
  # run.
  alias hkcie='heroku ci:last'

  # hkcii: Show the status of a specific test run.
  alias hkcii='heroku ci:info'

  # hkcil: Display the most recent CI runs for the given pipeline.
  alias hkcil='heroku ci'

  # hkcim: 'app-ci.json' is deprecated. Run this command to migrate to
  # app.json with an environments key.
  alias hkcim='heroku ci:migrate-manifest'

  # hkcio: Open the Dashboard version of Heroku CI.
  alias hkcio='heroku ci:open'

  # hkcir: Run tests against current directory.
  alias hkcir='heroku ci:run'

  # hkcir2: Rerun tests against current directory.
  alias hkcir2='heroku ci:rerun'

  ##  ------------------------------------------------------------------
  ##  1.9 Heroku config aliases
  ##  ------------------------------------------------------------------

  # hkclc: Create a new OAuth client.
  alias hkclc='heroku clients:create'

  # hkcli: Show details of an oauth client.
  alias hkcli='heroku clients:info'

  # hkclk: Delete client by ID.
  alias hkclk='heroku clients:destroy'

  # hkcll: List your OAuth clients.
  alias hkcll='heroku clients'

  # hkcls: Rotate OAuth client secret.
  alias hkcls='heroku clients:rotate'

  # hkclu: Update OAuth client.
  alias hkclu='heroku clients:update'

  ##  ------------------------------------------------------------------
  ##  2. Heroku Configuration aliases
  ##  ------------------------------------------------------------------

  # hkcfe: Interactively edit config vars.
  alias hkcfe='heroku config:edit'

  # hkcfg: Display a single config value for an app.
  alias hkcfg='heroku config:get'

  # hkcfs: Set one or more config vars.
  alias hkcfs='heroku config:set'

  # hkcfu: Unset one or more config vars.
  alias hkcfu='heroku config:unset'

  # hkcfv: Display the config vars for an app.
  alias hkcfv='heroku config'

  ##  ------------------------------------------------------------------
  ##  2.1 Heroku Container aliases
  ##  ------------------------------------------------------------------

  # hkct: Use containers to build and deploy Heroku apps.
  alias hkct='heroku container'

  # hkctin: Log in to Heroku Container Registry.
  alias hkctin='heroku container:login'

  # hkctout: Log out from Heroku Container Registry.
  alias hkctout='heroku container:logout'

  # hkctpull: Pulls an image from an app's process type.
  alias hkctpull='heroku container:pull'

  # hkctpush: Builds, then pushes Docker images to deploy your Heroku
  # app.
  alias hkctpush='heroku container:push'

  # hkctrelease: Releases previously pushed Docker images to your Heroku
  # app.
  alias hkctrelease='heroku container:release'

  # hkctrm: Remove the process type from your app.
  alias hkctrm='heroku container:rm'

  # hkctrun: Builds, then runs the docker image locally.
  alias hkctrun='heroku container:run'

  ##  ------------------------------------------------------------------
  ##  2.2 Heroku Domains aliases
  ##  ------------------------------------------------------------------

  # hkdo: List domains for an app.
  alias hkdo='heroku domains'

  # hkdoa: Add a domain to an app.
  alias hkdoa='heroku domains:add'

  # hkdoc: Remove all domains from an app.
  alias hkdoc='heroku domains:clear'

  # hkdoi: Show detailed information for a domain on an app.
  alias hkdoi='heroku domains:info'

  # hkdor: Remove a domain from an app.
  alias hkdor='heroku domains:remove'

  # hkdou: Update a domain to use a different SSL certificate on an app.
  alias hkdou='heroku domains:update'

  # hkdow: Wait for domain to be active for an app.
  alias hkdow='heroku domains:wait'

  ##  ------------------------------------------------------------------
  ##  2.3 Heroku Drains aliases
  ##  ------------------------------------------------------------------

  # hkdr: Display the log drains of an app.
  alias hkdr='heroku drains'

  # hkdra: Adds a log drain to an app.
  alias hkdra='heroku drains:add'

  # hkdrr: Removes a log drain from an app.
  alias hkdrr='heroku drains:remove'

  ##  ------------------------------------------------------------------
  ##  2.4 Heroku Dyno aliases
  ##  ------------------------------------------------------------------

  # hkdyk: Stop app dyno.
  alias hkdyk='heroku dyno:kill'

  # hkdyrz: Manage dyno sizes.
  alias hkdyrz='heroku dyno:resize'

  # hkdyrs: Restart app dynos.
  alias hkdyrs='heroku dyno:restart'

  # hkdysc: Scale dyno quantity up or down.
  alias hkdysc='heroku dyno:scale'

  # hkdyst: Stop app dyno.
  alias hkdyst='heroku dyno:stop'

  ##  ------------------------------------------------------------------
  ##  2.5 Heroku Features aliases
  ##  ------------------------------------------------------------------

  # hkfeat: List available app features.
  alias hkfeat='heroku features'

  # hkfeatd: Disables an app feature.
  alias hkfeatd='heroku features:disable'

  # hkfeate: Enables an app feature.
  alias hkfeate='heroku features:enable'

  # hkfeati: Display information about a feature.
  alias hkfeati='heroku features:info'

  ##  ------------------------------------------------------------------
  ##  2.6 Heroku Git aliases
  ##  ------------------------------------------------------------------

  # Clones a heroku app to your local machine at DIRECTORY
  # (defaults to app name).
  alias hkgitc='heroku git:clone'

  # Adds a git remote to an app repo.
  alias hkgitr='heroku git:remote'

  ##  ------------------------------------------------------------------
  ##  2.7 Heroku Keys aliases
  ##  ------------------------------------------------------------------

  # Display your SSH keys.
  alias hkk='heroku keys'

  # Add an SSH key for a user.
  alias hkka='heroku keys:add'

  # Remove all SSH keys for current user.
  alias hkkcl='heroku keys:clear'

  # Remove an SSH key from the user.
  alias hkkr='heroku keys:remove'

  ##  ------------------------------------------------------------------
  ##  2.8 Heroku Labs aliases
  ##  ------------------------------------------------------------------

  # hklab: List experimental features.
  alias hklab='heroku labs'

  # hklabd: Disables an experimental feature.
  alias hklabd='heroku labs:disable'

  # hklabe: Enables an experimental feature.
  alias hklabe='heroku labs:enable'

  # hklabi: Show feature info.
  alias hklabi='heroku labs:info'

  ##  ------------------------------------------------------------------
  ##  3. Heroku Advanced aliases
  ##  ------------------------------------------------------------------

  ##  ------------------------------------------------------------------
  ##  3.1 Heroku Local aliases
  ##  ------------------------------------------------------------------

  # hkloc: Run heroku app locally.
  alias hkloc='heroku local'

  # hklocr: Run a one-off command.
  alias hklocr='heroku local:run'

  # hklocv: Display node-foreman version.
  alias hklocv='heroku local:version'

  # hkloclk: Prevent team members from joining an app.
  alias hkloclk='heroku lock'

  ##  ------------------------------------------------------------------
  ##  3.2 Heroku Maintenance aliases
  ##  ------------------------------------------------------------------

  # hkmt: Display the current maintenance status of app.
  alias hkmt='heroku maintenance'

  # hkmtoff: Take the app out of maintenance mode.
  alias hkmtoff='heroku maintenance:off'

  # hkmton: Put the app into maintenance mode.
  alias hkmton='heroku maintenance:on'

  ##  ------------------------------------------------------------------
  ##  3.3 Heroku Members aliases
  ##  ------------------------------------------------------------------

  # hkmb: List members of a team.
  alias hkmb='heroku members'

  # hkmba: Adds a user to a team.
  alias hkmba='heroku members:add'

  # hkmbr: Removes a user from a team.
  alias hkmbr='heroku members:remove'

  # hkmbs: Sets a members role in a team.
  alias hkmbs='heroku members:set'

  ##  ------------------------------------------------------------------
  ##  3.4 Heroku Postgres aliases
  ##  ------------------------------------------------------------------

  # hkpg: Show database information.
  alias hkpg='heroku pg'

  # hkpgb: Show table and index bloat in your database ordered by most
  # wasteful.
  alias hkpgb='heroku pg:bloat'

  # hkpgbk: List database backups.
  alias hkpgbk='heroku pg:backups'

  # hkpgbkcl: Cancel an in-progress backup or restore (default newest).
  alias hkpgbkcl='heroku pg:backups:cancel'

  # hkpgbkc: Capture a new backup.
  alias hkpgbkc='heroku pg:backups:capture'

  # hkpgbkdl: Delete a backup.
  alias hkpgbkdl='heroku pg:backups:delete'

  # hkpgbkdw: Downloads database backup.
  alias hkpgbkdw='heroku pg:backups:download'

  # hkpgbki: Get information about a specific backup.
  alias hkpgbki='heroku pg:backups:info'

  # hkpgbkr: Restore a backup (default latest) to a database.
  alias hkpgbkr='heroku pg:backups:restore'

  # hkpgbks: Schedule daily backups for given database.
  alias hkpgbks='heroku pg:backups:schedule'

  # hkpgbksh: List backup schedule.
  alias hkpgbksh='heroku pg:backups:schedules'

  # hkpgbkurl: Get secret but publicly accessible URL of a backup.
  alias hkpgbkurl='heroku pg:backups:url'

  # hkpgbkk: Stop daily backups.
  alias hkpgbkk='heroku pg:backups:unschedule'

  # hkpgblk: Display queries holding locks other queries are waiting to
  # be released.
  alias hkpgblk='heroku pg:blocking'

  # hkpgc: Copy all data from source db to target.
  alias hkpgc='heroku pg:copy'

  # hkpgcpa: Add an attachment to a database using connection pooling.
  alias hkpgcpa='heroku pg:connection-pooling:attach'

  # hkpgcr: Show information on credentials in the database.
  alias hkpgcr='heroku pg:credentials'

  # hkpgcrc: Create credential within database.
  alias hkpgcrc='heroku pg:credentials:create'

  # hkpgcrd: Destroy credential within database.
  alias hkpgcrd='heroku pg:credentials:destroy'

  # hkpgcrr: Rotate the database credentials.
  alias hkpgcrr='heroku pg:credentials:rotate'

  # hkpgcrrd: Repair the permissions of the default credential within
  # database.
  alias hkpgcrrd='heroku pg:credentials:repair-default'

  # hkpgcrurl: Show information on a database credential.
  alias hkpgcrurl='heroku pg:credentials:url'

  # hkpgdg: Run or view diagnostics report.
  alias hkpgdg='heroku pg:diagnose'

  # hkpgi: Show database information.
  alias hkpgi='heroku pg:info'

  # hkpgk: Kill a query.
  alias hkpgk='heroku pg:kill'

  # hkpgka: Terminates all connections for all credentials.
  alias hkpgka='heroku pg:killall'

  # hkpglks: Display queries with active locks.
  alias hkpglks='heroku pg:locks'

  # hkpglnk: Lists all databases and information on link.
  alias hkpglnk='heroku pg:links'

  # hkpglnkc: Create a link between data stores.
  alias hkpglnkc='heroku pg:links:create'

  # hkpglnkd: Destroys a link between data stores.
  alias hkpglnkd='heroku pg:links:destroy'

  # hkpgmt: Show current maintenance information.
  alias hkpgmt='heroku pg:maintenance'

  # hkpgmtr: Start maintenance.
  alias hkpgmtr='heroku pg:maintenance:run'

  # hkpgmtw: Set weekly maintenance window.
  alias hkpgmtw='heroku pg:maintenance:window'

  # hkpgo: Show 10 queries that have longest execution time in
  # aggregate.
  alias hkpgo='heroku pg:outliers'

  # hkpgp: Sets DATABASE as your DATABASE_URL.
  alias hkpgp='heroku pg:promote'

  # hkpgps: View active queries with execution time.
  alias hkpgps='heroku pg:ps'

  # hkpgpsql: Open a psql shell to the database.
  alias hkpgpsql='heroku pg:psql'

  # hkpgpull: Pull Heroku database into local or remote database.
  alias hkpgpull='heroku pg:pull'

  # hkpgpush: Push local or remote into Heroku database.
  alias hkpgpush='heroku pg:push'

  # hkpgreset: Delete all data in DATABASE.
  alias hkpgreset='heroku pg:reset'

  # hkpgreset: Show your current database settings.
  alias hkpgset='heroku pg:settings'

  # hkpgsetllw: Controls whether a log message is produced when a
  # session waits longer than the deadlock_timeout to acquire a lock.
  alias hkpgsetllw='heroku pg:settings:log-lock-waits'

  # hkpgsetlmds: The duration of each completed statement will be logged
  # if the statement completes after the time specified by VALUE.
  alias hkpgsetlmds='heroku pg:settings:log-min-duration-statement'

  # hkpgsetlgs: 'log_statement' controls which SQL statements
  # are logged.
  alias hkpgsetlgs='heroku pg:settings:log-statement'

  # hkpguf: Stop a replica from following and make it a writeable
  # database.
  alias hkpguf='heroku pg:unfollow'

  # hkpgup: Unfollow a database and upgrade it to the latest stable
  # PostgreSQL version.
  alias hkpgup='heroku pg:upgrade'

  # hkpgvs: Show dead rows and whether an automatic vacuum is expected
  # to be triggered.
  alias hkpgvs='heroku pg:vacuum-stats'

  # hkpgww: Blocks until database is available.
  alias hkpgww='heroku pg:wait'

  ##  ------------------------------------------------------------------
  ##  3.5 Heroku Pipelines aliases
  ##  ------------------------------------------------------------------

  # List pipelines you have access to.
  alias hkpipe='heroku pipelines'

  # Add this app to a pipeline.
  alias hkpipea='heroku pipelines:add'

  # Create a new pipeline.
  alias hkpipec='heroku pipelines:create'

  # Connect a github repo to an existing pipeline.
  alias hkpipect='heroku pipelines:connect'

  # Compares the latest release of this app to its downstream app(s).
  alias hkpipediff='heroku pipelines:diff'

  # Show list of apps in a pipeline.
  alias hkpipei='heroku pipelines:info'

  # Destroy a pipeline.
  alias hkpipek='heroku pipelines:destroy'

  # Open a pipeline in dashboard.
  alias hkpipeo='heroku pipelines:open'

  # Promote the latest release of this app to its downstream app(s).
  alias hkpipep='heroku pipelines:promote'

  # Remove this app from its pipeline.
  alias hkpiper='heroku pipelines:remove'

  # Rename a pipeline.
  alias hkpipern='heroku pipelines:rename'

  # Bootstrap a new pipeline with common settings and create a
  # production and staging app (requires a fully formed app.json in
  # the repo).
  alias hkpipes='heroku pipelines:setup'

  # Transfer ownership of a pipeline.
  alias hkpipett='heroku pipelines:transfer'

  # Update the app's stage in a pipeline.
  alias hkpipeu='heroku pipelines:update'

  ##  ------------------------------------------------------------------
  ##  3.6 Heroku Plugins aliases
  ##  ------------------------------------------------------------------

  # hkplugs: List installed plugins.
  alias hkplugs='heroku plugins'

  # hkplugsi: Installs a plugin into the CLI.
  alias hkplugsi='heroku plugins:install'

  # hkplugslk: Links a plugin into the CLI for development.
  alias hkplugslk='heroku plugins:link'

  # hkplugsui: Removes a plugin from the CLI.
  alias hkplugsui='heroku plugins:uninstall'

  # hkplugsu: Update installed plugins.
  alias hkplugsu='heroku plugins:update'

  ##  ------------------------------------------------------------------
  ##  3.7 Heroku 'ps' aliases
  ##  ------------------------------------------------------------------

  # hkpsad: Disable web dyno autoscaling.
  alias hkpsad='heroku ps:autoscale:disable'

  # hkps: List dynos for an app.
  alias hkps='heroku ps'

  # hkpsae: Enable web dyno autoscaling.
  alias hkpsae='heroku ps:autoscale:enable '

  # hkpsc: Copy a file from a dyno to the local filesystem.
  alias hkpsc='heroku ps:copy'

  # hkpse: Create an SSH session to a dyno.
  alias hkpse='heroku ps:exec'

  # hkpsf: Forward traffic on a local port to a dyno.
  alias hkpsf='heroku ps:forward'

  # hkpsk: Stop app dyno.
  alias hkpsk='heroku ps:kill'

  # hkpsr: Restart app dynos.
  alias hkpsr='heroku ps:restart'

  # hkpsrs: Manage dyno sizes.
  alias hkpsrs='heroku ps:resize'

  # hkpss: Stop app dyno.
  alias hkpss='heroku ps:stop'

  # hkpssc: Scale dyno quantity up or down.
  alias hkpssc='heroku ps:scale'

  # hkpssck: Launch a SOCKS proxy into a dyno.
  alias hkpssck='heroku ps:socks'

  # hkpst: Manage dyno sizes.
  alias hkpst='heroku ps:type'

  # hkpsw: Wait for all dynos to be running latest version after
  # a release.
  alias hkpsw='heroku ps:wait'

  ##  ------------------------------------------------------------------
  ##  3.8 Heroku redis aliases
  ##  ------------------------------------------------------------------

  # hkred: Gets information about redis.
  alias hkred='heroku redis'

  # hkredcli: Opens a redis prompt.
  alias hkredcli='heroku redis:cli'

  # hkredcr: Display credentials information.
  alias hkredcr='heroku redis:credentials'

  # hkredi: Gets information about redis.
  alias hkredi='heroku redis:info'

  # hkredkn: Set the keyspace notifications configuration.
  alias hkredkn='heroku redis:keyspace-notifications'

  # hkredmm: Set the key eviction policy.
  alias hkredmm='heroku redis:maxmemory'

  # hkredmt: Manage maintenance windows.
  alias hkredmt='heroku redis:maintenance'

  # hkredp: Sets DATABASE as your REDIS_URL.
  alias hkredp='heroku redis:promote'

  # hkredsr: Reset all stats covered by RESETSTAT
  # (<https://redis.io/commands/config-resetstat>).
  alias hkredsr='heroku redis:stats-reset'

  # hkredt: Set the number of seconds to wait before killing idle
  # connections.
  alias hkredt='heroku redis:timeout'

  # hkredw: Wait for Redis instance to be available.
  alias hkredw='heroku redis:wait'

  ##  ------------------------------------------------------------------
  ##  3.9 Heroku Releases aliases
  ##  ------------------------------------------------------------------

  # hkrel: Display the releases for an app.
  alias hkrel='heroku releases'

  # hkreli: View detailed information for a release.
  alias hkreli='heroku releases:info'

  # hkrelo: View the release command output.
  alias hkrelo='heroku releases:output'

  # hkrelr: Rollback to a previous release.
  alias hkrelr='heroku releases:rollback'

  ##  ------------------------------------------------------------------
  ##  3.10.1 Heroku Spaces aliases
  ##  ------------------------------------------------------------------

  # hkrvae: Enable review apps and/or settings on an existing pipeline.
  alias hkrvae='heroku reviewapps:enable'

  # hkrvad: Disable review apps and/or settings on an existing pipeline.
  alias hkrvad='heroku reviewapps:disable'

  ##  ------------------------------------------------------------------
  ##  3.10.2 Heroku Run aliases
  ##  ------------------------------------------------------------------

  # hkrun: Run a one-off process inside a heroku dyno.
  alias hkrun='heroku run'

  # hkrund: Run a detached dyno, where output is sent to your logs.
  alias hkrund='heroku run:detached'

  ##  ------------------------------------------------------------------
  ##  3.10.3 Heroku Sessions aliases
  ##  ------------------------------------------------------------------

  # hksessions: List your OAuth sessions.
  alias hksessions='heroku sessions'

  # hksessionsd: Delete (logout) OAuth session by ID.
  alias hksessionsd='heroku sessions:destroy'

  ##  ------------------------------------------------------------------
  ##  3.10.4 Heroku Spaces aliases
  ##  ------------------------------------------------------------------

  # hksp: List available spaces.
  alias hksp='heroku spaces'

  # hkspc: Create a new space.
  alias hkspc='heroku spaces:create'

  # hkspd: Destroy a space.
  alias hkspd='heroku spaces:destroy'

  # hkspi: Show info about a space.
  alias hkspi='heroku spaces:info'

  # hksppi: Display the information necessary to initiate a peering
  # connection.
  alias hksppi='heroku spaces:peering:info'

  # hkspp: List peering connections for a space.
  alias hkspp='heroku spaces:peerings'

  # hksppa: Accepts a pending peering request for a private space.
  alias hksppa='heroku spaces:peerings:accept'

  # hksppd: Destroys an active peering connection in a private space.
  alias hksppd='heroku spaces:peerings:destroy'

  # hkspps: List dynos for a space.
  alias hkspps='heroku spaces:ps'

  # hkspr: Renames a space.
  alias hkspr='heroku spaces:rename'

  # hksptop: Show space topology.
  alias hksptop='heroku spaces:topology'

  # hkspt: Transfer a space to another team.
  alias hkspt='heroku spaces:transfer'

  # hkspconf: Display the configuration information for VPN.
  alias hkspconf='heroku spaces:vpn:config'

  # hkspvc: Create VPN.
  alias hkspvc='heroku spaces:vpn:connect'

  # hkspvcs: List the VPN Connections for a space.
  alias hkspvcs='heroku spaces:vpn:connections'

  # hkspvk: Destroys VPN in a private space.
  alias hkspvk='heroku spaces:vpn:destroy'

  # hkspvi: Display the information for VPN.
  alias hkspvi='heroku spaces:vpn:info'

  # hkspvu: Update VPN.
  alias hkspvu='heroku spaces:vpn:update'

  # hkspvw: Wait for VPN Connection to be created.
  alias hkspvw='heroku spaces:vpn:wait'

  # hkspw: Wait for a space to be created.
  alias hkspw='heroku spaces:wait'

  ##  ------------------------------------------------------------------
  ##  3.10.5 Heroku Webhooks aliases
  ##  ------------------------------------------------------------------

  # hkwh: List webhooks on an app.
  alias hkwh='heroku webhooks'

  # hkwha: Add a webhook to an app.
  alias hkwha='heroku webhooks:add'

  # hkwhdv: List webhook deliveries on an app.
  alias hkwhdv='heroku webhooks:deliveries'

  # hkwhdvi: Info for a webhook event on an app.
  alias hkwhdvi='heroku webhooks:deliveries:info'

  # hkwhev: List webhook events on an app.
  alias hkwhev='heroku webhooks:events'

  # hkwhevi: Info for a webhook event on an app.
  alias hkwhevi='heroku webhooks:events:info'

  # hkwhi: Info for a webhook on an app.
  alias hkwhi='heroku webhooks:info'

  # hkwhr: Removes a webhook from an app.
  alias hkwhr='heroku webhooks:remove'

  # hkwhu: Updates a webhook in an app.
  alias hkwhu='heroku webhooks:update'
fi
# shellcheck shell=bash
# Version: 0.2.472
# Website: https://dotfiles.io

# 🅵🅸🅽🅳 🅰🅻🅸🅰🆂🅴🆂

if command -v fd &>/dev/null; then
  # fd: a simple, fast and user-friendly alternative to find
  # Always colorize output by default.
  alias fd='fd --color always'

  # List all files with absolute path.
  alias fda='fd --absolute-path'

  # List all files with case-insensitive search.
  alias fdc='fd --ignore-case'

  # List all files with details.
  alias fdd='fd --list-details'

  # List all files with extension.
  alias fde='fd --extension'

  # List all files with follow symlinks.
  alias fdf='fd --follow'

  # List all files with help.
  alias fdh='fd --help'

  # List all files, including hidden files.
  alias fdh='fd --hidden'

  # List all files with glob.
  alias fdn='fd --glob'

  # List all files with owner.
  alias fdo='fd --owner'

  # List all files with size.
  alias fds='fd --size'

  # List all files with exclude.
  alias fdu='fd --exclude'

  # List all files with version.
  alias fdv='fd --version'

  # Execute a command for each search result.
  alias fdx='fd --exec'

  # Use fd as a replacement for find.
  alias find='fd'

fi
# shellcheck shell=bash
# Terraform & IaC Aliases

# Terraform
if command -v terraform &>/dev/null; then
  alias tf='terraform'
  alias tfi='terraform init'
  alias tfp='terraform plan'
  alias tfa='terraform apply'
  alias tfaa='terraform apply -auto-approve'
  alias tfd='terraform destroy'
  alias tfda='terraform destroy -auto-approve'
  alias tff='terraform fmt'
  alias tfv='terraform validate'
  alias tfo='terraform output'
  alias tfs='terraform state'
fi

# OpenTofu (Drop-in replacement support)
if command -v tofu &>/dev/null; then
  alias tofu='tofu'
  alias tip='tofu init && tofu plan'
fi

# Ansible
if command -v ansible &>/dev/null; then
  alias ans='ansible'
  alias ansp='ansible-playbook'
  alias ansg='ansible-galaxy'
  alias anslint='ansible-lint'
fi
# shellcheck shell=bash
# 🆆🅶🅴🆃 🅰🅻🅸🅰🆂🅴🆂
if command -v 'wget' >/dev/null; then

  # wget.
  alias wg='wget'

  # wget with continue.
  alias wgc='wg'

  # wget with robots=off.
  alias wge='wg -e robots=off'

  # wget with continue.
  alias wget='wget -c'
fi
# shellcheck shell=bash
# VS Code Aliases

if [[ "$(uname || true)" = "Darwin" ]]; then
  alias code="/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code"
elif [[ "$(uname || true)" = "Linux" ]]; then
  alias code="code"
fi

alias vs="code"
# alias vsc="code" -> Managed by function in functions.sh
alias vscode="code"
# shellcheck shell=bash
# macOS Aliases

if [[ "$OSTYPE" == "darwin"* ]]; then
  
  # --- Finder & Desktop ---
  
  # Recursively delete .DS_Store files with check
  # alias clds='find . -type f -name "*.DS_Store" -ls -delete'
  alias cleanup_dsstore='find . -type f -name "*.DS_Store" -ls -delete'
  
  alias emptytrash='rm -rf ~/.Trash/*'
  
  # Hide/Show Hidden Files
  alias finder_hide='defaults write com.apple.finder ShowAllFiles FALSE; killall Finder'
  alias finder_show='defaults write com.apple.finder ShowAllFiles TRUE; killall Finder'
  
  # Hide/Show Desktop Icons
  alias desktop_hide='defaults write com.apple.finder CreateDesktop false; killall Finder'
  alias desktop_show='defaults write com.apple.finder CreateDesktop true; killall Finder'
  
  # Open current directory in Finder
  alias ofd='open $PWD'
  
  # --- System & Network ---
  
  alias lockscreen='/System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend'
  
  # Wireless
  alias wifi_on='networksetup -setairportpower en0 on'
  alias wifi_off='networksetup -setairportpower en0 off'

  # Disk Utilities
  alias verify_perms='diskutil verifyPermissions /'
  alias verify_volume='diskutil verifyVolume /'

  # --- Development ---
  
  alias xcode='open -a Xcode'
  alias iphone='open /Applications/Xcode.app/Contents/Developer/Applications/Simulator.app'
  
  # Clean Xcode DerivedData
  alias cleanup_xcode='rm -rf ~/Library/Developer/Xcode/DerivedData/*'
  
  # --- Misc ---
  
  # Clean up LaunchServices to remove duplicates in the 'Open With' menu
  alias cleanup_ls='
    /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -kill -r -domain local -domain system -domain user && \
    killall Finder
  '

  # Disable .DS_Store compilation on network stores
  alias no_network_ds='defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true'
  
  alias safari_safe='open -a Safari --args -safe-mode'
  
  # Screensaver
  alias screensaver='/System/Library/Frameworks/ScreenSaver.framework/Resources/ScreenSaverEngine.app/Contents/MacOS/ScreenSaverEngine -background'

fi
# shellcheck shell=bash
# Version: 0.2.472
# Website: https://dotfiles.io

# 🅳🅸🆂🅺 🆄🆂🅰🅶🅴 🅰🅻🅸🅰🆂🅴🆂

if command -v 'du' >/dev/null; then

  # Display the disk usage of the current directory.
  alias du="du -h"

  # File size of files and directories in current directory.
  alias du1='du -hxd 1 | sort -h'

  # Top 10 largest files and directories in current directory.
  alias ducks="du -cks * .* | sort -rn | head -n 10"

  # File size of files and directories.
  alias duh='du'

  # File size human readable output sorted by size.
  alias dus='du -hs *'

  # File size of files and directories in current directory including
  # symlinks.
  alias dusym="du * -hsLc"

  # Total file size of current directory.
  alias dut='dus'

fi

# shellcheck shell=bash
# Description: This script provides enhanced functionality to quickly navigate directories.
# Website: https://dotfiles.io
# License: MIT
################################################################################

#-----------------------------------------------------------------------------
# Script configuration and version
#-----------------------------------------------------------------------------
DOTFILES_VERSION="0.2.472"
DOTFILES_LAST_UPDATED="2025-03-12"

#-----------------------------------------------------------------------------
# OS Detection for cross-platform compatibility
#-----------------------------------------------------------------------------
DOTFILES_OS="$(uname -s)"
case "${DOTFILES_OS}" in
    Darwin*)
        # macOS specific settings - no group directories option
        LS_COLOR_OPT="-G"
        LS_GROUP_DIRS=""
        SED_INPLACE="sed -i ''"
        ;;
    Linux*)
        # Linux specific settings
        LS_COLOR_OPT="--color=auto"
        LS_GROUP_DIRS="--group-directories-first"
        SED_INPLACE="sed -i"
        ;;
    *)
        # Default settings for other systems
        LS_COLOR_OPT=""
        LS_GROUP_DIRS=""
        # shellcheck disable=SC2034
        SED_INPLACE="sed -i"
        ;;
esac

#-----------------------------------------------------------------------------
# Configuration and customization options
#-----------------------------------------------------------------------------
# These variables can be overridden in your .bashrc or .zshrc
SHOW_HIDDEN_FILES=${SHOW_HIDDEN_FILES:-false}
ENABLE_COLOR_OUTPUT=${ENABLE_COLOR_OUTPUT:-true}
ENABLE_DIR_GROUPING=${ENABLE_DIR_GROUPING:-true}
MAX_RECENT_DIRS=${MAX_RECENT_DIRS:-10}
BOOKMARK_FILE="${HOME}/.dir_bookmarks"
LAST_DIR_FILE="${HOME}/.last_working_dir"
AUTO_LIST_AFTER_CD=${AUTO_LIST_AFTER_CD:-true}
RESTORE_LAST_DIR=${RESTORE_LAST_DIR:-false}
LARGE_DIR_THRESHOLD=${LARGE_DIR_THRESHOLD:-1000} # Skip auto-listing for dirs with >1000 files

# Build the ls command based on configuration
LS_CMD="ls -lh"

if [[ "${SHOW_HIDDEN_FILES}" == "true" ]]; then
    LS_CMD="${LS_CMD} -a"
fi

if [[ "${ENABLE_COLOR_OUTPUT}" == "true" && -n "${LS_COLOR_OPT}" ]]; then
    LS_CMD="${LS_CMD} ${LS_COLOR_OPT}"
fi

# Only add group directories option if it's supported and enabled
if [[ "${ENABLE_DIR_GROUPING}" == "true" && -n "${LS_GROUP_DIRS}" ]]; then
    LS_CMD="${LS_CMD} ${LS_GROUP_DIRS}"
fi

#-----------------------------------------------------------------------------
# Frequently Used Directory Variables
#-----------------------------------------------------------------------------
HOME_DIR="${HOME}"
APP_DIR="${HOME}/Applications"
CODE_DIR="${HOME}/Code"
DESK_DIR="${HOME}/Desktop"
DOCS_DIR="${HOME}/Documents"
DOTF_DIR="${HOME}/.dotfiles"
DOWN_DIR="${HOME}/Downloads"
MUSIC_DIR="${HOME}/Music"
PICS_DIR="${HOME}/Pictures"
VIDS_DIR="${HOME}/Videos"

# Recent directories array
RECENT_DIRS=()

#-----------------------------------------------------------------------------
# Utility Functions
#-----------------------------------------------------------------------------

# Safely create or modify files
safe_write_file() {
    local file="$1"
    local content="$2"
    local mode="${3:-w}" # Default to overwrite mode

    # Create directory if it doesn't exist
    local dir
    dir=$(dirname "${file}")
    if [[ ! -d "${dir}" ]]; then
        mkdir -p "${dir}" 2>/dev/null || {
            echo "Error: Could not create directory ${dir}"
            return 1
        }
    fi

    # Write content to file
    if [[ "${mode}" == "a" ]]; then
        # Append mode
        echo "${content}" >> "${file}" 2>/dev/null
    else
        # Write mode
        echo "${content}" > "${file}" 2>/dev/null
    fi

    # Check if write was successful
    # shellcheck disable="SC2181,2320"
    if [[ $? -ne 0 ]]; then
        echo "Error: Could not write to ${file}"
        return 1
    fi

    return 0
}

# Count items in directory (for performance optimization)
count_dir_items() {
    local dir="$1"
    local count

    # Use ls and wc instead of find to avoid fd compatibility issues
    if [[ "${SHOW_HIDDEN_FILES}" == "true" ]]; then
        # shellcheck disable=SC2012
        count=$(ls -A "$dir" 2>/dev/null | wc -l | tr -d ' ')
    else
        # shellcheck disable=SC2012
        count=$(ls "$dir" 2>/dev/null | wc -l | tr -d ' ')
    fi

    echo "$count"
}

#-----------------------------------------------------------------------------
# Directory Navigation Functions
#-----------------------------------------------------------------------------

# Enhanced cd function with directory history tracking
cd_with_history() {
    # Get the destination directory
    local dest="${1:-$HOME}"

    # Check if the destination is a bookmark
    if [[ -f "${BOOKMARK_FILE}" ]]; then
        local bookmark_dest
        bookmark_dest=$(grep "^${dest}:" "${BOOKMARK_FILE}" | cut -d':' -f2)
        if [[ -n "${bookmark_dest}" ]]; then
            dest="${bookmark_dest}"
        fi
    fi

    # Validate directory
    if [[ ! -d "${dest}" ]]; then
        echo "Error: Directory '${dest}' not found"
        return 1
    fi

    if [[ ! -r "${dest}" ]]; then
        echo "Error: Directory '${dest}' is not readable"
        return 1
    fi

    if [[ ! -x "${dest}" ]]; then
        echo "Error: Directory '${dest}' is not accessible"
        return 1
    fi

    # Save current directory to history
    if [[ "${PWD}" != "${dest}" ]]; then
        # Add to recent dirs (avoid duplicates)
        local found=false
        for dir in "${RECENT_DIRS[@]}"; do
            if [[ "${dir}" == "${PWD}" ]]; then
                found=true
                break
            fi
        done

        if [[ "${found}" == false ]]; then
            RECENT_DIRS=("${PWD}" "${RECENT_DIRS[@]}")

            # Limit array size
            if [[ ${#RECENT_DIRS[@]} -gt ${MAX_RECENT_DIRS} ]]; then
                RECENT_DIRS=("${RECENT_DIRS[@]:0:${MAX_RECENT_DIRS}}")
            fi
        fi
    fi

    # Change directory
    builtin cd "${dest}" 2>/dev/null || return 1

    # Check if cd was successful
    # shellcheck disable=SC2181
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to navigate to '${dest}'"
        return 1
    fi

    # Save last working directory
    safe_write_file "${LAST_DIR_FILE}" "${PWD}"

    # List directory contents if enabled and not a large directory
    if [[ "${AUTO_LIST_AFTER_CD}" == "true" ]]; then
        local item_count
        item_count=$(count_dir_items "${PWD}")
        if [[ ${item_count} -lt ${LARGE_DIR_THRESHOLD} ]]; then
            eval "${LS_CMD}"
        else
            echo "Directory contains ${item_count} items. Skipping automatic listing."
            echo "Use 'ls' to list contents."
        fi
    fi
}

# Create directory and navigate to it
mkcd() {
    if [ -z "$1" ]; then
        echo "Usage: mkcd <directory_name>"
        return 1
    fi

    mkdir -p "$1" || {
        echo "Error: Failed to create directory '$1'"
        return 1
    }

    cd_with_history "$1"
}

# List all bookmarks
bookmark_list() {
    if [[ -f "${BOOKMARK_FILE}" ]]; then
        echo "Available bookmarks:"
        # shellcheck disable=SC2002
        cat "${BOOKMARK_FILE}" | sed 's/:/\t/' | column -t
    else
        echo "No bookmarks found."
    fi
}

# Create a bookmark
bookmark() {
    if [ -z "$1" ]; then
        # Show usage and call the bookmark_list function
        echo "Usage: bookmark <bookmark_name> [directory]"
        bookmark_list
        return 0
    fi

    local name="$1"
    local dir="${2:-$PWD}"

    # Validate bookmark name (no spaces or special characters)
    if [[ ! "${name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: Bookmark name can only contain letters, numbers, underscores and hyphens"
        return 1
    fi

    # Validate directory
    if [[ ! -d "${dir}" ]]; then
        echo "Error: Cannot bookmark non-existent directory '${dir}'"
        return 1
    fi

    if [[ ! -r "${dir}" ]] || [[ ! -x "${dir}" ]]; then
        echo "Error: Cannot bookmark inaccessible directory '${dir}'"
        return 1
    fi

    # Create bookmark file if it doesn't exist
    touch "${BOOKMARK_FILE}" 2>/dev/null || {
        echo "Error: Could not create bookmark file"
        return 1
    }

    # Check if bookmark already exists
    if grep -q "^${name}:" "${BOOKMARK_FILE}"; then
        echo "Bookmark '${name}' already exists. Use 'bookmark_update' to update it."
        return 1
    fi

    # Add bookmark
    safe_write_file "${BOOKMARK_FILE}" "${name}:${dir}" "a" || {
        echo "Error: Failed to write bookmark"
        return 1
    }

    echo "Bookmark '${name}' created for directory '${dir}'"
}

# Update existing bookmark
bookmark_update() {
    if [[ -z "$1" ]]; then
        echo "Usage: bookmark_update <bookmark_name> [directory]"
        return 1
    fi

    local name="$1"
    local dir="${2:-$PWD}"

    # Validate bookmark name
    if [[ ! "${name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: Bookmark name can only contain letters, numbers, underscores and hyphens"
        return 1
    fi

    # Validate directory
    if [[ ! -d "${dir}" ]]; then
        echo "Error: Cannot bookmark non-existent directory '${dir}'"
        return 1
    fi

    if [[ ! -r "${dir}" ]] || [[ ! -x "${dir}" ]]; then
        echo "Error: Cannot bookmark inaccessible directory '${dir}'"
        return 1
    fi

    # Check if bookmark file exists
    if [[ ! -f "${BOOKMARK_FILE}" ]]; then
        echo "No bookmarks found."
        return 1
    fi

    # Check if bookmark exists
    if ! grep -q "^${name}:" "${BOOKMARK_FILE}"; then
        echo "Bookmark '${name}' does not exist. Use 'bookmark' to create it."
        return 1
    fi

    # Update bookmark
    if [[ "${DOTFILES_OS}" == "Darwin"* ]]; then
        # macOS version of sed requires a backup extension
        sed -i '' "s|^${name}:.*$|${name}:${dir}|" "${BOOKMARK_FILE}"
    else
        # Linux version can use -i without an extension
        sed -i "s|^${name}:.*$|${name}:${dir}|" "${BOOKMARK_FILE}"
    fi

    echo "Bookmark '${name}' updated to '${dir}'"
}

# Remove bookmark
bookmark_remove() {
    if [ -z "$1" ]; then
        echo "Usage: bookmark_remove <bookmark_name>"
        return 1
    fi

    local name="$1"

    # Check if bookmark file exists
    if [[ ! -f "${BOOKMARK_FILE}" ]]; then
        echo "No bookmarks found."
        return 1
    fi

    # Check if bookmark exists
    if ! grep -q "^${name}:" "${BOOKMARK_FILE}"; then
        echo "Bookmark '${name}' does not exist."
        return 1
    fi

    # Remove bookmark
    if [[ "${DOTFILES_OS}" == "Darwin"* ]]; then
        # macOS version of sed
        sed -i '' "/^${name}:/d" "${BOOKMARK_FILE}"
    else
        # Linux version
        sed -i "/^${name}:/d" "${BOOKMARK_FILE}"
    fi

    echo "Bookmark '${name}' removed"
}

# Go to bookmark
goto() {
    if [ -z "$1" ]; then
        echo "Usage: goto <bookmark_name>"
        # Just show usage without listing bookmarks to avoid platform-specific issues
        echo "Use 'bml' or 'bookmark_list' to see available bookmarks"
        return 1
    fi

    local name="$1"

    # Check if bookmark file exists
    if [[ ! -f "${BOOKMARK_FILE}" ]]; then
        echo "No bookmarks found."
        return 1
    fi

    # Get bookmark path
    local dir
    dir=$(grep "^${name}:" "${BOOKMARK_FILE}" | cut -d':' -f2)

    if [[ -z "${dir}" ]]; then
        echo "Bookmark '${name}' not found."
        return 1
    fi

    # Validate directory before navigation
    if [[ ! -d "${dir}" ]]; then
        echo "Error: Bookmarked directory '${dir}' no longer exists"
        echo "Please update or remove this bookmark."
        return 1
    fi

    if [[ ! -r "${dir}" ]] || [[ ! -x "${dir}" ]]; then
        echo "Error: Bookmarked directory '${dir}' is inaccessible"
        echo "Please update or remove this bookmark."
        return 1
    fi

    # Navigate to the bookmark
    cd_with_history "${dir}"
}

# Directory history navigation
dirhistory() {
    if [[ ${#RECENT_DIRS[@]} -eq 0 ]]; then
        echo "No directory history found."
        return 0
    fi

    echo "Recent directories:"
    for i in "${!RECENT_DIRS[@]}"; do
        # Highlight current directory
        if [[ "${RECENT_DIRS[$i]}" == "${PWD}" ]]; then
            echo "$i: ${RECENT_DIRS[$i]} (current)"
        else
            echo "$i: ${RECENT_DIRS[$i]}"
        fi
    done

    echo ""
    read -p "Enter number to navigate (or any other key to cancel): " num

    if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -lt ${#RECENT_DIRS[@]} ]]; then
        cd_with_history "${RECENT_DIRS[$num]}"
    fi
}

# Find and navigate to project root (git, npm, etc.)
proj() {
    local dir="${PWD}"
    local markers=(".git" "package.json" "Makefile" "CMakeLists.txt" "pom.xml" "build.gradle" "requirements.txt" "setup.py" "Cargo.toml")

    while [[ "${dir}" != "/" ]]; do
        for marker in "${markers[@]}"; do
            if [[ -d "${dir}/${marker}" ]] || [[ -f "${dir}/${marker}" ]]; then
                cd_with_history "${dir}"
                echo "Found project root: ${dir} (marker: ${marker})"
                return 0
            fi
        done
        dir=$(dirname "${dir}")
    done

    echo "No project root found."
    return 1
}

# Restore last working directory
lwd() {
    if [[ -f "${LAST_DIR_FILE}" ]]; then
        local last_dir
        last_dir=$(cat "${LAST_DIR_FILE}")

        if [[ ! -d "${last_dir}" ]] || [[ ! -r "${last_dir}" ]] || [[ ! -x "${last_dir}" ]]; then
            echo "Last working directory no longer exists or is inaccessible."
            return 1
        fi

        cd_with_history "${last_dir}"
    else
        echo "No last working directory saved."
        return 1
    fi
}

#-----------------------------------------------------------------------------
# Parent Directory Shortcuts
#-----------------------------------------------------------------------------
alias -- -='cd -'                            # Go to the previous directory
alias ..='cd_with_history ..'                # Go up one level
alias ...='cd_with_history ../..'            # Go up two levels
alias ....='cd_with_history ../../..'        # Go up three levels
alias .....='cd_with_history ../../../..'    # Go up four levels

#-----------------------------------------------------------------------------
# Home and Frequently Used Directories
#-----------------------------------------------------------------------------
# Only create aliases for directories that exist
[[ -d "${APP_DIR}" ]] && alias app='cd_with_history "${APP_DIR}"'     # Applications
[[ -d "${CODE_DIR}" ]] && alias cod='cd_with_history "${CODE_DIR}"'   # Code
[[ -d "${DESK_DIR}" ]] && alias dsk='cd_with_history "${DESK_DIR}"'   # Desktop
[[ -d "${DOCS_DIR}" ]] && alias doc='cd_with_history "${DOCS_DIR}"'   # Documents
[[ -d "${DOTF_DIR}" ]] && alias dot='cd_with_history "${DOTF_DIR}"'   # Dotfiles
[[ -d "${DOWN_DIR}" ]] && alias dwn='cd_with_history "${DOWN_DIR}"'   # Downloads
[[ -d "${DOWN_DIR}" ]] && alias hom='cd_with_history "${HOME_DIR}"'   # Home Directory
[[ -d "${MUSIC_DIR}" ]] && alias mus='cd_with_history "${MUSIC_DIR}"' # Music
[[ -d "${PICS_DIR}" ]] && alias pic='cd_with_history "${PICS_DIR}"'   # Pictures
[[ -d "${VIDS_DIR}" ]] && alias vid='cd_with_history "${VIDS_DIR}"'   # Videos

#-----------------------------------------------------------------------------
# System Directories
#-----------------------------------------------------------------------------
[[ -d "/etc" ]] && alias etc="cd_with_history /etc"     # System configuration
[[ -d "/var" ]] && alias var="cd_with_history /var"     # Variable data
[[ -d "/tmp" ]] && alias tmp="cd_with_history /tmp"     # Temporary files
[[ -d "/usr" ]] && alias usr="cd_with_history /usr"     # User programs

#-----------------------------------------------------------------------------
# Directory Stack Management
#-----------------------------------------------------------------------------
alias dirs='dirs -v'                          # List directory stack with indices
alias pd='pushd'                              # Push directory to stack
alias popd='popd && eval "${LS_CMD}"'         # Pop directory from stack and list contents

#-----------------------------------------------------------------------------
# Consistent Shorthand Aliases
#-----------------------------------------------------------------------------
alias cd='cd_with_history'                    # Override default cd command
alias mcd='mkcd'                              # Create and enter directory

# Bookmark management
alias bm='bookmark'                           # Create bookmark
alias bmu='bookmark_update'                   # Update bookmark
alias bmr='bookmark_remove'                   # Remove bookmark
alias bml='bookmark_list'                     # List bookmarks (fixed from 'bookmark' to 'bookmark_list')
alias bmg='goto'                              # Go to bookmark

# Navigation shortcuts
alias dh='dirhistory'                         # Show directory history
alias pr='proj'                               # Navigate to project root
alias ld='lwd'                                # Return to last directory

#-----------------------------------------------------------------------------
# Add completion for custom commands
#-----------------------------------------------------------------------------
# Helper to list all bookmark names
_get_bookmarks() {
    if [[ -f "${BOOKMARK_FILE}" ]]; then
        cut -d':' -f1 "${BOOKMARK_FILE}"
    fi
}

# Completion for bookmarks
_bookmark_complete() {
    local curr_arg;
    curr_arg=${COMP_WORDS[COMP_CWORD]}

    if [[ $COMP_CWORD -eq 1 ]]; then
        if type mapfile &>/dev/null; then
            mapfile -t COMPREPLY < <(compgen -W "$(_get_bookmarks)" -- "$curr_arg")
        else
            # Fallback for older bash versions
            # shellcheck disable=SC2207
            COMPREPLY=( $(compgen -W "$(_get_bookmarks)" -- "$curr_arg") )
        fi
    fi
}

# Set up completions
if type complete &>/dev/null; then
    complete -F _bookmark_complete goto
    complete -F _bookmark_complete bookmark_update
    complete -F _bookmark_complete bookmark_remove
    complete -F _bookmark_complete bmg
    complete -F _bookmark_complete bmu
    complete -F _bookmark_complete bmr
fi

#-----------------------------------------------------------------------------
# Initialize last working directory
#-----------------------------------------------------------------------------
if [[ "${RESTORE_LAST_DIR:-false}" == "true" ]]; then
    # Only run when the shell starts, not when the script is sourced again
    if [[ -z "${DOTFILES_INIT_DONE}" ]]; then
        lwd 2>/dev/null
        export DOTFILES_INIT_DONE=1
    fi
fi

#-----------------------------------------------------------------------------
# Help and Documentation
#-----------------------------------------------------------------------------
# Display help information
cd_aliases_help() {
    echo "╭─────────────────────────────────────────────────────────────╮"
    echo "│  ENHANCED DIRECTORY NAVIGATION v${DOTFILES_VERSION}                     │"
    echo "╰─────────────────────────────────────────────────────────────╯"
    echo ""
    echo "PRIMARY NAVIGATION COMMANDS:"
    echo "  cd [dir]              Change to directory with history tracking"
    echo "  mkcd, mk <dir>        Create and enter directory"
    echo "  proj, pr              Navigate to project root (git, npm, etc.)"
    echo "  lwd, ld               Return to last working directory"
    echo ""
    echo "BOOKMARK SYSTEM:"
    echo "  bookmark, bm [name] [dir]      List or create bookmarks"
    echo "  bookmark_update, bmu <n> [dir] Update existing bookmark"
    echo "  bookmark_remove, bmr <n>       Remove a bookmark"
    echo "  goto, bmg <n>                  Go to bookmarked directory"
    echo "  bookmark_list, bml             List all bookmarks"
    echo ""
    echo "HISTORY AND STACK:"
    echo "  dirhistory, dh              Show and navigate to recent directories"
    echo "  dirs                        List directory stack with indices"
    echo "  pd <dir>                    Push directory to stack"
    echo "  popd                        Pop directory from stack"
    echo ""
    echo "DIRECTORY SHORTCUTS:"
    echo "  ..    → Up one level        ...   → Up two levels"
    echo "  ....  → Up three levels     ..... → Up four levels"
    echo "  -     → Previous directory"
    echo ""
    echo "COMMON LOCATIONS:"
    echo "  hom → Home          app → Applications   cod → Code"
    echo "  dsk → Desktop       doc → Documents      dot → Dotfiles"
    echo "  dwn → Downloads     mus → Music          pic → Pictures"
    echo "  vid → Videos        etc → /etc           var → /var"
    echo "  tmp → /tmp          usr → /usr"
    echo ""
    echo "CONFIGURATION OPTIONS:"
    echo "  To customize, add these variables to your .bashrc or .zshrc:"
    echo "  SHOW_HIDDEN_FILES=true|false     # Show hidden files in listings"
    echo "  ENABLE_COLOR_OUTPUT=true|false   # Enable colorized output"
    echo "  AUTO_LIST_AFTER_CD=true|false    # List directory after navigation"
    echo "  LARGE_DIR_THRESHOLD=1000         # Skip listing for large dirs"
    echo "  MAX_RECENT_DIRS=10               # Number of dirs in history"
    echo "  RESTORE_LAST_DIR=true|false      # Restore last dir on shell start"
    echo ""
    if [[ "${DOTFILES_OS}" == "Darwin"* ]]; then
        echo "NOTE: Directory grouping is not supported on macOS."
        echo ""
    fi
    echo "For updates and more information, visit:"
    echo "  https://github.com/sebastienrousseau/dotfiles"
}

# Version information
cd_aliases_version() {
    echo "Enhanced Directory Navigation v${DOTFILES_VERSION}"
    echo "Last updated: ${DOTFILES_LAST_UPDATED}"
    echo "OS detected: ${DOTFILES_OS}"
}

# Help aliases
alias cdhelp='cd_aliases_help'
alias cdversion='cd_aliases_version'
# shellcheck shell=bash
# 🆁🆂🆈🅽🅲 🅰🅻🅸🅰🆂🅴🆂

if command -v 'rsync' >/dev/null; then

  # Rsync with verbose and progress.
  alias rs='rsync -avz'

  # Rsync with verbose and progress.
  alias rsync='rs'
fi
# shellcheck shell=bash
# Docker Aliases
#
# Sections:
# 1. Core & Containers
# 2. Images
# 3. Volumes & Networks
# 4. System & Context
# 5. Compose
# 6. Swarm

if command -v 'docker' &>/dev/null; then
  
  # --- Core ---
  alias dk='docker'
  alias dkv='docker version'
  alias dki='docker info'
  alias dkl='docker login'
  alias dklo='docker logout'

  # --- Containers ---
  alias dkps='docker ps'
  alias dkpsa='docker ps -a'
  alias dkr='docker run'
  alias dkri='docker run -it'
  alias dkrd='docker run -d'
  alias dks='docker start'
  alias dkst='docker stop'
  alias dkrs='docker restart'
  alias dkp='docker pause'
  alias dkup='docker unpause'
  alias dkrm='docker rm'
  alias dkrma='docker rm $(docker ps -aq)'
  alias dkrmf='docker rm -f'
  
  alias dkin='docker inspect'
  alias dklg='docker logs'
  alias dklf='docker logs -f'
  alias dkt='docker top'
  alias dkst='docker stats'
  alias dkdf='docker diff'
  alias dkpl='docker pull'
  alias dkex='docker exec'
  alias dkeit='docker exec -it'
  
  alias dkcp='docker cp'
  alias dkw='docker wait'
  alias dkk='docker kill'
  
  # --- Images ---
  alias dkim='docker images' # renamed from dki to avoid conflict
  alias dkia='docker images -a'
  alias dkb='docker build'
  alias dkbt='docker build -t'
  alias dkpu='docker push'
  alias dkrmi='docker rmi'
  alias dkh='docker history'
  alias dksv='docker save'
  alias dkld='docker load'
  alias dkprune='docker system prune'
  alias dkprunea='docker system prune -a'
  alias dkrmi_dangling='docker rmi $(docker images -f "dangling=true" -q)'

  # --- Volumes ---
  alias dkvl='docker volume' # renamed from dkv to avoid conflict
  alias dkvls='docker volume ls'
  alias dkvc='docker volume create'
  alias dkvi='docker volume inspect'
  alias dkvrm='docker volume rm'
  alias dkvp='docker volume prune'

  # --- Networks ---
  alias dkn='docker network'
  alias dknls='docker network ls'
  alias dknc='docker network create'
  alias dkni='docker network inspect'
  alias dknrm='docker network rm'
  alias dknp='docker network prune'
  alias dkncon='docker network connect'
  alias dkndis='docker network disconnect'

  # --- System ---
  alias dksys='docker system' # renamed from dks to avoid conflict
  alias dksdf='docker system df'
  alias dksev='docker system events'
  alias dksi='docker system info'
  alias dksp='docker system prune'
  alias dkspa='docker system prune -a'
  alias dkcon='docker context'
fi

# --- Docker Compose ---
if command -v 'docker-compose' &>/dev/null; then
  alias dc='docker-compose'
  alias dcu='docker-compose up'
  alias dcud='docker-compose up -d'
  alias dcd='docker-compose down'
  alias dcdv='docker-compose down -v'
  alias dcr='docker-compose restart'
  alias dcs='docker-compose stop'
  alias dcsta='docker-compose start'
  alias dcps='docker-compose ps'
  alias dcl='docker-compose logs'
  alias dclf='docker-compose logs -f'
  alias dcex='docker-compose exec'
  alias dcb='docker-compose build'
  alias dcpull='docker-compose pull'
  alias dcpush='docker-compose push'
  alias dcrm='docker-compose rm'
  alias dcrun='docker-compose run'
  alias dci='docker-compose images'
  alias dck='docker-compose kill'
  alias dccfg='docker-compose config'
  alias dctop='docker-compose top'
fi

# --- Docker Swarm ---
if command -v 'docker' &>/dev/null && docker swarm &>/dev/null; then
  alias dksw='docker swarm'
  alias dkswi='docker swarm init'
  alias dkswj='docker swarm join'
  alias dkswl='docker swarm leave'
  alias dkswu='docker swarm update'
  
  alias dksrv='docker service'
  alias dksrvls='docker service ls'
  alias dksrvc='docker service create'
  alias dksrvi='docker service inspect'
  alias dksrvps='docker service ps'
  alias dksrvl='docker service logs'
  alias dksrvu='docker service update'
  alias dksrvrm='docker service rm'
  
  alias dkstk='docker stack'
  alias dkstkls='docker stack ls'
  alias dkstkd='docker stack deploy'
  alias dkstkrm='docker stack rm'
  alias dkstkps='docker stack ps'
  
  alias dknode='docker node' # renamed from dkn to avoid conflict
  alias dknls='docker node ls'
  alias dkni='docker node inspect'
fi
# shellcheck shell=bash
# Go Aliases

if command -v go &>/dev/null; then
  alias go='go'
  alias gor='go run'
  alias gob='go build'
  alias got='go test'
  alias gota='go test ./...'
  alias gocv='go coverage'
  alias gofmt='go fmt'
  alias govet='go vet'
  alias gomod='go mod'
  alias gomt='go mod tidy'
  alias gomv='go mod vendor'
  alias goget='go get'
  alias goinstall='go install'
fi
#!/usr/bin/env bash
# Font Management Aliases

# Update font cache
alias update-fonts='if command -v fc-cache >/dev/null; then fc-cache -fv; else echo "fc-cache not found (is fontconfig installed?)"; fi'

# List installed fonts (if fc-list available)
alias list-fonts='fc-list : family | sort | uniq'
# shellcheck shell=bash
# 🅼🅰🅺🅴 🅰🅻🅸🅰🆂🅴🆂

# mk - make
alias mk='make'

# mkc - make clean
alias mkc='make clean'

# mkd - make doc
alias mkd='make doc'

# mkf - make format
alias mkf='make format'

# mkh - make help
alias mkh='make help'

# mki - make install
alias mki='make install'

# mka - make all
alias mka='make all'

# mkr - make run
alias mkr='make run'

# mkt - make test
alias mkt='make test'
# shellcheck shell=bash
if command -v 'cargo' >/dev/null; then
    # Basic Commands
    alias cg='cargo'                             # Cargo shortcut
    alias cgn='cg new'                           # Create new binary project
    alias cgni='cg new --lib'                    # Create new library project
    alias cginit='cg init'                       # Initialize project in current directory

    # Build and Run
    alias cgb='cg build'                         # Build debug
    alias cgbr='cg build --release'              # Build release
    alias cgr='cg run'                           # Run debug
    alias cgrr='cg run --release'                # Run release
    alias cgw='cg watch'                         # Watch and rebuild

    # Testing and Benchmarking
    alias cgt='cg test'                          # Run tests
    alias cgtr='cg test --release'               # Run tests in release mode
    alias cgbh='cg bench'                        # Run benchmarks
    alias cgta='cg test --all'                   # Test all targets
    alias cgtt='cg test -- --test-threads=1'     # Single threaded tests

    # Code Quality
    alias cgc='cg check'                         # Check compilation
    alias cgcl='cg clean'                        # Clean build artifacts
    alias cgcy='cg clippy'                       # Run clippy lints
    alias cgf='cg fmt'                           # Format code
    alias cgfa='cg fmt --all'                    # Format all code
    alias cgfx='cg fix'                          # Auto-fix code issues
    alias cgaud='cg audit'                       # Security vulnerabilities check

    # Documentation
    alias cgd='cg doc --open'                    # Build and open documentation
    alias cgdr='cg doc --release'                # Build release documentation
    alias cgdo='cg doc --document-private-items' # Document private items

    # Dependencies
    alias cga='cg add'                           # Add dependency
    alias cgad='cg add --dev'                    # Add dev dependency
    alias cgu='cg update'                        # Update dependencies
    alias cgo='cg outdated'                      # Check outdated dependencies
    alias cgv='cg vendor'                        # Vendor dependencies
    alias cgtree='cg tree'                       # Display dependency tree

    # Cross Compilation
    alias cgx='cg zigbuild'                      # Build using Zig
    alias cgxw='cg cross'                        # Cross compilation
    alias cgxt='cg target'                       # Target specific platform

    # Analysis and Profiling
    alias cgfl='cg flamegraph'                   # Generate flamegraph
    alias cgbl='cg bloat'                        # Binary size analysis
    alias cgl='cg llvm-cov'                      # Code coverage
    alias cgm='cg modules'                       # Module structure
    alias cgex='cg expand'                       # Expand macros

    # Package Management
    alias cgi='cg install'                       # Install binary
    alias cgun='cg uninstall'                    # Uninstall binary
    alias cgp='cg publish'                       # Publish to crates.io
    alias cgs='cg search'                        # Search crates.io
    alias cgcp='cg package'                      # Create release package

    # Advanced Build
    alias cgba='cg build --all-targets'          # Build all targets
    alias cgbt='cg build --all-features'         # Build with all features
    alias cgbp='cg build --release --profile'    # Build with specific profile

    # Project Templates
    alias cgnb='cg generate --bin'               # New binary from template
    alias cgnl='cg generate --lib'               # New library from template
    alias cgnt='cg generate'                     # New from custom template
fi

# 🆁🆄🆂🆃🆄🅿 🅰🅻🅸🅰🆂🅴🆂
if command -v 'rustup' >/dev/null; then
    # Updates and Installation
    alias ru='rustup update'                     # Update all toolchains
    alias rus='rustup update stable'             # Update stable toolchain
    alias run='rustup update nightly'            # Update nightly toolchain
    alias rti='rustup toolchain install'         # Install specific toolchain

    # Components Management
    alias rca='rustup component add'             # Add component
    alias rcl='rustup component list'            # List components
    alias rcr='rustup component remove'          # Remove component

    # Toolchain Management
    alias rtl='rustup toolchain list'            # List installed toolchains
    alias rtu='rustup toolchain uninstall'       # Uninstall toolchain
    alias rde='rustup default'                   # Set default toolchain

    # Target Management
    alias rtaa='rustup target add'               # Add compilation target
    alias rtal='rustup target list'              # List available targets
    alias rtar='rustup target remove'            # Remove compilation target

    # Environment Running
    alias rns='rustup run stable'                # Run command with stable
    alias rnn='rustup run nightly'               # Run command with nightly

    # Documentation and Help
    alias rdo='rustup doc --open'                # Open Rust documentation

    # Override Management
    alias rpr='rustup override set'              # Set directory toolchain
    alias rpl='rustup override list'             # List directory overrides
    alias rpn='rustup override none'             # Remove directory override

    # Toolchain Information
    alias rws='rustup which rustc'               # Show active rustc path
    alias rsh='rustup show'                      # Show toolchain info
fi
# shellcheck shell=bash
# Copyright (c) 2015-2025. All rights reserved
# Description: Script containing aliases to open configuration files in default
# editor
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Set default text editor
EDITOR="${EDITOR:-vi}"

# Apache aliases
# ------------------------------------------------------------------------------

# Open Apache configuration file in default text editor
alias edit_apache_config='${EDITOR} /etc/apache2/apache2.conf'

# Bash aliases
# ------------------------------------------------------------------------------

# Open Bash configuration file in default text editor
alias edit_bashrc='${EDITOR} $HOME/.bashrc'

# Open Bash profile in default text editor
alias edit_bash_profile='${EDITOR} $HOME/.bash_profile'

# Docker aliases
# ------------------------------------------------------------------------------

# Open Docker Compose file in default text editor
alias edit_docker_compose='${EDITOR} docker-compose.yml'

# General aliases
# ------------------------------------------------------------------------------

# Open current directory in default text editor
alias edit_current_directory='${EDITOR} .'

# Git aliases
# ------------------------------------------------------------------------------

# Open Git configuration file in default text editor
alias edit_git_config='${EDITOR} $HOME/.gitconfig'

# Open Git ignore file in default text editor
alias edit_git_ignore='${EDITOR} $HOME/.gitignore'

# System config aliases
# ------------------------------------------------------------------------------

# Open hosts file in default text editor
alias edit_hosts='${EDITOR} /etc/hosts'

# Open Nginx configuration file in default text editor
alias edit_nginx_config='${EDITOR} /etc/nginx/nginx.conf'

# Open SSH configuration file in default text editor
alias edit_ssh_config='${EDITOR} $HOME/.ssh/config'

# Open Zsh configuration file in default text editor
alias edit_zshrc='${EDITOR} $HOME/.zshrc'

# Open Zsh profile in default text editor
alias edit_zsh_profile='${EDITOR} $HOME/.zsh_profile'
# shellcheck shell=bash
# Version: 0.2.472
# Website: https://dotfiles.io

# 🅶🅲🅻🅾🆄🅳 🅰🅻🅸🅰🆂🅴🆂 - Google Cloud aliases.
if command -v gcloud &>/dev/null; then
  # Sections:
  #
  #      1.0 Google Cloud Aliases.
  #      1.1 Aliases to get going with the gcloud command-line tool.
  #      1.2 Aliases to make the Cloud SDK your own; personalize your
  #          configuration with properties.
  #      1.3 Aliases to grant and revoke authorization to Cloud SDK.
  #      1.4 Aliases to configuring Cloud Identity & Access Management
  #          (IAM) preferences and service accounts.
  #      1.5 Aliases to manage project access policies.
  #      1.6 Aliases to manage containerized applications on Kubernetes.
  #      1.7 Aliases to create, run, and manage VMs on Google
  #          infrastructure.
  #      1.8 Aliases to build highly scalable applications on a fully
  #          managed serverless platform.
  #      1.9 Aliases to commands that might come in handy.
  #      1.10 Additional Google Cloud Aliases.

  ##  ------------------------------------------------------------------
  ##  1.0 Google Cloud Aliases
  ##  ------------------------------------------------------------------
  ##  ------------------------------------------------------------------
  ##  1.1 Aliases to get going with the gcloud command-line tool.
  ##  ------------------------------------------------------------------

  # Install specific components.
  alias gcci='gcloud components install'

  # Set a default Google Cloud project to work on.
  alias gccsp='gcloud config set project'

  # Update your Cloud SDK to the latest version.
  alias gccu='gcloud components update'

  # Initialize, authorize, and configure the gcloud tool.
  alias gci='gcloud init'

  # Display current gcloud tool environment details.
  alias gcinf='gcloud info'

  # Display version and installed components.
  alias gcv='gcloud version'

  ##  ------------------------------------------------------------------
  ##  1.2 Aliases to make the Cloud SDK your own; personalize your
  ##      configuration with properties.
  ##  ------------------------------------------------------------------

  # Switch to an existing named configuration.
  alias gccca='gcloud config configurations activate'

  # Create a new named configuration.
  alias gcccc='gcloud config configurations create'

  # Display a list of all available configurations.
  alias gcccl='gcloud config configurations list'

  # Fetch value of a Cloud SDK property.
  alias gccgv='gcloud config get-value'

  # Display all the properties for the current configuration.
  alias gccl='gcloud config list'

  # Define a property (like compute/zone) for the current configuration.
  alias gccs='gcloud config set'

  ##  ------------------------------------------------------------------
  ##  1.3 Aliases to grant and revoke authorization to Cloud SDK
  ##  ------------------------------------------------------------------

  # Like gcloud auth login but with service account credentials.
  alias gcaasa='gcloud auth activate-service-account'

  # Register the gcloud tool as a Docker credential helper.
  alias gcacd='gcloud auth configure-docker'

  # List all credentialed accounts.
  alias gcal='gcloud auth list'

  # Authorize Google Cloud access for the gcloud tool with Google user
  # credentials and set current account as active.
  # alias gcal='gcloud auth login' # Duplicate key gcal defined above

  # Display the current account's access token.
  alias gcapat='gcloud auth print-access-token'

  # Remove access credentials for an account.
  alias gcar='gcloud auth revoke'

  ##  ------------------------------------------------------------------
  ##  1.4 Aliases to configuring Cloud Identity & Access Management
  ##      (IAM) preferences and service accounts.
  ##  ------------------------------------------------------------------

  # List a service account's keys.
  alias gciamk='gcloud iam service-accounts keys list'

  # List IAM grantable roles for a resource.
  alias gciaml='gcloud iam list-grantable-roles'

  # Add an IAM policy binding to a service account.
  alias gciamp='gcloud iam service-accounts add-iam-policy-binding'

  # Create a custom role for a project or org.
  alias gciamr='gcloud iam roles create'

  # Replace existing IAM policy binding.
  alias gciams='gcloud iam service-accounts set-iam-policy'

  # Create a service account for a project.
  alias gciamv='gcloud iam service-accounts create'

  ##  ------------------------------------------------------------------
  ##  1.5 Aliases to manage project access policies
  ##  ------------------------------------------------------------------

  # Add an IAM policy binding to a specified project.
  alias gcpa='gcloud projects add-iam-policy-binding'

  # Display metadata for a project (including its ID).
  alias gcpd='gcloud projects describe'

  ## -------------------------------------------------------------------
  ## 1.6 Aliases to manage containerized applications on Kubernetes
  ## -------------------------------------------------------------------

  # Create a cluster to run GKE containers.
  alias gcccc='gcloud container clusters create'

  # Update kubeconfig to get kubectl to use a GKE cluster.
  alias gcccg='gcloud container clusters get-credentials'

  # List clusters for running GKE containers.
  alias gcccl='gcloud container clusters list'

  # List tag and digest metadata for a container image.
  alias gccil='gcloud container images list-tags'

  ## -------------------------------------------------------------------
  ## 1.7 Aliases to create, run, and manage VMs on
  ##     Google infrastructure.
  ## -------------------------------------------------------------------

  # Copy files
  alias gcpc='gcloud compute copy-files'

  # Stop instance
  alias gcpdown='gcloud compute instances stop'

  # Create snapshot of persistent disks.
  alias gcpds='gcloud compute disks snapshot'

  # Display a VM instance's details.
  alias gcpid='gcloud compute instances describe'

  # List all VM instances in a project.
  alias gcpil='gcloud compute instances list'

  # Delete instance
  alias gcprm='gcloud compute instances delete'

  # Delete a snapshot.
  alias gcpsk='gcloud compute snapshots delete'

  # Connect to a VM instance by using SSH.
  alias gcpssh='gcloud compute ssh'

  # Start instance.
  alias gcpup='gcloud compute instances start'

  # List Compute Engine zones.
  alias gcpzl='gcloud compute zones list'

  ## -------------------------------------------------------------------
  ## 1.8 Aliases to build highly scalable applications on a fully
  ##     managed serverless platform.
  ## -------------------------------------------------------------------

  # Open the current app in a web browser.
  alias gcapb='gcloud app browse'

  # Create an App Engine app within your current project.
  alias gcapc='gcloud app create'

  # Deploy your app's code and configuration to the App Engine server.
  alias gcapd='gcloud app deploy'

  # Display the latest App Engine app logs.
  alias gcapl='gcloud app logs read'

  # List all versions of all services deployed to the App Engine server.
  alias gcapv='gcloud app versions list'

  ## -------------------------------------------------------------------
  ## 1.9 Aliases to commands that might come in handy
  ## -------------------------------------------------------------------

  # Decrypt ciphertext (to a plaintext file) using a Cloud Key
  # Management Service (Cloud KMS) key.
  alias gckmsd='gcloud kms decrypt'

  # List your project's logs.
  alias gclll='gcloud logging logs list'

  # Display info about a Cloud SQL instance backup.
  alias gcsqlb='gcloud sql backups describe'

  # Export data from a Cloud SQL instance to a SQL file.
  alias gcsqle='gcloud sql export sql'

  ## -------------------------------------------------------------------
  ## 1.10 Aliases to commands that might come in handy
  ## -------------------------------------------------------------------

  # Authenticate with Google Cloud.
  # alias gca='gcloud auth' # Conflicts with Git

  # Access to beta commands.
  # alias gcb='gcloud beta' # Conflicts with Git

  # Manage Google Cloud Build.
  alias gclb='gcloud builds'

  # Manage Compute Engine IP addresses.
  alias gcca='gcloud compute addresses'

  # Create a new virtual machine instance.
  alias gccc='gcloud compute instances create'

  # Connect to a virtual machine instance by using SSH.
  alias gcco='gcloud compute ssh'

  # Set default project to current directory name.
  alias gcd='gcloud config set project $(gcloud projects list --format="value(projectId)" --filter="name:${PWD##\*/}")'

  # Manage Google Cloud Datastore.
  alias gcdb='gcloud datastore'

  # Manage Google Cloud Dataproc.
  alias gcdp='gcloud dataproc'

  # Manage Google Cloud Endpoints.
  alias gce='gcloud endpoints'

  # Manage Google Cloud Eventarc.
  alias gcem='gcloud eventarc'

  # Manage Google Cloud Functions.
  alias gcf='gcloud functions'

  # Manage Google Cloud Compute Engine instances.
  alias gci='gcloud compute instances'

  # Manage Google Cloud Identity and Access Management.
  alias gcic='gcloud iam'

  # Manage Google Cloud IoT Core.
  alias gcir='gcloud iot'

  # List all configurations.
  alias gck='gcloud config configurations list'

  # Manage Google Cloud KMS.
  alias gcki='gcloud kms'

  # Manage Google Cloud Logging.
  alias gcla='gcloud logging'

  # Manage Google Cloud Monitoring.
  alias gcma='gcloud monitoring'

  # Manage Google Cloud Networks.
  alias gcn='gcloud networks'

  # Manage Google Cloud projects.
  alias gcp='gcloud projects'

  # Delete a Google Cloud project.
  alias gcpd='gcloud projects delete'

  # Display details for a Compute Engine IP address.
  alias gcpha='gcloud compute addresses describe'

  # Manage Google Cloud Pub/Sub.
  alias gcps='gcloud pubsub'

  # Delete a container image from Google Container Registry
  alias gcr='gcloud container images delete'

  # Manage Google Cloud resources.
  alias gcrm='gcloud resource-manager'

  # Manage Google Cloud Run.
  alias gcro='gcloud run'

  # Manage Google Cloud Kubernetes Engine clusters.
  alias gcs='gcloud container clusters'

  # Set the account for the current configuration.
  alias gcsa='gcloud config set account'

  # Manage Google Cloud Source Repositories.
  alias gcsc='gcloud source'

  # Open the Google Cloud Console for the current project.
  alias gcso='gcloud organizations'

  # Manage Google Cloud SQL.
  alias gcsq='gcloud sql'

  # Manage Google Cloud Storage.
  alias gcss='gcloud storage'

  # Enable or disable Google Cloud services.
  alias gcst='gcloud services'

  # Manage Google Cloud Tasks.
  alias gct='gcloud tasks'

  # Manage Google Cloud App Engine.
  alias gcu='gcloud app'

fi
# shellcheck shell=bash
# 🆄🆄🅸🅳 🅰🅻🅸🅰🆂🅴🆂

# uuid: Generate a UUID and copy it to the clipboard.
if [[ "${OSTYPE}" == "darwin"* ]]; then
  if command -v 'uuidgen' >/dev/null; then
    # macOS
    alias uuid="uuidgen | tr -d '\n' | tr '[:upper:]' '[:lower:]' | pbcopy && pbpaste && echo"
  fi
elif [[ "${OSTYPE}" == "linux-gnu"* ]]; then
  # Linux
  alias uuid="uuid | tr '[:upper:]' '[:lower:]' | xsel -ib && xsel -ob && echo"
fi
# shellcheck shell=bash
# 🅶🅽🆄 🅲🅾🆁🅴🆄🆃🅸🅻🆂 🅰🅻🅸🅰🆂🅴🆂

if command -v 'gdate' >/dev/null; then

  # Strip directory and suffix from filenames.
  alias basename=basename

  # Copy files and directories.
  alias cp=cp

  # Strip non-directory suffix from filenames.
  alias dirname=dirname

  # Create links between files.
  alias ln=ln

  # Print the name of the link.
  alias loname=loname

  # List directory contents.
  alias ls=ls

  # Create directories.
  alias mkdir=mkdir

  # Make named pipes (FIFOs).
  alias mkfifo=mkfifo

  # Make block or character special files.
  alias mknod=mknod

  # Move or rename files or directories.
  alias mv=mv

  # Check file name validity and portability.
  alias pathchk=pathchk

  # Print working directory name.
  alias pwd=pwd

  # Print resolved symbolic links or canonical file names.
  alias readlink=readlink

  # Print the resolved physical path of the specified path.
  alias realpath=realpath

  # Remove files or directories.
  alias rm=rm

  # Remove empty directories.
  alias rmdir=rmdir

  # Remove files or directories.
  alias unlink=unlink

  ## File content manipulation utilities

  # Pattern scanning and processing language.
  alias awk=awk

  # Concatenate and display files.
  alias cat=cat

  # Split a file into context-determined pieces.
  alias csplit=csplit

  # Remove sections from each line of files.
  alias cut=cut

  # Compare files line by line.
  alias diff=diff

  # Wrap each input line to fit in specified width.
  alias fold=fold

  # Print lines matching a pattern.
  alias grep=grep

  # Output the first part of files.
  alias head=head

  # Number lines of files.
  alias nl=nl

  # Merge lines of files.
  alias paste=paste

  # Apply a diff file to an original.
  alias patch=patch

  # ptx: Produce a permuted index of file contents.
  alias ptx=ptx

  # sed: Stream editor for filtering and transforming text.
  alias sed=sed

  # sort: Sort lines of text files.
  alias sort=sort

  # split: Split a file into pieces.
  alias split=split

  # tail: Output the last part of files.
  alias tail=tail

  # tr: Translate or delete characters.
  alias tr=tr

  ## File checksum and encryption utilities

  # Print or check BLAKE2 message digests.
  alias b2sum=b2sum

  # Print CRC checksum and byte counts.
  alias cksum=cksum

  # Print or check SHA1 message digests.
  alias sha1sum=sha1sum

  # Print or check SHA224 message digests.
  alias sha224sum=sha224sum

  # Print or check SHA256 message digests.
  alias sha256sum=sha256sum

  # Print or check SHA384 message digests.
  alias sha384sum=sha384sum

  # Print or check SHA512 message digests.
  alias sha512sum=sha512sum

  ## Other file utilities

  # Print or convert base32 data.
  alias base32=base32

  # Encode or decode base64 data.
  alias base64=base64

  # Encode or decode base64, base32,
  alias basenc=basenc

fi
# shellcheck shell=bash
#
# Description:
#   Configuration file for Python development environment, including aliases,
#   environment variables, and utility functions for common Python tasks.
#
################################################################################

# Environment Variables
export PYTHONIOENCODING='UTF-8'           # Set UTF-8 encoding for Python I/O
export PYTHONUTF8=1                       # Enable UTF-8 mode for Python
export PYTHONDONTWRITEBYTECODE=1          # Prevent Python from writing .pyc files
export PYTHONUNBUFFERED=1                 # Force Python output to be unbuffered
export PYENV_VIRTUALENV_DISABLE_PROMPT=1   # Disable virtualenv prompt modification

# Frameworks and Applications
# uv (Modern Python Package Manager)
if command -v uv &>/dev/null; then
  alias uvp='uv pip'
  alias uvpi='uv pip install'
  alias uvv='uv venv'
  alias uvr='uv run'
fi

# Add Python 3.12 or the Homebrew Python to PATH
if command -v /opt/homebrew/bin/python3 >/dev/null; then
    export PATH="/opt/homebrew/bin:${PATH}"
elif command -v /Library/Frameworks/Python.framework/Versions/3.12/bin/python3 >/dev/null; then
    export PATH="/Library/Frameworks/Python.framework/Versions/3.12/bin:${PATH}"
fi

if command -v 'python3' >/dev/null; then
    # Python Version Management
    python() {
        command python3 "$@"
    }

    pip() {
        command pip3 "$@"
    }

    # Basic Python Commands
    alias py='python'                     # Quick Python access
    alias ipy='ipython'                   # Interactive Python shell
    alias pyv='python --version'          # Show Python version
    alias pydoc='python -m pydoc'         # Python documentation

    # Package Management
    alias pipi='pip install'              # Install packages
    alias pipl='pip list'                 # List installed packages
    alias pipup='pip install --upgrade'    # Upgrade packages
    alias pipun='pip uninstall -y'        # Uninstall packages
    alias pipf='pip freeze'               # Show frozen requirements
    alias pipr='pip install -r'           # Install from requirements
    alias pipout='pip freeze > requirements.txt'  # Save requirements

    # Development Tools
    alias pep8='autopep8'                 # Code formatting
    alias lint='pylint'                   # Code linting
    alias black='python -m black'         # Code formatting with black
    alias mypy='python -m mypy'           # Static type checking
    alias ruff='python -m ruff'           # Fast Python linter

    # Testing
    alias pytest='python -m pytest'        # Run tests
    alias pytestv='pytest -v'             # Verbose test output
    alias pytestc='pytest --cov'          # Test coverage
    alias unittest='python -m unittest'    # Run unittest

    # Virtual Environment Management
    alias venv='python -m venv'           # Create virtual environment
    alias mkvenv='python -m venv ./venv'  # Create venv in current directory
    alias venva='source ./venv/bin/activate'  # Activate venv
    alias deact='deactivate'              # Deactivate venv
    alias rmvenv='rm -rf ./venv'          # Remove venv

    # Cleanup
    alias rmpyc="find . -type f -name '*.pyc' -delete"  # Remove .pyc files
    alias rmpyo="find . -type f -name '*.pyo' -delete"  # Remove .pyo files
    alias rmpyall="find . -type f -name '*.py[cod]' -delete && find . -type d -name __pycache__ -delete"  # Remove all

    # Utility Functions
    python_speed() {
        if [ $# -eq 0 ]; then
            echo "Usage: python_speed 'Python code here'"
            return 1
        fi
        python -m timeit -s "$1"
    }

    python_profile() {
        if [ $# -eq 0 ]; then
            echo "Usage: python_profile script.py"
            return 1
        fi
        python -m cProfile "$1"
    }

    python_debug() {
        if [ $# -eq 0 ]; then
            echo "Usage: python_debug script.py"
            return 1
        fi
        python -m pdb "$1"
    }

    python_serve() {
        local port="${1:-8000}"
        python -m http.server "$port"
    }

    # Project Templates
    python_new_project() {
        if [ $# -eq 0 ]; then
            echo "Usage: python_new_project project_name"
            return 1
        fi
        local project_name="$1"
        mkdir -p "$project_name"/{src,tests,docs}
        touch "$project_name/README.md"
        touch "$project_name/requirements.txt"
        touch "$project_name/setup.py"
        touch "$project_name/src/__init__.py"
        touch "$project_name/tests/__init__.py"
        echo "Created new Python project structure in ./$project_name"
    }

    # Environment Information
    python_info() {
        echo "Python Version:"
        python --version
        echo -e "\nPip Version:"
        pip --version
        echo -e "\nVirtual Environment:"
        if [ -n "$VIRTUAL_ENV" ]; then
            echo "Active: $VIRTUAL_ENV"
        else
            echo "None active"
        fi
        echo -e "\nInstalled Packages:"
        pip list
    }
fi# shellcheck shell=bash
# Version: 0.2.472
# Website: https://dotfiles.io

# 🅴🅳🅸🆃🅾🆁 🅰🅻🅸🅰🆂🅴🆂

# Note: This script assumes editor.sh has already been sourced
# to set up EDITOR, VISUAL, and other editor environment variables.

# Common editor aliases that work with any editor
alias e='${EDITOR}'
alias edit='${EDITOR}'
alias editor='${EDITOR}'
alias mate='${EDITOR}'
alias n='${EDITOR}'
alias v='${EDITOR}'

# Editor-specific aliases based on the current EDITOR/VISUAL
if [[ -n "${EDITOR}" ]]; then
  case "${EDITOR}" in
    nvim|*/nvim)
      # Neovim aliases
      alias vi="nvim"
      alias vim="nvim"
      alias nvimrc='nvim "${HOME}/.config/nvim/init.lua"'
      alias nvimlua='nvim "${HOME}/.config/nvim/init.lua"'
      alias nvimconf='nvim "${HOME}/.config/nvim"'
      ;;
    code|*/code)
      # VS Code aliases
      alias vsc="code"
      alias vsca="code --add"
      alias vscd="code --diff"
      alias vscn="code --new-window"
      alias vscr="code --reuse-window"
      alias vscu="code --user-data-dir"
      alias vsced="code --extensions-dir"
      alias vscex="code --install-extension"
      alias vsclist="code --list-extensions"
      ;;
    nano|*/nano)
      # Nano aliases
      alias nanorc='nano "${HOME}/.nanorc"'
      # Enhanced nano with line numbers and smooth scrolling
      function nanoedit() { nano -l -S "$@"; }
      alias ne="nanoedit"
      ;;
    emacs|*/emacs)
      # Emacs aliases
      alias em="emacs"
      alias emacs-nw="emacs -nw"
      alias emacsc="emacsclient"
      alias emacsrc="emacs ~/.emacs"
      alias et="emacs -nw"  # Terminal mode
      ;;
    subl|*/subl)
      # Sublime Text aliases
      alias st="subl"
      alias stt="subl ."  # Open current directory
      alias stn="subl -n" # Open in new window
      ;;
    atom|*/atom)
      # Atom aliases
      alias a="atom"
      alias at="atom ."
      alias an="atom -n"
      ;;
  esac
fi

# Quick edit function to edit common configuration files
function editrc() {
  case "$1" in
    bash)     "${EDITOR}" "${HOME}/.bashrc" ;;
    zsh)      "${EDITOR}" "${HOME}/.zshrc" ;;
    vim)      "${EDITOR}" "${NVIM_INIT:-${HOME}/.config/nvim/init.lua}" ;;
    nvim)     "${EDITOR}" "${NVIM_INIT:-${HOME}/.config/nvim/init.lua}" ;;
    tmux)     "${EDITOR}" "${HOME}/.tmux.conf" ;;
    git)      "${EDITOR}" "${HOME}/.gitconfig" ;;
    ssh)      "${EDITOR}" "${HOME}/.ssh/config" ;;
    alias)    "${EDITOR}" "${HOME}/.dotfiles/aliases" ;;
    dotfiles) "${EDITOR}" "${HOME}/.dotfiles" ;;
    *)        echo "Usage: editrc [bash|zsh|vim|nvim|tmux|git|ssh|alias|dotfiles]" ;;
  esac
}
# shellcheck shell=bash
# Kubernetes Aliases

# Check if kubectl is installed
if command -v kubectl &>/dev/null; then
  alias k='kubectl'
  
  # Core
  alias kg='kubectl get'
  alias kgp='kubectl get pods'
  alias kga='kubectl get all'
  alias kd='kubectl describe'
  alias kdel='kubectl delete'
  alias kl='kubectl logs'
  alias kex='kubectl exec -it'
  
  # Context / Namespace
  alias kcx='kubectl config get-contexts'
  alias kuse='kubectl config use-context'
  alias kns='kubectl config set-context --current --namespace'
  
  # Apply / File
  alias kaf='kubectl apply -f'
  alias kdf='kubectl delete -f'
fi

# Helm
if command -v helm &>/dev/null; then
  # alias h='helm' # Reserved for history
  alias hi='helm install'
  alias hu='helm upgrade'
  alias hls='helm list'
  alias hrm='helm uninstall'
fi

# k9s
if command -v k9s &>/dev/null; then
  alias k9='k9s'
fi
