#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂
# File: editor.sh
# Version: 0.2.470
# Author: Sebastien Rousseau
# Copyright (c) 2015-2025. All rights reserved
# Description: Configure editor preferences for various applications
# Website: https://dotfiles.io
# License: MIT
################################################################################

#-----------------------------------------------------------------------------
# Function: configure_preferred_editors
#
# Description:
#   Sets up editor preferences for various applications with appropriate
#   fallbacks based on available editors.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#-----------------------------------------------------------------------------
configure_preferred_editors() {
  local OS_NAME
  OS_NAME=$(uname -s)
  local default_editor="vi"
  local preferred_editors=("nvim" "code" "vim" "nano" "emacs" "subl" "atom" "notepad++")
  local selected_editor=""

  # Try to find preferred editors in order of preference
  for editor in "${preferred_editors[@]}"; do
    if command -v "${editor}" &>/dev/null; then
      selected_editor="${editor}"
      break
    fi
  done

  # If none of the preferred editors are found, check Windows-specific paths
  if [[ -z "${selected_editor}" ]]; then
    # For Windows, check additional paths for VS Code
    if [[ "${OS_NAME}" == "MINGW"* || "${OS_NAME}" == "MSYS"* ]]; then
      win_code_path="/c/Users/${USER}/AppData/Local/Programs/Microsoft VS Code/bin/code"
      if [[ -f "${win_code_path}" ]]; then
        selected_editor="${win_code_path}"
      fi
    fi

    # If still no editor found, fall back to default
    if [[ -z "${selected_editor}" ]]; then
      if command -v "${default_editor}" &>/dev/null; then
        selected_editor="${default_editor}"
      else
        echo "Warning: No suitable editor found. Editor variables will not be set." >&2
        return 1
      fi
    fi
  fi

  # Set VISUAL to the selected editor
  export VISUAL="${selected_editor}"

  # Set other editor variables to use VISUAL
  export EDITOR="${VISUAL}"
  export GIT_EDITOR="${VISUAL}"
  export SVN_EDITOR="${VISUAL}"
  export SUDO_EDITOR="${VISUAL}"

  # Set environment variables for editor configuration
  export VIMRC="${HOME}/.vimrc"
  export NVIM_INIT="${HOME}/.config/nvim/init.lua"

  return 0
}

#-----------------------------------------------------------------------------
# Function: configure_editor_options
#
# Description:
#   Configures editor-specific options based on the selected editor.
#
# Arguments:
#   None
#
# Returns:
#   0 on success
#-----------------------------------------------------------------------------
configure_editor_options() {
  # Set editor-specific options based on VISUAL
  case "${VISUAL}" in
  nvim)
    # Set Neovim-specific configuration
    export VIMINIT="source ${NVIM_INIT:-${HOME}/.config/nvim/init.lua}"
    ;;
  code | */code)
    # VS Code specific settings
    export VSCODE_EXTENSIONS="${HOME}/.vscode/extensions/"
    ;;
  emacs)
    # Emacs specific settings
    export EMACSLOADPATH="${HOME}/.emacs.d"
    ;;
  subl | */subl)
    # Sublime Text specific settings
    export SUBLIME_USER_DIR="${HOME}/.config/sublime-text/Packages/User"
    ;;
  *)
    # No specific settings for other editors
    ;;
  esac
  return 0
}

#-----------------------------------------------------------------------------
# Main Execution
#-----------------------------------------------------------------------------

# Configure preferred editors
configure_preferred_editors || echo "Warning: Failed to configure preferred editors" >&2

# Configure editor-specific options
if [[ -n "${VISUAL}" ]]; then
  configure_editor_options
fi
