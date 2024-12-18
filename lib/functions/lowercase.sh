#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Cross-Platform Lowercase Utility (lowercase)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   lowercase is a utility function that converts file or directory names to
#   lowercase. It supports multiple arguments and provides informative messages
#   for each operation, including errors and successful renames.
#
# Usage:
#   lowercase <file_or_directory> [<file_or_directory> ...]
#
# Arguments:
#   <file_or_directory>     One or more file or directory paths to rename
#                           to lowercase.
#
# Notes:
#   - This utility will skip renaming files or directories that are already
#     in lowercase.
#   - Invalid or non-existent paths will result in an error message.
#
################################################################################

lowercase() {
  # Ensure at least one argument is provided
  if [[ "$#" -lt 1 ]]; then
    echo "[ERROR] Please provide at least one file or directory to convert to lowercase." >&2
    return 1
  fi

  for file in "$@"; do
    # Check if the file/directory exists
    if [[ ! -e "$file" ]]; then
      echo "[ERROR] The file or directory '$file' does not exist." >&2
      continue
    fi

    dirname=$(dirname "$file")
    filename=$(basename "$file")

    # Convert filename to lowercase using tr
    nf=$(printf "%s" "$filename" | tr '[:upper:]' '[:lower:]')

    # If already lowercase, skip
    if [[ "$filename" == "$nf" ]]; then
      echo "[INFO] '$file' is already in lowercase."
      continue
    fi

    newname="${dirname}/${nf}"

    if mv "$file" "$newname"; then
      echo "[INFO] Renamed '$file' to '$newname'."
    else
      echo "[ERROR] Failed to rename '$file'." >&2
    fi
  done
}
