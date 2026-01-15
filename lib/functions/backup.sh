#!/usr/bin/env bash

################################################################################
# 🅳🅾🆃🅵🅸🅻🅴🆂 - Cross-Platform Backup Utility (backup)
# Made with ♥ by Sebastien Rousseau
# License: MIT
#
# Description:
#   backup is a utility that creates timestamped backups of files and directories.
#   It can automatically compress large backups and maintains a configurable
#   backup history.
#
# Usage:
#   backup [--max-size SIZE] [--keep N] <file_or_directory> [<file_or_directory> ...]
#
# Arguments:
#   <file_or_directory>     One or more file or directory paths to back up.
#
# Options:
#   --max-size SIZE         Maximum uncompressed backup size before compression.
#                           Uses 'M' for megabytes, 'K' for kilobytes, or no suffix
#                           for bytes. Default is '100M' (100 megabytes).
#
#   --keep N                Number of most recent backups to keep. Older backups
#                           are removed. Default is 5.
#
# Notes:
#   - Backups are stored in a 'backups' directory in the current working directory.
#     Adjust the BACKUP_DIR variable if needed.
#   - The script creates a timestamped tar archive for the backup.
#   - If the tar archive exceeds --max-size, it will be compressed with gzip.
################################################################################

backup() {
  # Default configuration
  BACKUP_DIR="${BACKUP_DIR:-./backups}"
  MAX_SIZE="100M"   # Default max size before compression
  KEEP=5             # Default number of backups to keep

  # Parse arguments
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --max-size)
        MAX_SIZE="$2"
        shift 2
        ;;
      --keep)
        KEEP="$2"
        shift 2
        ;;
      -*)
        echo "[ERROR] Unknown option: $1" >&2
        return 1
        ;;
      *)
        # Once we hit a non-option, break to treat all remaining as files/dirs
        break
        ;;
    esac
  done

  # Ensure at least one file or directory is provided
  if [[ "$#" -lt 1 ]]; then
    echo "[ERROR] Please provide at least one file or directory to back up." >&2
    return 1
  fi

  # Create backup directory if it doesn't exist
  if [[ ! -d "$BACKUP_DIR" ]]; then
    mkdir -p "$BACKUP_DIR"
  fi

  # Generate a timestamp for the backup filename
  TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

  # Construct a temporary tar archive name (uncompressed)
  TAR_NAME="backup_${TIMESTAMP}.tar"
  TAR_PATH="${BACKUP_DIR}/${TAR_NAME}"

  # Create the tar archive
  if tar cf "${TAR_PATH}" "$@"; then
    echo "[INFO] Created backup archive '${TAR_PATH}'."
  else
    echo "[ERROR] Failed to create the backup archive." >&2
    return 1
  fi

  # Convert MAX_SIZE to bytes for comparison
  convert_size_to_bytes() {
    local size_str="$1"
    local num="${size_str//[!0-9]/}"
    local unit=$(echo "${size_str}" | sed 's/[0-9]//g' | tr '[:upper:]' '[:lower:]')

    case "$unit" in
      m) echo $((num * 1024 * 1024)) ;;
      k) echo $((num * 1024)) ;;
      "") echo "${num}" ;; # No unit means bytes
      *)
        echo "[ERROR] Invalid unit in --max-size. Use M for megabytes, K for kilobytes, or no unit for bytes." >&2
        return 1
        ;;
    esac
  }

  MAX_BYTES=$(convert_size_to_bytes "$MAX_SIZE")
  [[ $? -ne 0 ]] && return 1

  # Get file size in bytes using wc -c
  FILE_SIZE=$(wc -c < "${TAR_PATH}")

  if (( FILE_SIZE > MAX_BYTES )); then
    # Compress the backup
    if gzip "${TAR_PATH}"; then
      COMPRESSED_PATH="${TAR_PATH}.gz"
      echo "[INFO] Backup exceeded ${MAX_SIZE}. Compressed to '${COMPRESSED_PATH}'."
    else
      echo "[ERROR] Failed to compress the backup." >&2
      return 1
    fi
  else
    COMPRESSED_PATH="${TAR_PATH}"
    echo "[INFO] No compression required."
  fi

  # Enforce backup retention
  BACKUPS=($(ls -1t "${BACKUP_DIR}"/backup_*.tar* 2>/dev/null))
  BACKUP_COUNT=${#BACKUPS[@]}

  # Only attempt removal if we actually have more backups than KEEP
  if (( BACKUP_COUNT > KEEP )); then
    REMOVE_COUNT=$((BACKUP_COUNT - KEEP))
    OLD_BACKUPS=("${BACKUPS[@]:$KEEP:$REMOVE_COUNT}")
    for old_backup in "${OLD_BACKUPS[@]}"; do
      if rm -f "$old_backup"; then
        echo "[INFO] Removed old backup '$old_backup'."
      else
        echo "[ERROR] Failed to remove old backup '$old_backup'." >&2
      fi
    done
  fi

  echo "[INFO] Backup completed successfully. Current backups stored in '${BACKUP_DIR}'."
}
