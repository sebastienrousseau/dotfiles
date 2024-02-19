#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# Script: chmod.aliases.sh
# Version: 0.2.468
# Author: @wwdseb
# Copyright (c) 2015-2024. All rights reserved
# Description: Enhanced chmod command aliases with safety features, input validation, and structured organization.
# Website: https://dotfiles.io
# License: MIT
################################################################################

# Ensuring chmod command is available
if command -v chmod >/dev/null; then

  # Validate input for permission and path
  function validate_input() {
    local permission="$1"
    local path="$2"
    # Validate permission pattern (e.g., numeric octal)
    if ! [[ ${permission} =~ ^[0-7]{3}$ ]]; then
      echo "Invalid permission format: ${permission}. Expected format: ### (e.g., 644)."
      return 1
    fi
    # Validate path existence
    if ! [[ -e "${path}" ]]; then
      echo "Path does not exist: ${path}."
      return 1
    fi
    return 0
  }

  # Function to change permissions with confirmation for recursive changes
  function change_permission() {
    local permission="$1"
    local path="$2"
    local recursive="$3"
    local confirm

    # Validate inputs
    if ! validate_input "${permission}" "${path}"; then
      return 1
    fi

    # Confirmation for recursive changes
    if [[ "${recursive}" == "-R" ]]; then
      read -rp "Confirm recursive change to ${permission} for ${path}? (y/N): " confirm
      if [[ ${confirm} != [yY] ]]; then
        echo "Operation cancelled."
        return
      fi
    fi

    chmod "${recursive}" "${permission}" "${path}" && echo "Permissions set to ${permission} on ${path}"
  }

  # Alias definitions using the function for common permissions
  alias perm000='change_permission 000'
  alias perm400='change_permission 400'
  alias perm444='change_permission 444'
  alias perm600='change_permission 600'
  alias perm644='change_permission 644'
  alias perm666='change_permission 666'
  alias perm755='change_permission 755'
  alias perm764='change_permission 764'
  alias perm777='change_permission 777'

  # Shortcuts to set permissions for specific user types
  alias u+x='chmod u+x' # u+x: Add execute permission for the owner of the file.
  alias u-x='chmod u-x' # u-x: Remove execute permission for the owner of the file.
  alias u+w='chmod u+w' # u+w: Add write permission for the owner of the file.
  alias u-w='chmod u-w' # u-w: Remove write permission for the owner of the file.
  alias u+r='chmod u+r' # u+r: Add read permission for the owner of the file.
  alias u-r='chmod u-r' # u-r: Remove read permission for the owner of the file.

  alias g+x='chmod g+x' # g+x: Add execute permission for the group owner of the file.
  alias g-x='chmod g-x' # g-x: Remove execute permission for the group owner of the file.
  alias g+w='chmod g+w' # g+w: Add write permission for the group owner of the file.
  alias g-w='chmod g-w' # g-w: Remove write permission for the group owner of the file.
  alias g+r='chmod g+r' # g+r: Add read permission for the group owner of the file.
  alias g-r='chmod g-r' # g-r: Remove read permission for the group owner of the file.

  alias o+x='chmod o+x' # o+x: Add execute permission for others.
  alias o-x='chmod o-x' # o-x: Remove execute permission for others.
  alias o+w='chmod o+w' # o+w: Add write permission for others.
  alias o-w='chmod o-w' # o-w: Remove write permission for others.
  alias o+r='chmod o+r' # o+r: Add read permission for others.
  alias o-r='chmod o-r' # o-r: Remove read permission for others.

fi
