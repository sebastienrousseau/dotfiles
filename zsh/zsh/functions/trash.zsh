# trash: Function to moves a file to the MacOS trash
function trash() { 
	if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument" >&2
    return 1
  fi
  rm "$1"
}
