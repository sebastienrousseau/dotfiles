#!/usr/bin/env bash
################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: history.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Enhanced by: ChatGPT
# Description: Manages shell history configuration, deduplication, and sorting.
# Website: https://dotfiles.io
# License: MIT
################################################################################

# BACKUP MANAGEMENT:
# This script automatically creates backups before modifying history files.
# - Default backup suffix is '.bak' (configurable via DOTFILES_BACKUP_SUFFIX)
# - Backups can be disabled by setting DOTFILES_NO_BACKUP=1
# - Backups are created atomically to prevent data loss
################################################################################

## Configurable environment variables
# DOTFILES_VERBOSE=0|1|2|3 - Controls verbosity (0=minimal, 1=normal, 2=debug, 3=trace)
# DOTFILES_BACKUP_SUFFIX=".bak" - Suffix for backup files
# DOTFILES_NO_BACKUP=0|1 - Set to 1 to disable backups
# DOTFILES_NUM_COLOR="33" - ANSI color code for history numbers (33=yellow)
# DOTFILES_CMD_COLOR="" - ANSI color code for commands (empty=default terminal color)
# DOTFILES_LOG_FILE="" - Path to log file (empty=log to stderr only)
# DOTFILES_LOG_LEVEL=0|1|2|3 - Log level (0=errors, 1=warnings, 2=info, 3=debug)

## 🅷🅸🆂🆃🅾🆁🆈

# ------------------------------------------------------------------------------
# Global variables for temporary file tracking and cleanup
# ------------------------------------------------------------------------------
declare -a TEMP_FILES=()  # Array to track temporary files for cleanup

# ------------------------------------------------------------------------------
# Enhanced logging function
# Args:
#   $1: Log level (0=ERROR, 1=WARN, 2=INFO, 3=DEBUG)
#   $2: Message to log
# ------------------------------------------------------------------------------
log_message() {
  local level="$1"
  local message="$2"
  local log_level="${DOTFILES_LOG_LEVEL:-1}"  # Default log level: warnings and errors
  local log_file="${DOTFILES_LOG_FILE:-}"     # Default: no log file
  local timestamp
  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"

  # Only log if the current level is less than or equal to the configured level
  if [[ "$level" -le "$log_level" ]]; then
    # Determine the log level text
    local level_text
    case "$level" in
      0) level_text="ERROR" ;;
      1) level_text="WARN " ;;
      2) level_text="INFO " ;;
      3) level_text="DEBUG" ;;
      *) level_text="?????" ;;
    esac

    # Format the log message
    local formatted_message="[$timestamp] [$level_text] $message"

    # Always output errors and warnings to stderr
    if [[ "$level" -le 1 ]]; then
      echo "$formatted_message" >&2
    fi

    # If log file is specified and writable, log to file
    if [[ -n "$log_file" ]]; then
      echo "$formatted_message" >> "$log_file" 2>/dev/null || \
        echo "[$timestamp] [ERROR] Failed to write to log file: $log_file" >&2
    # If no log file and level > 1, output to stderr if verbose mode
    elif [[ "$level" -gt 1 ]]; then
      local verbose="${DOTFILES_VERBOSE:-0}"
      if [[ "$verbose" -ge "$level" ]]; then
        echo "$formatted_message" >&2
      fi
    fi
  fi
}

# ------------------------------------------------------------------------------
# Creates a temporary file and registers it for cleanup
# Returns:
#   Prints the path to the temporary file
# ------------------------------------------------------------------------------
create_temp_file() {
  local temp_file
  temp_file="$(mktemp)" || {
    log_message 0 "Failed to create temporary file"
    return 1
  }

  # Add to the array of temp files to clean up
  TEMP_FILES+=("$temp_file")

  # Return the temp file path
  echo "$temp_file"
}

# ------------------------------------------------------------------------------
# Cleanup function for temporary files and resources
# ------------------------------------------------------------------------------
cleanup() {
  # Remove all tracked temporary files
  for temp_file in "${TEMP_FILES[@]}"; do
    if [[ -f "$temp_file" ]]; then
      rm -f "$temp_file"
      log_message 3 "Cleaned up temporary file: $temp_file"
    fi
  done

  # Reset the array
  TEMP_FILES=()
}

# Set up the cleanup trap for multiple signals
trap cleanup EXIT INT TERM HUP

# ------------------------------------------------------------------------------
# Helper function to format and colorize history output
# Args:
#   $1: The history output to format
# ------------------------------------------------------------------------------
format_history_output() {
  local input="$1"
  local num_color="${DOTFILES_NUM_COLOR:-33}"  # Default: yellow
  local cmd_color="${DOTFILES_CMD_COLOR:-}"    # Default: terminal default

  # If no command color specified, just use reset code
  local cmd_color_code=""
  if [[ -n "$cmd_color" ]]; then
    cmd_color_code="\033[${cmd_color}m"
  fi

  # Remove date/time format (matches YYYY-MM-DD HH:MM format)
  # Then colorize the line number while keeping the command
  echo "$input" |
    sed -E 's/[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}//g' |
    sed 's/^ *//' |
    awk -v num_color="$num_color" -v cmd_color="$cmd_color_code" '{
      # Print history number in specified color (default yellow)
      printf("\033[%sm%s\033[0m ", num_color, $1);

      # Find where the command part starts (after the first field)
      cmd_part = substr($0, index($0,$2));

      # Print command in specified color or default terminal color
      printf("%s%s\n", cmd_color, cmd_part);
    }'
}

