# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# remove_disk: spin down unneeded disk
remove_disk() {
  diskutil eject "$1"
}
