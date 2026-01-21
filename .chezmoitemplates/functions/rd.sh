# shellcheck shell=bash
# rd: Function to remove a directory and its files
rd() {
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument" >&2
    return 1
  fi
  echo "[INFO] The operation completed successfully, directory listing of $1:"
  rm -rf "$1" || exit
  ls -lh
}
