# rm: Function to make 'rm' move files to the trash
function rm {
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument" >&2
    return 1
  fi
  [ ! -d ~/.Trash ] && mkdir ~/.Trash
  echo "[INFO] Removing $1"
  mv "$1" ~/.Trash
}
