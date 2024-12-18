#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Cross-Platform Uppercase Utility (uppercase)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   uppercase is a utility function that converts file or directory names to
#   uppercase. It supports multiple arguments and provides informative messages
#   for each operation, including errors and successful renames.
#
# Usage:
#   uppercase <file_or_directory> [<file_or_directory> ...]
#
# Arguments:
#   <file_or_directory>     One or more file or directory paths to rename
#                           to uppercase.
#
# Notes:
#   - This utility will skip renaming files or directories that are already
#     in uppercase.
#   - Invalid or non-existent paths will result in an error message.
#
################################################################################

uppercase() {
  # Ensure at least one argument is provided
  if [[ "$#" -lt 1 ]]; then
    echo "[ERROR] Please provide at least one file or directory to convert to uppercase." >&2
    return 1
  fi

  for file in "$@"; do
    # Check if the file/directory exists
    if [[ ! -e "${file}" ]]; then
      echo "[ERROR] The file or directory '${file}' does not exist." >&2
      continue
    fi

    dirname=$(dirname "${file}")
    filename=$(basename "${file}")

    # Convert filename to uppercase using tr
    uf=$(printf "%s" "${filename}" | tr '[:lower:]' '[:upper:]')

    # If already uppercase, skip
    if [[ "${filename}" == "${uf}" ]]; then
      echo "[INFO] '${file}' is already in uppercase."
      continue
    fi

    newname="${dirname}/${uf}"

    if mv "${file}" "${newname}"; then
      echo "[INFO] Renamed '${file}' to '${newname}'."
    else
      echo "[ERROR] Failed to rename '${file}'." >&2
    fi
  done
}