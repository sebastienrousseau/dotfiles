#!/usr/bin/env bash

################################################################################
# 🅲🅷🅼🅾🅳 🅰🅻🅸🅰🆂🅴🆂 - Enhanced chmod command aliases
# Made with ♥ by Sebastien Rousseau
# License: MIT
# Enhanced chmod command aliases with safety features, input validation, and structured organization.
################################################################################


# Ensure chmod exists before proceeding
if command -v chmod >/dev/null; then

  #-----------------------------------------------------------------------------
  # Function: Validate input
  # Description: Checks permission format and path validity.
  #-----------------------------------------------------------------------------
  validate_input() {
    local permission="$1"
    local path="$2"

    # Check permission format (supports both 3-digit and 4-digit octal)
    if ! [[ ${permission} =~ ^[0-7]{3,4}$ ]]; then
      echo "Error: Invalid permission format '${permission}'. Expected format: ### or #### (e.g., 644 or 2755)."
      return 1
    fi

    # Check if the path exists
    if ! [[ -e "${path}" ]]; then
      echo "Error: Path does not exist: '${path}'."
      return 1
    fi

    return 0
  }

  #-----------------------------------------------------------------------------
  # Function: Create backup
  # Description: Creates a backup of the target file/directory before modification.
  #-----------------------------------------------------------------------------
  create_backup() {
    local path="$1"
    local backup_path
    backup_path="${path}.bak.$(date +%Y%m%d%H%M%S)"

    # Only backup files, not directories
    if [[ -f "${path}" ]]; then
      cp -p "${path}" "${backup_path}" 2>/dev/null && \
        echo "Backup created at '${backup_path}'"
    fi
  }

  #-----------------------------------------------------------------------------
  # Function: Change permissions
  # Description: Applies chmod with validation and optional recursive handling.
  #-----------------------------------------------------------------------------
  change_permission() {
    local permission="$1"
    local path="$2"
    local recursive="${3:-}"
    local backup="${4:-false}"

    # Validate input
    if ! validate_input "${permission}" "${path}"; then
      return 1
    fi

    # Create backup if requested
    if [[ "${backup}" == "true" ]]; then
      create_backup "${path}"
    fi

    # Handle recursive changes with confirmation
    if [[ "${recursive}" == "-R" ]]; then
      local count
      count=$(find "${path}" 2>/dev/null | wc -l)
      read -rp "Confirm recursive change to '${permission}' for '${path}' (${count} items)? (y/N): " confirm
      if [[ ${confirm} != [yY] ]]; then
        echo "Operation cancelled."
        return 1
      fi
    fi

    # Apply permissions
    chmod "${recursive}" "${permission}" "${path}" && \
      echo "Permissions set to '${permission}' on '${path}'"
  }

  #-----------------------------------------------------------------------------
  # Function: Symbolic permission change with validation
  # Description: Wrapper for symbolic chmod with path validation.
  #-----------------------------------------------------------------------------
  symbolic_permission() {
    local permission="$1"
    local path="$2"
    local recursive="${3:-}"
    local backup="${4:-false}"

    # Check if the path exists
    if ! [[ -e "${path}" ]]; then
      echo "Error: Path does not exist: '${path}'."
      return 1
    fi

    # Create backup if requested
    if [[ "${backup}" == "true" ]]; then
      create_backup "${path}"
    fi

    # Handle recursive changes with confirmation
    if [[ "${recursive}" == "-R" ]]; then
      local count
      count=$(find "${path}" 2>/dev/null | wc -l)
      read -rp "Confirm recursive symbolic change '${permission}' for '${path}' (${count} items)? (y/N): " confirm
      if [[ ${confirm} != [yY] ]]; then
        echo "Operation cancelled."
        return 1
      fi
    fi

    # Apply permissions
    chmod "${recursive}" "${permission}" "${path}" && \
      echo "Applied '${permission}' on '${path}'"
  }

  #-----------------------------------------------------------------------------
  # Common Permission Aliases - Numeric Format
  #-----------------------------------------------------------------------------
  # No permissions
  alias chmod_000='change_permission 000'

  # Read-only permissions
  alias chmod_400='change_permission 400'  # Read-only for owner
  alias chmod_444='change_permission 444'  # Read-only for all

  # Read/write permissions
  alias chmod_600='change_permission 600'  # Read/write for owner
  alias chmod_644='change_permission 644'  # Read/write for owner, read for others
  alias chmod_664='change_permission 664'  # Read/write for owner and group, read for others
  alias chmod_666='change_permission 666'  # Read/write for all

  # Execute permissions
  alias chmod_700='change_permission 700'  # Full for owner only
  alias chmod_744='change_permission 744'  # Full for owner, read for others
  alias chmod_755='change_permission 755'  # Full for owner, read/execute for others
  alias chmod_764='change_permission 764'  # Full for owner, read/write for group, read for others
  alias chmod_775='change_permission 775'  # Full for owner and group, read/execute for others
  alias chmod_777='change_permission 777'  # Full permissions for all

  # Special permission bits
  alias chmod_1755='change_permission 1755'  # Sticky bit + 755
  alias chmod_2755='change_permission 2755'  # Setgid + 755
  alias chmod_4755='change_permission 4755'  # Setuid + 755

  #-----------------------------------------------------------------------------
  # Recursive Permission Functions
  #-----------------------------------------------------------------------------
  chmod_r_644() {
    change_permission 644 "$1" -R
  }  # Recursive 644

  chmod_r_755() {
    change_permission 755 "$1" -R
  }  # Recursive 755

  chmod_r_775() {
    change_permission 775 "$1" -R
  }  # Recursive 775

  #-----------------------------------------------------------------------------
  # Backup + Change Permission Functions
  #-----------------------------------------------------------------------------
  chmod_b_644() {
    change_permission 644 "$1" "" true
  }  # 644 with backup

  chmod_b_755() {
    change_permission 755 "$1" "" true
  }  # 755 with backup

  chmod_rb_644() {
    change_permission 644 "$1" -R true
  }  # Recursive 644 with backup

  chmod_rb_755() {
    change_permission 755 "$1" -R true
  }  # Recursive 755 with backup

  #-----------------------------------------------------------------------------
  # User, Group, and Other Symbolic Permission Functions
  #-----------------------------------------------------------------------------
  # User permissions
  chmod_u+x() { symbolic_permission u+x "$1"; }  # Add execute for owner
  chmod_u-x() { symbolic_permission u-x "$1"; }  # Remove execute for owner
  chmod_u+w() { symbolic_permission u+w "$1"; }  # Add write for owner
  chmod_u-w() { symbolic_permission u-w "$1"; }  # Remove write for owner
  chmod_u+r() { symbolic_permission u+r "$1"; }  # Add read for owner
  chmod_u-r() { symbolic_permission u-r "$1"; }  # Remove read for owner

  # Group permissions
  chmod_g+x() { symbolic_permission g+x "$1"; }  # Add execute for group
  chmod_g-x() { symbolic_permission g-x "$1"; }  # Remove execute for group
  chmod_g+w() { symbolic_permission g+w "$1"; }  # Add write for group
  chmod_g-w() { symbolic_permission g-w "$1"; }  # Remove write for group
  chmod_g+r() { symbolic_permission g+r "$1"; }  # Add read for group
  chmod_g-r() { symbolic_permission g-r "$1"; }  # Remove read for group

  # Others permissions
  chmod_o+x() { symbolic_permission o+x "$1"; }  # Add execute for others
  chmod_o-x() { symbolic_permission o-x "$1"; }  # Remove execute for others
  chmod_o+w() { symbolic_permission o+w "$1"; }  # Add write for others
  chmod_o-w() { symbolic_permission o-w "$1"; }  # Remove write for others
  chmod_o+r() { symbolic_permission o+r "$1"; }  # Add read for others
  chmod_o-r() { symbolic_permission o-r "$1"; }  # Remove read for others

  # Combined permissions
  chmod_a+x() { symbolic_permission a+x "$1"; }  # Add execute for all
  chmod_a-x() { symbolic_permission a-x "$1"; }  # Remove execute for all
  chmod_a+w() { symbolic_permission a+w "$1"; }  # Add write for all
  chmod_a-w() { symbolic_permission a-w "$1"; }  # Remove write for all
  chmod_a+r() { symbolic_permission a+r "$1"; }  # Add read for all
  chmod_a-r() { symbolic_permission a-r "$1"; }  # Remove read for all

  # Recursive symbolic permissions
  chmod_ru+x() { symbolic_permission u+x "$1" -R; }  # Recursive add execute for owner
  chmod_rg+x() { symbolic_permission g+x "$1" -R; }  # Recursive add execute for group
  chmod_ro+x() { symbolic_permission o+x "$1" -R; }  # Recursive add execute for others
  chmod_ra+x() { symbolic_permission a+x "$1" -R; }  # Recursive add execute for all

  #-----------------------------------------------------------------------------
  # Helper functions and aliases
  #-----------------------------------------------------------------------------
  # Show permissions in octal format for a file/directory
  # Minimalist version using built-in shell features only
  show_permissions() {
    local path="$1"
    if [[ -e "${path}" ]]; then
      echo "Permissions for: ${path}"

      # Check basic permissions using test operators
      echo "Read:    $(if [[ -r "${path}" ]]; then echo "Yes"; else echo "No"; fi)"
      echo "Write:   $(if [[ -w "${path}" ]]; then echo "Yes"; else echo "No"; fi)"
      echo "Execute: $(if [[ -x "${path}" ]]; then echo "Yes"; else echo "No"; fi)"

      # Check file type
      if [[ -f "${path}" ]]; then
        echo "Type: Regular file"
      elif [[ -d "${path}" ]]; then
        echo "Type: Directory"
      elif [[ -L "${path}" ]]; then
        echo "Type: Symbolic link"
      elif [[ -b "${path}" ]]; then
        echo "Type: Block device"
      elif [[ -c "${path}" ]]; then
        echo "Type: Character device"
      elif [[ -p "${path}" ]]; then
        echo "Type: Named pipe"
      elif [[ -S "${path}" ]]; then
        echo "Type: Socket"
      else
        echo "Type: Unknown"
      fi
    else
      echo "Error: Path does not exist: '${path}'."
      return 1
    fi
  }

  alias permissions='show_permissions'

