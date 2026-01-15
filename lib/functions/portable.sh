#!/usr/bin/env bash

# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.470) - <https://dotfiles.io>
# Made with ♥ in London, UK by Sebastien Rousseau
# License: MIT

## PORTABLE SYSTEM ABSTRACTIONS
##
## Provides cross-platform wrappers for OS-specific commands.
## Supports: macOS (Darwin) and Linux (Ubuntu, Debian, RHEL)
##
## Functions:
##   get_file_mtime <file>     - Get modification time (seconds since epoch)
##   get_file_perms <file>     - Get file permissions (octal format)
##   is_macos                  - Return 0 if macOS, 1 otherwise
##   is_linux                  - Return 0 if Linux, 1 otherwise

#------------------------------------------------------------------------------
# OS Detection
#------------------------------------------------------------------------------

is_macos() {
  [[ "$(uname -s)" == "Darwin" ]]
}

is_linux() {
  [[ "$(uname -s)" == "Linux" ]]
}

#------------------------------------------------------------------------------
# File Metadata
#------------------------------------------------------------------------------

# Get file modification time in seconds since epoch
# Usage: get_file_mtime <file>
# Returns: Integer (seconds since epoch) or 0 on error
get_file_mtime() {
  local file="$1"
  
  if [[ ! -e "$file" ]]; then
    echo "0"
    return 1
  fi
  
  if is_macos; then
    # macOS: stat -f %m (modification time)
    stat -f %m "$file" 2>/dev/null || echo "0"
  elif is_linux; then
    # Linux: stat -c %Y (modification time)
    stat -c %Y "$file" 2>/dev/null || echo "0"
  else
    echo "0"
    return 1
  fi
}

# Get file permissions in octal format (e.g., 0644, 0700)
# Usage: get_file_perms <file>
# Returns: String (octal permissions like "0644") or empty on error
get_file_perms() {
  local file="$1"
  
  if [[ ! -e "$file" ]]; then
    return 1
  fi
  
  if is_macos; then
    # macOS: stat -f %p (permissions, full format like 100644)
    # tail -c 4 to get last 3 octal digits plus leading 0
    stat -f %p "$file" 2>/dev/null | tail -c 4
  elif is_linux; then
    # Linux: stat -c %a (permissions, octal like 644)
    # Prefix with 0 for consistency
    local perms
    perms=$(stat -c %a "$file" 2>/dev/null)
    if [[ -n "$perms" ]]; then
      echo "0${perms}"
    fi
  else
    return 1
  fi
}

#------------------------------------------------------------------------------
# Export Functions (Bash and Zsh compatible)
#------------------------------------------------------------------------------

# Only use export -f in Bash (not supported in Zsh)
if [[ -n "${BASH_VERSION:-}" ]]; then
  export -f is_macos
  export -f is_linux
  export -f get_file_mtime
  export -f get_file_perms
fi
