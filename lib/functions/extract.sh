#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Archive Extractor (extract)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   extract is a function to extract most known archive formats with a single
#   command. It supports various archive types like .tar, .zip, .gz, .7z, and more.
#
# Usage:
#   extract [file]
#   extract --help
#
# Arguments:
#   file        The archive file to extract.
#   --help      Displays this help menu and exits.
#
# Examples:
#   extract file.tar.gz
#       # Extracts the contents of file.tar.gz.
#
#   extract archive.zip
#       # Extracts the contents of archive.zip.
#
#   extract --help
#       # Displays the help menu.
#
################################################################################

# Function to extract most known archive formats
extract() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "extract: Archive Extractor"
    echo
    echo "Usage:"
    echo "  extract [file]"
    echo "  extract --help"
    echo
    echo "Arguments:"
    echo "  file        The archive file to extract."
    echo "  --help      Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  extract file.tar.gz"
    echo "      # Extracts the contents of file.tar.gz."
    echo
    echo "  extract archive.zip"
    echo "      # Extracts the contents of archive.zip."
    echo
    echo "  extract --help"
    echo "      # Displays the help menu."
    echo
    return 0
  fi

  # Validate input
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please provide one argument (the archive file to extract)." >&2
    return 1
  fi

  # Check if the file exists
  if [[ -f "$1" ]]; then
    echo "[INFO] Extracting '$1'..."
    case "$1" in
      *.tar.bz2) tar xjf "$1" ;;
      *.tar.gz)  tar xzf "$1" ;;
      *.bz2)     bunzip2 "$1" ;;
      *.rar)     unrar e "$1" ;;
      *.gz)      gunzip "$1" ;;
      *.tar)     tar xf "$1" ;;
      *.tbz2)    tar xjf "$1" ;;
      *.tgz)     tar xzf "$1" ;;
      *.zip)     unzip "$1" ;;
      *.Z)       uncompress "$1" ;;
      *.7z)      7z x "$1" ;;
      *)         echo "[ERROR] '$1' cannot be extracted via extract()." ;;
    esac
  else
    echo "[ERROR] '$1' is not a valid file." >&2
    return 1
  fi
}