fi

# Usage information
chmod_help() {
  cat << EOF
CHMOD ALIASES USAGE:

  Numeric Permission Aliases:
    chmod_000, chmod_400, chmod_444, chmod_600, chmod_644, chmod_664, chmod_666,
    chmod_700, chmod_744, chmod_755, chmod_764, chmod_775, chmod_777,
    chmod_1755, chmod_2755, chmod_4755

  Recursive Permission Functions:
    chmod_r_644, chmod_r_755, chmod_r_775

  Backup + Change Permission Functions:
    chmod_b_644, chmod_b_755, chmod_rb_644, chmod_rb_755

  Symbolic Permission Functions:
    User:   chmod_u+x, chmod_u-x, chmod_u+w, chmod_u-w, chmod_u+r, chmod_u-r
    Group:  chmod_g+x, chmod_g-x, chmod_g+w, chmod_g-w, chmod_g+r, chmod_g-r
    Others: chmod_o+x, chmod_o-x, chmod_o+w, chmod_o-w, chmod_o+r, chmod_o-r
    All:    chmod_a+x, chmod_a-x, chmod_a+w, chmod_a-w, chmod_a+r, chmod_a-r

  Recursive Symbolic Permissions:
    chmod_ru+x, chmod_rg+x, chmod_ro+x, chmod_ra+x

  Helper Functions:
    permissions <path>   - Show permissions in octal format for a file/directory
    chmod_help           - Display this help message
EOF
}
