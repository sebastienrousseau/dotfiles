# shellcheck shell=bash
# CD Navigation - Configuration and Variables
[[ -n "${_CD_CONFIG_LOADED:-}" ]] && return 0
_CD_CONFIG_LOADED=1

# Script configuration and version
DOTFILES_VERSION="0.2.478"
DOTFILES_LAST_UPDATED="2025-03-12"

# OS Detection for cross-platform compatibility
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

# Configuration and customization options
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

# Frequently Used Directory Variables
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
