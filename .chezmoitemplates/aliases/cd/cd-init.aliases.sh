# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# CD Navigation - Initialization
[[ -n "${_CD_INIT_LOADED:-}" ]] && :
_CD_INIT_LOADED=1

# Consistent Shorthand Aliases
# Keep `cd` override opt-in to avoid surprising behavior in scripts/sessions.
if [[ "${DOTFILES_ENABLE_CD_ALIAS:-0}" == "1" ]]; then
  alias cd='cd_with_history' # Override default cd command
else
  alias cdh='cd_with_history' # Explicit enhanced cd helper
fi
mcd() { mkdir -p "$1" && cd "$1"; } # Create and enter directory

# Bookmark management
alias bm='bm add'               # Create bookmark
alias bmu='bm update'           # Update bookmark
alias bmr='bm remove'           # Remove bookmark
alias bml='bm list'             # List bookmarks
bmg() { cd "$(bm goto "$1")"; } # Go to bookmark (requires shell cd)

# Navigation shortcuts
alias dh='dirhistory' # Show directory history
alias pr='proj'       # Navigate to project root
alias ld='lwd'        # Return to last directory

# Initialize last working directory
if [[ "${RESTORE_LAST_DIR:-false}" == "true" ]]; then
  # Only run when the shell starts, not when the script is sourced again
  if [[ -z "${DOTFILES_INIT_DONE}" ]]; then
    lwd 2>/dev/null
    export DOTFILES_INIT_DONE=1
  fi
fi
