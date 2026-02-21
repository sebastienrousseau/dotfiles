# shellcheck shell=bash
# CD Navigation - Directory History
[[ -n "${_CD_HISTORY_LOADED:-}" ]] && :
_CD_HISTORY_LOADED=1

# Directory history navigation
dirhistory() {
  if [[ ${#RECENT_DIRS[@]} -eq 0 ]]; then
    echo "No directory history found."
    return 0
  fi

  echo "Recent directories:"
  for i in "${!RECENT_DIRS[@]}"; do
    # Highlight current directory
    if [[ "${RECENT_DIRS[$i]}" == "${PWD}" ]]; then
      echo "$i: ${RECENT_DIRS[$i]} (current)"
    else
      echo "$i: ${RECENT_DIRS[$i]}"
    fi
  done

  echo ""
  read -p "Enter number to navigate (or any other key to cancel): " num

  if [[ "$num" =~ ^[0-9]+$ ]] && [[ $num -lt ${#RECENT_DIRS[@]} ]]; then
    cd_with_history "${RECENT_DIRS[$num]}"
  fi
}
