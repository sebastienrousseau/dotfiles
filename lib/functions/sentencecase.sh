#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Cross-Platform Sentencecase Utility (sentencecase)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   sentencecase converts file or directory names to sentence case. It capitalizes
#   the first character of the first word, while the rest of the characters are
#   lowercased. This is different from title case, as only the very first letter
#   is capitalized.
#
# Usage:
#   sentencecase <file_or_directory> [<file_or_directory> ...]
#
# Arguments:
#   <file_or_directory>     One or more file or directory paths to rename
#                           to sentence case.
#
# Notes:
#   - Already sentence case files are skipped.
#   - Non-existent paths will produce an error message.
#   - Complex scenarios (multiple words, punctuation) are handled by simply
#     making all letters lowercase except the first character.
#
################################################################################

sentencecase() {
  if [[ "$#" -lt 1 ]]; then
    echo "[ERROR] Please provide at least one file or directory to convert to sentence case." >&2
    return 1
  fi

  for file in "$@"; do
    if [[ ! -e "$file" ]]; then
      echo "[ERROR] The file or directory '$file' does not exist." >&2
      continue
    fi

    dirname=$(dirname "$file")
    filename=$(basename "$file")

    # Convert filename to lowercase
    lc_filename=$(printf "%s" "$filename" | tr '[:upper:]' '[:lower:]')

    # Capitalize only the first character
    sc_filename="$(printf "%s" "${lc_filename:0:1}" | tr '[:lower:]' '[:upper:]')${lc_filename:1}"

    # If already sentence case, skip
    if [[ "$filename" == "$sc_filename" ]]; then
      echo "[INFO] '$file' is already in sentence case."
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
