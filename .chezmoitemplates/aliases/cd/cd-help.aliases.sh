# shellcheck shell=bash
# CD Navigation - Help and Documentation
[[ -n "${_CD_HELP_LOADED:-}" ]] && :
_CD_HELP_LOADED=1

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
