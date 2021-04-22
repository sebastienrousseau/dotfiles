# mcd: Function to combine mkdir and cd
function mcd() {
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument" >&2
    return 1
  fi
  echo "[INFO] Creating the folder $1"
	mkdir "$1"
  echo "[INFO] Switching to $1 folder"
	cd "$1" || exit
}
