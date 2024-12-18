#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Cross-Platform Snakecase Utility (snakecase)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   snakecase converts file or directory names to snake_case. All letters
#   are lowercase and spaces or other non-alphanumeric characters are replaced
#   by underscores.
#
# Usage:
#   snakecase <file_or_directory> [<file_or_directory> ...]
#
# Arguments:
#   <file_or_directory>     One or more file or directory paths to rename
#                           to snake_case.
#
# Notes:
#   - Already snake_case files are skipped.
#   - Non-existent paths will produce an error message.
#   - Special characters (other than alphanumeric and '.') are replaced
#     with underscores.
#
################################################################################

snakecase() {
  if [[ "$#" -lt 1 ]]; then
    echo "[ERROR] Please provide at least one file or directory to convert to snake_case." >&2
    return 1
  fi

  for file in "$@"; do
    if [[ ! -e "$file" ]]; then
      echo "[ERROR] The file or directory '$file' does not exist." >&2
      continue
    fi

    dirname=$(dirname "$file")
    filename=$(basename "$file")

    # Convert to lowercase and replace non-alphanumeric chars (except '.') with underscores
    sc_filename=$(printf "%s" "$filename" \
      | tr '[:upper:]' '[:lower:]' \
      | sed 's/[^[:alnum:].]/_/g')

    # If already snake_case, skip
    if [[ "$filename" == "$sc_filename" ]]; then
      echo "[INFO] '$file' is already in snake_case."
      continue
    fi

    newname="${dirname}/${sc_filename}"
    if mv "$file" "$newname"; then
      echo "[INFO] Renamed '$file' to '$newname'."
    else
      echo "[ERROR] Failed to rename '$file'." >&2
    fi
  done
}
