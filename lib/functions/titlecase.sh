#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Cross-Platform Titlecase Utility (titlecase)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   titlecase is a utility function that converts file or directory names to
#   title case. It capitalizes the first character and lowercases all subsequent
#   characters, resulting in a format similar to "Myfile.txt".
#
# Usage:
#   titlecase <file_or_directory> [<file_or_directory> ...]
#
# Arguments:
#   <file_or_directory>     One or more file or directory paths to rename
#                           to title case.
#
# Notes:
#   - This utility will skip renaming files or directories that are already
#     in title case.
#   - Invalid or non-existent paths will result in an error message.
#   - If you need more complex title casing (e.g., handling underscores or
#     multiple words), you may need to adjust the logic.
#
################################################################################

titlecase() {
  # Ensure at least one argument is provided
  if [[ "$#" -lt 1 ]]; then
    echo "[ERROR] Please provide at least one file or directory to convert to title case." >&2
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

    # Convert the entire filename to lowercase
    lc_filename=$(printf "%s" "${filename}" | tr '[:upper:]' '[:lower:]')
    # Capitalize the first letter
    tc_filename="$(printf "%s" "${lc_filename:0:1}" | tr '[:lower:]' '[:upper:]')${lc_filename:1}"

    # If already in title case, skip
    if [[ "${filename}" == "${tc_filename}" ]]; then
      echo "[INFO] '${file}' is already in title case."
      continue
    fi

    newname="${dirname}/${tc_filename}"

    if mv "${file}" "${newname}"; then
      echo "[INFO] Renamed '${file}' to '${newname}'."
    else
      echo "[ERROR] Failed to rename '${file}'." >&2
    fi
  done
}
