# remove_disk: spin down unneeded disk
function remove_disk () {
  diskutil eject "$1"
}