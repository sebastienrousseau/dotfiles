# shellcheck shell=bash
# mount_read_only: Function to mount a read-only disk image as read-write
mount_read_only() {
  local disk_image="$1"

  # Validate input
  if [[ -z "$disk_image" ]]; then
    echo "[ERROR] No disk image specified." >&2
    return 1
  fi
  if [[ ! -f "$disk_image" ]]; then
    echo "[ERROR] Disk image not found: $disk_image" >&2
    return 1
  fi

  # Create secure temporary shadow file
  local shadow_file
  shadow_file="$(mktemp)" || return 1
  trap 'rm -f "$shadow_file"' RETURN

  hdiutil attach "$disk_image" -shadow "$shadow_file" -noverify
}
