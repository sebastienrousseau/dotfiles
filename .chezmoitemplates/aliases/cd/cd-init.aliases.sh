# shellcheck shell=bash
# CD Navigation - Initialization
[[ -n "${_CD_INIT_LOADED:-}" ]] && return 0
_CD_INIT_LOADED=1

# Consistent Shorthand Aliases
# Keep `cd` override opt-in to avoid surprising behavior in scripts/sessions.
if [[ "${DOTFILES_ENABLE_CD_ALIAS:-0}" == "1" ]]; then
  alias cd='cd_with_history' # Override default cd command
else
  alias cdh='cd_with_history' # Explicit enhanced cd helper
fi
alias mcd='mkcd' # Create and enter directory

# Bookmark management
alias bm='bookmark'         # Create bookmark
alias bmu='bookmark_update' # Update bookmark
alias bmr='bookmark_remove' # Remove bookmark
alias bml='bookmark_list'   # List bookmarks (fixed from 'bookmark' to 'bookmark_list')
alias bmg='goto'            # Go to bookmark

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
