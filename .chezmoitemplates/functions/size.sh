# shellcheck shell=bash
# size: Function to check a file size
# Platform: macOS uses stat -f, Linux uses stat -c
size() {
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument (file or directory)" >&2
    return 1
  fi

  local bytes
  if [[ "$(uname -s)" == "Darwin" ]]; then
    bytes=$(stat -f '%z' "$1" 2>/dev/null)
  else
    bytes=$(stat -c '%s' "$1" 2>/dev/null)
  fi

  if [[ -n "$bytes" ]]; then
    echo "[INFO] Total size: $bytes bytes"
  else
    echo "[ERROR] Could not determine size of $1" >&2
    return 1
  fi
}
