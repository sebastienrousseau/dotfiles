# shellcheck shell=bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.450)

# cd: Function to Enable "cd" into directory aliases
function cd() {
  if [ ${#1} == 0 ]; then
    builtin cd || exit
  elif [ -d "${1}" ]; then
    builtin cd "${1}" || exit
  elif [[ -f "${1}" || -L "${1}" ]]; then
    path=$(getTrueName "$1")
    builtin cd "$path" || exit
  else
    builtin cd "${1}" || exit
  fi
}
