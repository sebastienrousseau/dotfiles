#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - History Configuration
# Made with ♥ in London, UK by Sebastien Rousseau
# License: MIT

## CONFIGURATION MODULE
## Applies shell-specific history configurations and sets up aliases

# Configurable environment variables:
# DOTFILES_VERBOSE - Controls verbosity (0=minimal, 1=normal, 2=debug, 3=trace)

# Source core module
DOTFILES_ROOT="${DOTFILES_ROOT:-${HOME}/.dotfiles}"
# shellcheck source=./core.sh
source "${DOTFILES_ROOT}/lib/history/core.sh"

#------------------------------------------------------------------------------
# Apply shell-specific history configurations
#------------------------------------------------------------------------------
apply_shell_configurations() {
  local verbose="${DOTFILES_VERBOSE:-0}"

  if [[ -n "${ZSH_VERSION:-}" ]]; then
    # ZSH history settings
    setopt hist_ignore_all_dups    # No duplicate entries
    setopt hist_ignore_space       # Don't record commands starting with space
    setopt hist_no_store           # Don't record history/fc commands
    setopt hist_reduce_blanks      # Remove unnecessary blanks
    setopt hist_expire_dups_first  # Expire duplicates first when trimming
    setopt hist_save_no_dups       # Don't save duplicates
    setopt hist_find_no_dups       # Ignore duplicates when searching
    setopt hist_verify             # Show command before executing from history
    setopt append_history          # Append to history file
    setopt inc_append_history      # Add commands as they are typed

    export HISTFILE="${HOME}/.zsh_history"
    export HISTSIZE=10000          # Lines to keep in memory
    export SAVEHIST=10000          # Lines to save to disk
    (( verbose >= 1 )) && echo "Applied Zsh history configurations" >&2

  elif [[ -n "${BASH_VERSION:-}" ]]; then
    # BASH history settings
    export HISTFILE="${HOME}/.bash_history"
    export HISTCONTROL="ignoreboth:erasedups"  # Ignore duplicates and commands starting with space
    export HISTSIZE=10000          # Lines to keep in memory
    export HISTFILESIZE=10000      # Lines to save to disk
    export HISTIGNORE="&:ls:[bf]g:exit:history:clear"  # Commands to ignore
    export HISTTIMEFORMAT=""       # No timestamp format (to match our display)

    # BASH shell options
    shopt -s histappend            # Append to history file, don't overwrite
    shopt -s histverify            # Edit recalled commands before executing
    shopt -s cmdhist               # Save multi-line commands as one entry
    (( verbose >= 1 )) && echo "Applied Bash history configurations" >&2
  else
    echo "Warning: Unsupported shell: ${SHELL}" >&2
    return 1
  fi

  return 0
}

#------------------------------------------------------------------------------
# Set up history aliases and final configuration
#------------------------------------------------------------------------------
configure_history() {
  local verbose="${DOTFILES_VERBOSE:-0}"

  # Force write current history to file (Zsh-specific)
  if [[ -n "${ZSH_VERSION:-}" ]] && command -v fc >/dev/null 2>&1; then
    fc -W
  fi

  # Set up convenient aliases
  alias h='dotfiles_history'
  alias history='dotfiles_history'
  alias hs='dotfiles_history -s'
  alias hc='dotfiles_history -c'
  (( verbose >= 1 )) && echo "Configured history aliases" >&2

  return 0
}

#------------------------------------------------------------------------------
# Print usage information
#------------------------------------------------------------------------------
print_usage() {
  cat <<EOF
dotfiles_history: Manage shell history

Usage:
  h              Display history
  h -c           Clear history
  h -s           Sort history and remove duplicates
  h -l [args]    List history with the given arguments

Environment variables:
  DOTFILES_VERBOSE       Set verbosity level (0=minimal, 1=normal, 2=debug, 3=trace)
  DOTFILES_BACKUP_SUFFIX Set suffix for backup files (default: .bak)
  DOTFILES_NO_BACKUP     Disable backups when set to 1
  DOTFILES_NUM_COLOR     ANSI color code for history numbers (default: 33=yellow)
  DOTFILES_CMD_COLOR     ANSI color code for commands (default: terminal default)
  DOTFILES_LOG_FILE      Path to log file (default: log to stderr only)
  DOTFILES_LOG_LEVEL     Log level (0=errors, 1=warnings, 2=info, 3=debug)
EOF
}

# Apply shell configurations and set up aliases
apply_shell_configurations || {
  echo "Warning: Could not apply shell-specific history configurations" >&2
}
configure_history
