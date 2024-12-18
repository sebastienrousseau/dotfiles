#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Cross-Platform Kebabcase Utility (kebabcase)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   kebabcase converts file or directory names to kebab-case. All letters
#   are lowercase and spaces or other non-alphanumeric characters are replaced
#   by hyphens.
#
# Usage:
#   kebabcase <file_or_directory> [<file_or_directory> ...]
#
# Arguments:
#   <file_or_directory>     One or more file or directory paths to rename
#                           to kebab-case.
#
# Notes:
#   - Already kebab-case files are skipped.
#   - Non-existent paths will produce an error message.
#   - Special characters (other than alphanumeric and '.') are replaced
#     with hyphens.
#
################################################################################

kebabcase() {
  if [[ "$#" -lt 1 ]]; then
    echo "[ERROR] Please provide at least one file or directory to convert to kebab-case." >&2
    return 1
  fi

  for file in "$@"; do
    if [[ ! -e "$file" ]]; then
      echo "[ERROR] The file or directory '$file' does not exist." >&2
      continue
    fi

    dirname=$(dirname "$file")
    filename=$(basename "$file")

    # Convert to lowercase and replace non-alphanumeric chars (except '.') with hyphens
    kc_filename=$(printf "%s" "$filename" \
      | tr '[:upper:]' '[:lower:]' \
      | sed 's/[^[:alnum:].]/-/g')

    # If already kebab-case, skip
    if [[ "$filename" == "$kc_filename" ]]; then
      echo "[INFO] '$file' is already in kebab-case."
      continue
    fi

    newname="${dirname}/${kc_filename}"
    if mv "$file" "$newname"; then
      echo "[INFO] Renamed '$file' to '$newname'."
    else
      echo "[ERROR] Failed to rename '$file'." >&2
    fi
  done
}
