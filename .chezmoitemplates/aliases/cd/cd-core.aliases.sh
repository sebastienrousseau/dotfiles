# shellcheck shell=bash
# CD Navigation - Core Functions (cd_with_history, mkcd)
[[ -n "${_CD_CORE_LOADED:-}" ]] && :
_CD_CORE_LOADED=1

# Build the ls command based on configuration
LS_CMD="ls -lh"

if [[ "${SHOW_HIDDEN_FILES}" == "true" ]]; then
  LS_CMD="${LS_CMD} -a"
fi

if [[ "${ENABLE_COLOR_OUTPUT}" == "true" && -n "${LS_COLOR_OPT}" ]]; then
  LS_CMD="${LS_CMD} ${LS_COLOR_OPT}"
fi

# Only add group directories option if it's supported and enabled
if [[ "${ENABLE_DIR_GROUPING}" == "true" && -n "${LS_GROUP_DIRS}" ]]; then
  LS_CMD="${LS_CMD} ${LS_GROUP_DIRS}"
fi

# Enhanced cd function with directory history tracking
cd_with_history() {
  # Get the destination directory
  local dest="${1:-$HOME}"

  # Check if the destination is a bookmark
  if [[ -f "${BOOKMARK_FILE}" ]]; then
    local bookmark_dest
    bookmark_dest=$(grep "^${dest}:" "${BOOKMARK_FILE}" | cut -d':' -f2)
    if [[ -n "${bookmark_dest}" ]]; then
      dest="${bookmark_dest}"
    fi
  fi

  # Validate directory
  if [[ ! -d "${dest}" ]]; then
    echo "Error: Directory '${dest}' not found"
    return 1
  fi

  if [[ ! -r "${dest}" ]]; then
    echo "Error: Directory '${dest}' is not readable"
    return 1
  fi

  if [[ ! -x "${dest}" ]]; then
    echo "Error: Directory '${dest}' is not accessible"
    return 1
  fi

  # Save current directory to history
  if [[ "${PWD}" != "${dest}" ]]; then
    # Add to recent dirs (avoid duplicates)
    local found=false
    for dir in "${RECENT_DIRS[@]}"; do
      if [[ "${dir}" == "${PWD}" ]]; then
        found=true
        break
      fi
    done

    if [[ "${found}" == false ]]; then
      RECENT_DIRS=("${PWD}" "${RECENT_DIRS[@]}")

      # Limit array size
      if [[ ${#RECENT_DIRS[@]} -gt ${MAX_RECENT_DIRS} ]]; then
        RECENT_DIRS=("${RECENT_DIRS[@]:0:${MAX_RECENT_DIRS}}")
      fi
    fi
  fi

  # Change directory
  builtin cd "${dest}" 2>/dev/null || return 1

  # Save last working directory
  safe_write_file "${LAST_DIR_FILE}" "${PWD}"

  # List directory contents if enabled and not a large directory
  if [[ "${AUTO_LIST_AFTER_CD}" == "true" ]]; then
    local item_count
    item_count=$(count_dir_items "${PWD}")
    if [[ ${item_count} -lt ${LARGE_DIR_THRESHOLD} ]]; then
      local -a _ls_args=(-lh)
      [[ "${SHOW_HIDDEN_FILES}" == "true" ]] && _ls_args+=(-a)
      [[ -n "${LS_COLOR_OPT}" && "${ENABLE_COLOR_OUTPUT}" == "true" ]] && _ls_args+=("${LS_COLOR_OPT}")
      [[ -n "${LS_GROUP_DIRS}" && "${ENABLE_DIR_GROUPING}" == "true" ]] && _ls_args+=("${LS_GROUP_DIRS}")
      ls "${_ls_args[@]}"
    else
      echo "Directory contains ${item_count} items. Skipping automatic listing."
      echo "Use 'ls' to list contents."
    fi
  fi
}

# Create directory and navigate to it
mkcd() {
  if [ -z "$1" ]; then
    echo "Usage: mkcd <directory_name>"
    return 1
  fi

  mkdir -p "$1" || {
    echo "Error: Failed to create directory '$1'"
    return 1
  }

  cd_with_history "$1"
}
