# vsc: Function to open a file in Visual Studio Code.

vsc() {
  if [[ -z "$1" ]]; then
    echo "Usage: vsc <file>"
    return 1
  fi

  if [[ -f "$1" ]]; then
    code "$1"
  else
    echo "File not found: $1"
    return 1
  fi
}
