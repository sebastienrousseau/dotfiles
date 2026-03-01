# shellcheck shell=bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# CD Navigation - Parent Directory and Common Location Shortcuts
[[ -n "${_CD_SHORTCUTS_LOADED:-}" ]] && :
_CD_SHORTCUTS_LOADED=1

# Parent Directory Shortcuts
alias -- -='cd -'                         # Go to the previous directory
alias ..='up 1'               # Go up one level
alias ...='up 2'              # Go up two levels
alias ....='up 3'             # Go up three levels
alias .....='up 4'            # Go up four levels
alias ......='up 5'           # Go up five levels

# Home and Frequently Used Directories
# Only create aliases for directories that exist
[[ -d "${APP_DIR}" ]] && alias app='cd_with_history "${APP_DIR}"'     # Applications
[[ -d "${CODE_DIR}" ]] && alias cod='cd_with_history "${CODE_DIR}"'   # Code
[[ -d "${DESK_DIR}" ]] && alias dsk='cd_with_history "${DESK_DIR}"'   # Desktop
[[ -d "${DOCS_DIR}" ]] && alias doc='cd_with_history "${DOCS_DIR}"'   # Documents
[[ -d "${DOTF_DIR}" ]] && alias dotf='cd_with_history "${DOTF_DIR}"'  # Dotfiles
[[ -d "${DOWN_DIR}" ]] && alias dwn='cd_with_history "${DOWN_DIR}"'   # Downloads
[[ -d "${DOWN_DIR}" ]] && alias hom='cd_with_history "${HOME_DIR}"'   # Home Directory
[[ -d "${MUSIC_DIR}" ]] && alias mus='cd_with_history "${MUSIC_DIR}"' # Music
[[ -d "${PICS_DIR}" ]] && alias pic='cd_with_history "${PICS_DIR}"'   # Pictures
[[ -d "${VIDS_DIR}" ]] && alias vid='cd_with_history "${VIDS_DIR}"'   # Videos

# System Directories
[[ -d "/etc" ]] && alias etc="cd_with_history /etc" # System configuration
[[ -d "/var" ]] && alias var="cd_with_history /var" # Variable data
[[ -d "/tmp" ]] && alias tmp="cd_with_history /tmp" # Temporary files
[[ -d "/usr" ]] && alias usr="cd_with_history /usr" # User programs
