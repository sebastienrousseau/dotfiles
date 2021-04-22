# rd: Function to remove a direcory and its files
function rd() {
	if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument" >&2
    return 1
  fi
  rm "$1"
}