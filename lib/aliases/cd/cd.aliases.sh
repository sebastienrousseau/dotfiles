#!/usr/bin/env bash
################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: cd.aliases.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: This script provides enhanced functionality to quickly navigate directories.
# Website: https://dotfiles.io
# License: MIT
################################################################################

#-----------------------------------------------------------------------------
# Script configuration and version
#-----------------------------------------------------------------------------
DOTFILES_VERSION="0.2.470"
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
alias mk='mkcd'                               # Create and enter directory

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
