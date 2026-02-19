#!/usr/bin/env bash
# Copyright (c) 2015-2026 Sebastien Rousseau. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Backup Library
# Handles backup of existing dotfiles before chezmoi applies changes

# Create a timestamped backup directory
# Returns: Path to the backup directory
create_backup_dir() {
  local backup_dir
  backup_dir="$HOME/.dotfiles.bak.$(date +"%Y%m%d_%H%M%S")"
  echo "$backup_dir"
}

# Backup files that chezmoi will overwrite
# Arguments:
#   $1 - Backup directory path
#   $2 - Chezmoi config file path
# Returns: Number of files backed up
backup_managed_files() {
  local backup_dir="$1"
  local config_file="$2"
  local backup_count=0

  if ! command -v chezmoi >/dev/null 2>&1; then
    echo "0"
    return
  fi

  if [ ! -f "$config_file" ]; then
    echo "0"
    return
  fi

  while IFS= read -r file; do
    [ -z "$file" ] && continue
    if [ -e "$file" ]; then
      local rel="${file#"$HOME"/}"
      mkdir -p "$backup_dir/$(dirname "$rel")"
      cp -a "$file" "$backup_dir/$rel"
      backup_count=$((backup_count + 1))
    fi
  done < <(chezmoi managed --path-style=absolute 2>/dev/null || true)

  echo "$backup_count"
}

# Perform backup and report results
# Returns: 0 on success
perform_backup() {
  local config_dir="$HOME/.config/chezmoi"
  local config_file="$config_dir/chezmoi.toml"

  local backup_dir
  backup_dir="$(create_backup_dir)"

  local backup_count
  backup_count="$(backup_managed_files "$backup_dir" "$config_file")"

  if [ "$backup_count" -gt 0 ]; then
    echo "   Backed up $backup_count files to $backup_dir"
  else
    echo "   No existing dotfiles to back up."
    rm -rf "$backup_dir" 2>/dev/null || true
  fi

  return 0
}

# Restore from a backup directory
# Arguments:
#   $1 - Backup directory path
restore_backup() {
  local backup_dir="$1"

  if [ ! -d "$backup_dir" ]; then
    echo "Error: Backup directory not found: $backup_dir" >&2
    return 1
  fi

  echo "Restoring from $backup_dir..."

  # Use rsync if available, otherwise cp
  if command -v rsync >/dev/null 2>&1; then
    rsync -av "$backup_dir/" "$HOME/"
  else
    cp -a "$backup_dir/." "$HOME/"
  fi

  echo "Restore complete."
  return 0
}

# List available backups
list_backups() {
  local backups
  backups=$(find "$HOME" -maxdepth 1 -type d -name ".dotfiles.bak.*" 2>/dev/null | sort -r)

  if [ -z "$backups" ]; then
    echo "No backups found."
    return 0
  fi

  echo "Available backups:"
  echo "$backups" | while read -r backup; do
    local file_count
    file_count=$(find "$backup" -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  $(basename "$backup") ($file_count files)"
  done
}
