# size: Function to check a file size
function size() {
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument" >&2
    return 1
  fi
  stat -f '[INFO] The file total size, in bytes is %z' "$1"
}
