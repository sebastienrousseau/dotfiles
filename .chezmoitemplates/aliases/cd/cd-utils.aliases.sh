# shellcheck shell=bash
# CD Navigation - Utility Functions
[[ -n "${_CD_UTILS_LOADED:-}" ]] && return 0
_CD_UTILS_LOADED=1

# Safely create or modify files
safe_write_file() {
  local file="$1"
  local content="$2"
  local mode="${3:-w}" # Default to overwrite mode

  # Create directory if it doesn't exist
  local dir
  dir=$(dirname "${file}")
  if [[ ! -d "${dir}" ]]; then
    mkdir -p "${dir}" 2>/dev/null || {
      echo "Error: Could not create directory ${dir}"
      return 1
    }
  fi

  # Write content to file
  if [[ "${mode}" == "a" ]]; then
    # Append mode
    echo "${content}" >>"${file}" 2>/dev/null
  else
    # Write mode
    echo "${content}" >|"${file}" 2>/dev/null
  fi

  return 0
}

# Count items in directory (for performance optimization)
count_dir_items() {
  local dir="$1"
  local count

  # Use ls and wc instead of find to avoid fd compatibility issues
  if [[ "${SHOW_HIDDEN_FILES}" == "true" ]]; then
    # shellcheck disable=SC2012
    count=$(ls -A "$dir" 2>/dev/null | wc -l | tr -d ' ')
  else
    # shellcheck disable=SC2012
    count=$(ls "$dir" 2>/dev/null | wc -l | tr -d ' ')
  fi

  echo "$count"
}
