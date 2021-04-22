# goto: Function to change to the directory inputed 
goto() {
  if [ -e "$1" ]; then
	  cd "$1"; l
  else
	  echo "[ERROR] Please add a directory name" >&2
  fi
}