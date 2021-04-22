# mount_read_only: Function to mount a read-only disk image as read-write
function mount_read_only() {
  hdiutil attach "$1" -shadow /tmp/"$1".shadow -noverify
}
