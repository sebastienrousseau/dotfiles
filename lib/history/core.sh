#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - History Core
# Made with ♥ in London, UK by Sebastien Rousseau
# License: MIT

## CORE MODULE
## Provides the main dotfiles_history() function for managing shell history

# Source dependencies
DOTFILES_ROOT="${DOTFILES_ROOT:-${HOME}/.dotfiles}"
# shellcheck source=./logging.sh
source "${DOTFILES_ROOT}/lib/history/logging.sh"
# shellcheck source=./utils.sh
source "${DOTFILES_ROOT}/lib/history/utils.sh"
# shellcheck source=./backup.sh
source "${DOTFILES_ROOT}/lib/history/backup.sh"

#------------------------------------------------------------------------------
# Main history management function
# Handles clearing, sorting, and listing shell history
#------------------------------------------------------------------------------
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