# ------------------------------------------------------------------------------
# Create a backup of a file if backup is enabled
# Args:
#   $1: Path to file to backup
# Returns:
#   0 on success, 1 on failure
# ------------------------------------------------------------------------------
backup_file() {
  local file="$1"
  local backup_suffix="${DOTFILES_BACKUP_SUFFIX:-.bak}"
  local no_backup="${DOTFILES_NO_BACKUP:-0}"
  local verbose="${DOTFILES_VERBOSE:-0}"

  # Skip backup if disabled
  if [[ "$no_backup" -eq 1 ]]; then
    (( verbose >= 1 )) && echo "Backups disabled, skipping backup of $file" >&2
    return 0
  fi

  # Create backup if file exists
  if [[ -f "$file" ]]; then
    if cp "$file" "${file}${backup_suffix}"; then
      (( verbose >= 1 )) && echo "Created backup: ${file}${backup_suffix}" >&2
      return 0
    else
      (( verbose >= 1 )) && echo "Warning: Failed to create backup of $file" >&2
      return 1
    fi
  fi

  return 0
}

# ------------------------------------------------------------------------------
# Atomically replace a file
# Args:
#   $1: Source file
#   $2: Destination file
# Returns:
#   0 on success, 1 on failure
# ------------------------------------------------------------------------------
atomic_replace() {
  local src="$1"
  local dst="$2"
  # Use mv for atomic replacement
  log_message 3 "Atomically replacing $dst with $src"
  if mv "$src" "$dst"; then
    log_message 2 "Successfully replaced $dst"
    return 0
  else
    log_message 0 "Failed to replace $dst with $src"
    return 1
  fi
}

