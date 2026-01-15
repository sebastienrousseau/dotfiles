#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Free Disk Space Cleaner (freespace)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   freespace is a utility function to securely erase purgeable disk space with
#   zeros on the selected disk using the `diskutil secureErase freespace` command.
#
# Usage:
#   freespace [disk]
#   freespace --help
#
# Arguments:
#   disk        The disk to clean purgeable space from (e.g., /dev/disk1s1).
#   --help      Displays this help menu and exits.
#
# Examples:
#   freespace /dev/disk1s1
#       # Erases purgeable disk space with zeros on /dev/disk1s1.
#
#   freespace --help
#       # Displays the help menu.
#
################################################################################

freespace() {
  # Display help menu
  if [[ "$1" == "--help" ]]; then
    echo "freespace: Free Disk Space Cleaner"
    echo
    echo "Usage:"
    echo "  freespace [disk]"
    echo "  freespace --help"
    echo
    echo "Arguments:"
    echo "  disk        The disk to clean purgeable space from (e.g., /dev/disk1s1)."
    echo "  --help      Displays this help menu and exits."
    echo
    echo "Examples:"
    echo "  freespace /dev/disk1s1"
    echo "      # Erases purgeable disk space with zeros on /dev/disk1s1."
    echo
    echo "  freespace --help"
    echo "      # Displays the help menu."
    echo
    echo "Available Disks:"
    df -h | awk 'NR == 1 || /^\/dev\/disk/'
    echo
    return 0
  fi

  # Check if a disk argument is provided
  if [[ -z "$1" ]]; then
    echo "[ERROR] No disk provided. Use 'freespace --help' for usage information."
    echo
    echo "Available Disks:"
    df -h | awk 'NR == 1 || /^\/dev\/disk/'
    return 1
  fi

  # Perform secure erase of free space on the selected disk
  echo "[INFO] Cleaning purgeable files from disk: $1..."
  diskutil secureErase freespace 0 "$1"
}
