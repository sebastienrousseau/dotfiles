# shellcheck shell=bash
# CD Navigation - Configuration and Variables
[[ -n "${_CD_CONFIG_LOADED:-}" ]] && :
_CD_CONFIG_LOADED=1

# Script configuration and version (exported: used by other cd-*.aliases.sh modules)
export DOTFILES_VERSION="0.2.482"
export DOTFILES_LAST_UPDATED="2025-03-12"

# OS Detection for cross-platform compatibility
DOTFILES_OS="$(uname -s)"
case "${DOTFILES_OS}" in
  Darwin*)
    # macOS specific settings - no group directories option
    export LS_COLOR_OPT="-G"
    export LS_GROUP_DIRS=""
    export SED_INPLACE="sed -i ''"
    ;;
  Linux*)
    # Linux specific settings
    export LS_COLOR_OPT="--color=auto"
    export LS_GROUP_DIRS="--group-directories-first"
    export SED_INPLACE="sed -i"
    ;;
  *)
    # Default settings for other systems
    export LS_COLOR_OPT=""
    export LS_GROUP_DIRS=""
    export SED_INPLACE="sed -i"
    ;;
esac

# Configuration and customization options
# These variables can be overridden in your .bashrc or .zshrc
SHOW_HIDDEN_FILES=${SHOW_HIDDEN_FILES:-false}
ENABLE_COLOR_OUTPUT=${ENABLE_COLOR_OUTPUT:-true}
ENABLE_DIR_GROUPING=${ENABLE_DIR_GROUPING:-true}
MAX_RECENT_DIRS=${MAX_RECENT_DIRS:-10}
export BOOKMARK_FILE="${HOME}/.dir_bookmarks"
export LAST_DIR_FILE="${HOME}/.last_working_dir"
AUTO_LIST_AFTER_CD=${AUTO_LIST_AFTER_CD:-true}
RESTORE_LAST_DIR=${RESTORE_LAST_DIR:-false}
LARGE_DIR_THRESHOLD=${LARGE_DIR_THRESHOLD:-1000} # Skip auto-listing for dirs with >1000 files

# Frequently Used Directory Variables (exported: used by cd-navigation aliases)
export HOME_DIR="${HOME}"
export APP_DIR="${HOME}/Applications"
export CODE_DIR="${HOME}/Code"
export DESK_DIR="${HOME}/Desktop"
export DOCS_DIR="${HOME}/Documents"
export DOTF_DIR="${HOME}/.dotfiles"
export DOWN_DIR="${HOME}/Downloads"
export MUSIC_DIR="${HOME}/Music"
export PICS_DIR="${HOME}/Pictures"
export VIDS_DIR="${HOME}/Videos"

# Recent directories array (used by cd-core and cd-history modules)
# shellcheck disable=SC2034
RECENT_DIRS=()
