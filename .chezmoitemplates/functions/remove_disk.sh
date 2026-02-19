# shellcheck shell=bash
# remove_disk: spin down unneeded disk
remove_disk() {
  diskutil eject "$1"
}