# ------------------------------------------------------------------------------
# Main history management function
# ------------------------------------------------------------------------------
dotfiles_history() {
  local opt OPTARG OPTIND
  local clear_flag="" list_flag="" sort_flag=""
  local verbose="${DOTFILES_VERBOSE:-0}"
  local ret=0
  local hist_file=""
  local shell_name=""

  # Detect shell and set history file path
  if [[ -n "${ZSH_VERSION:-}" ]]; then
    shell_name="zsh"
    hist_file="${HISTFILE:-$HOME/.zsh_history}"
    # Use zsh's option parsing
    zparseopts -E c=clear_flag l=list_flag s=sort_flag || ret=$?
  elif [[ -n "${BASH_VERSION:-}" ]]; then
    shell_name="bash"
    hist_file="${HISTFILE:-$HOME/.bash_history}"
    # Use getopts for bash
    while getopts "cls" opt; do
      case "$opt" in
        c) clear_flag="1" ;;
        l) list_flag="1" ;;
        s) sort_flag="1" ;;
        *) echo "Invalid option: -$OPTARG" >&2; return 1 ;;
      esac
    done
    shift $((OPTIND-1))
  else
    echo "Warning: Unsupported shell for this script." >&2
    return 1
  fi

  (( ret != 0 )) && { echo "Error parsing options" >&2; return "$ret"; }

  # ---------------------------------------------------------------------------
  # 1) Clear history
  # ---------------------------------------------------------------------------
  if [[ -n "${clear_flag}" ]]; then
    (( verbose >= 1 )) && echo "Clearing history file: $hist_file" >&2

    # Create a backup before clearing
    backup_file "$hist_file"

    if [[ "$shell_name" == "zsh" ]]; then
      # Write current history to file then clear it
      fc -W
      if : > "${hist_file}"; then
        # Reload history from the now-empty file
        fc -R
        (( verbose >= 1 )) && echo "History file cleared." >&2
      else
        echo "Failed to clear history file" >&2
        return 1
      fi
    else
      # For bash: Clear history in memory
      history -c
      if : > "${hist_file}"; then
        (( verbose >= 1 )) && echo "History file cleared." >&2
      else
        echo "Failed to clear history file" >&2
        return 1
      fi
    fi

    echo "Reload your shell session to see the effects." >&2
    return 0
  fi

  # ---------------------------------------------------------------------------
  # 2) Sort history & remove duplicates
  # ---------------------------------------------------------------------------
  if [[ -n "${sort_flag}" ]]; then
    (( verbose >= 1 )) && echo "Sorting history and removing duplicates..." >&2

    if [[ -f "${hist_file}" ]]; then
      # Create a backup before sorting
      backup_file "$hist_file"

      # Create temporary file
      local temp_file
      temp_file="$(create_temp_file)" || {
        log_message 0 "Failed to create temporary file"
        return 1
      }

      log_message 3 "Created temporary file: $temp_file"

      if [[ "$shell_name" == "zsh" ]]; then
        # For Zsh history format: ": timestamp:command_number;command"

        # Step 1: Process the file to remove duplicates (keep most recent entries)
        (( verbose >= 2 )) && echo "Removing duplicate commands..." >&2
        if ! tac "${hist_file}" | awk -F ';' '!seen[$2]++' | tac > "${temp_file}"; then
          echo "Error: Failed to process history file when removing duplicates" >&2
          return 1
        fi

        # Step 2: Sort by timestamp
        (( verbose >= 2 )) && echo "Sorting by timestamp..." >&2
        local sort_temp
        sort_temp="$(create_temp_file)" || {
          log_message 0 "Failed to create sorting temporary file"
          return 1
        }

        log_message 3 "Created sorting temporary file: $sort_temp"

        # Complex sorting process for zsh history format:
        # 1. Extract timestamp for sorting
        # 2. Sort by timestamp
        # 3. Remove the timestamp column we added just for sorting
        if ! awk 'BEGIN { FS=":"; OFS=":" } {
          # Extract timestamp, removing leading space if present
          ts=$2;
          gsub(/^ /, "", ts);
          # Print timestamp first for sorting, then original line
          print ts, $0
        }' "${temp_file}" | sort -k1,1n | awk '{
          # Remove the first field (timestamp) we added just for sorting
          $1="";
          # Remove leading space
          sub(/^ /, "");
          print
        }' > "${sort_temp}"; then
          echo "Error: Failed to sort history file" >&2
          return 1
        fi

        # Atomically update the history file
        if ! atomic_replace "$sort_temp" "$hist_file"; then
          return 1
        fi

        # Reload history in zsh
        fc -R
      else
        # For Bash: Remove duplicate lines, keeping most recent occurrence
        (( verbose >= 2 )) && echo "Removing duplicate commands..." >&2
        if ! tac "${hist_file}" | awk '!seen[$0]++' | tac > "${temp_file}"; then
          echo "Error: Failed to process history file" >&2
          return 1
        fi

        # Atomically update the history file
        if ! atomic_replace "$temp_file" "$hist_file"; then
          return 1
        fi

        # Clear and reload history in bash
        history -c
        history -r
      fi

      (( verbose >= 1 )) && echo "History sorted and duplicates removed." >&2
    else
      echo "Warning: History file ($hist_file) not found." >&2
    fi

    return 0
  fi

  # ---------------------------------------------------------------------------
  # 3) List history with args or options
  # ---------------------------------------------------------------------------
  if [[ -n "${list_flag}" ]] || [[ $# -ne 0 ]]; then
    local history_output=""

    # Handle custom history listing with date formatting removal
    if [[ "$shell_name" == "zsh" ]]; then
      # For Zsh, get history output
      if ! history_output=$(fc -li "$@" 2>/dev/null); then
        echo "Error retrieving history" >&2
        return 1
      fi
    else
      # For Bash, temporarily unset HISTTIMEFORMAT if needed
      local old_format="$HISTTIMEFORMAT"
      HISTTIMEFORMAT=""

      if ! history_output=$(history "$@" 2>/dev/null); then
        HISTTIMEFORMAT="$old_format"  # Restore original format
        echo "Error retrieving history" >&2
        return 1
      fi
      HISTTIMEFORMAT="$old_format"  # Restore original format
    fi

    # Format and colorize the output
    format_history_output "$history_output"
    return 0
  fi

  # ---------------------------------------------------------------------------
  # 4) Default action: Print recent history chunk
  # ---------------------------------------------------------------------------
  local history_output=""

  if [[ "$shell_name" == "zsh" ]]; then
    # Write current history to file
    fc -W

    # Get history output
    if ! history_output=$(fc -li 1 2>/dev/null); then
      echo "Error retrieving history" >&2
      return 1
    fi
  else
    # For Bash, temporarily unset HISTTIMEFORMAT
    local old_format="$HISTTIMEFORMAT"
    HISTTIMEFORMAT=""

    if ! history_output=$(history 2>/dev/null); then
      HISTTIMEFORMAT="$old_format"  # Restore original format
      echo "Error retrieving history" >&2
      return 1
    fi

    HISTTIMEFORMAT="$old_format"  # Restore original format
  fi

  # Format and colorize the output
  format_history_output "$history_output"
  return 0
}

# ------------------------------------------------------------------------------
# Apply shell-specific history configurations
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Set up history aliases and final configuration
# ------------------------------------------------------------------------------
configure_history() {
  local verbose="${DOTFILES_VERBOSE:-0}"

  # Force write current history to file
  if command -v fc >/dev/null 2>&1; then
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

# ------------------------------------------------------------------------------
# Print usage information
# ------------------------------------------------------------------------------
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

# ------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Script is being executed directly
  if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    print_usage
    exit 0
  fi
fi

# Apply shell configurations and set up aliases
apply_shell_configurations || {
  echo "Warning: Could not apply shell-specific history configurations" >&2
}
configure_history
