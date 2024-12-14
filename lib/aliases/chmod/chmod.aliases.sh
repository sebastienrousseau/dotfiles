#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Change directory aliases
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

    # Check permission format (e.g., numeric octal: ###)
    if ! [[ ${permission} =~ ^[0-7]{3}$ ]]; then
      echo "Error: Invalid permission format '${permission}'. Expected format: ### (e.g., 644)."
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
  # Function: Change permissions
  # Description: Applies chmod with validation and optional recursive handling.
  #-----------------------------------------------------------------------------
  change_permission() {
    local permission="$1"
    local path="$2"
    local recursive="${3:-}"

    # Validate input
    if ! validate_input "${permission}" "${path}"; then
      return 1
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
  # Common Permission Aliases
  #-----------------------------------------------------------------------------
  alias chmod_000='change_permission 000'  # No permissions
  alias chmod_400='change_permission 400'  # Read-only for owner
  alias chmod_444='change_permission 444'  # Read-only for all
  alias chmod_600='change_permission 600'  # Read/write for owner
  alias chmod_644='change_permission 644'  # Read/write for owner, read for others
  alias chmod_666='change_permission 666'  # Read/write for all
  alias chmod_755='change_permission 755'  # Full for owner, read/execute for others
  alias chmod_764='change_permission 764'  # Full for owner, read/write for group
  alias chmod_777='change_permission 777'  # Full permissions for all

  #-----------------------------------------------------------------------------
  # User, Group, and Other Shortcuts
  #-----------------------------------------------------------------------------
  # User
  alias chmod_u+x='chmod u+x'  # Add execute for owner
  alias chmod_u-x='chmod u-x'  # Remove execute for owner
  alias chmod_u+w='chmod u+w'  # Add write for owner
  alias chmod_u-w='chmod u-w'  # Remove write for owner
  alias chmod_u+r='chmod u+r'  # Add read for owner
  alias chmod_u-r='chmod u-r'  # Remove read for owner

  # Group
  alias chmod_g+x='chmod g+x'  # Add execute for group
  alias chmod_g-x='chmod g-x'  # Remove execute for group
  alias chmod_g+w='chmod g+w'  # Add write for group
  alias chmod_g-w='chmod g-w'  # Remove write for group
  alias chmod_g+r='chmod g+r'  # Add read for group
  alias chmod_g-r='chmod g-r'  # Remove read for group

  # Others
  alias chmod_o+x='chmod o+x'  # Add execute for others
  alias chmod_o-x='chmod o-x'  # Remove execute for others
  alias chmod_o+w='chmod o+w'  # Add write for others
  alias chmod_o-w='chmod o-w'  # Remove write for others
  alias chmod_o+r='chmod o+r'  # Add read for others
  alias chmod_o-r='chmod o-r'  # Remove read for others

fi
