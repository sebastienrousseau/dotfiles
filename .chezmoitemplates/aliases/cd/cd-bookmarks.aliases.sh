# shellcheck shell=bash
# CD Navigation - Bookmark Functions
[[ -n "${_CD_BOOKMARKS_LOADED:-}" ]] && return 0
_CD_BOOKMARKS_LOADED=1

# List all bookmarks
bookmark_list() {
  if [[ -f "${BOOKMARK_FILE}" ]]; then
    echo "Available bookmarks:"
    # shellcheck disable=SC2002
    cat "${BOOKMARK_FILE}" | sed 's/:/\t/' | column -t
  else
    echo "No bookmarks found."
  fi
}

# Create a bookmark
bookmark() {
  if [ -z "$1" ]; then
    # Show usage and call the bookmark_list function
    echo "Usage: bookmark <bookmark_name> [directory]"
    bookmark_list
    return 0
  fi

  local name="$1"
  local dir="${2:-$PWD}"

  # Validate bookmark name (no spaces or special characters)
  if [[ ! "${name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Bookmark name can only contain letters, numbers, underscores and hyphens"
    return 1
  fi

  # Validate directory
  if [[ ! -d "${dir}" ]]; then
    echo "Error: Cannot bookmark non-existent directory '${dir}'"
    return 1
  fi

  if [[ ! -r "${dir}" ]] || [[ ! -x "${dir}" ]]; then
    echo "Error: Cannot bookmark inaccessible directory '${dir}'"
    return 1
  fi

  # Create bookmark file if it doesn't exist
  touch "${BOOKMARK_FILE}" 2>/dev/null || {
    echo "Error: Could not create bookmark file"
    return 1
  }

  # Check if bookmark already exists
  if grep -q "^${name}:" "${BOOKMARK_FILE}"; then
    echo "Bookmark '${name}' already exists. Use 'bookmark_update' to update it."
    return 1
  fi

  # Add bookmark
  safe_write_file "${BOOKMARK_FILE}" "${name}:${dir}" "a" || {
    echo "Error: Failed to write bookmark"
    return 1
  }

  echo "Bookmark '${name}' created for directory '${dir}'"
}

# Update existing bookmark
bookmark_update() {
  if [[ -z "$1" ]]; then
    echo "Usage: bookmark_update <bookmark_name> [directory]"
    return 1
  fi

  local name="$1"
  local dir="${2:-$PWD}"

  # Validate bookmark name
  if [[ ! "${name}" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Error: Bookmark name can only contain letters, numbers, underscores and hyphens"
    return 1
  fi

  # Validate directory
  if [[ ! -d "${dir}" ]]; then
    echo "Error: Cannot bookmark non-existent directory '${dir}'"
    return 1
  fi

  if [[ ! -r "${dir}" ]] || [[ ! -x "${dir}" ]]; then
    echo "Error: Cannot bookmark inaccessible directory '${dir}'"
    return 1
  fi

  # Check if bookmark file exists
  if [[ ! -f "${BOOKMARK_FILE}" ]]; then
    echo "No bookmarks found."
    return 1
  fi

  # Check if bookmark exists
  if ! grep -q "^${name}:" "${BOOKMARK_FILE}"; then
    echo "Bookmark '${name}' does not exist. Use 'bookmark' to create it."
    return 1
  fi

  # Update bookmark
  if [[ "${DOTFILES_OS}" == "Darwin"* ]]; then
    # macOS version of sed requires a backup extension
    sed -i '' "s|^${name}:.*$|${name}:${dir}|" "${BOOKMARK_FILE}"
  else
    # Linux version can use -i without an extension
    sed -i "s|^${name}:.*$|${name}:${dir}|" "${BOOKMARK_FILE}"
  fi

  echo "Bookmark '${name}' updated to '${dir}'"
}

# Remove bookmark
bookmark_remove() {
  if [ -z "$1" ]; then
    echo "Usage: bookmark_remove <bookmark_name>"
    return 1
  fi

  local name="$1"

  # Check if bookmark file exists
  if [[ ! -f "${BOOKMARK_FILE}" ]]; then
    echo "No bookmarks found."
    return 1
  fi

  # Check if bookmark exists
  if ! grep -q "^${name}:" "${BOOKMARK_FILE}"; then
    echo "Bookmark '${name}' does not exist."
    return 1
  fi

  # Remove bookmark
  if [[ "${DOTFILES_OS}" == "Darwin"* ]]; then
    # macOS version of sed
    sed -i '' "/^${name}:/d" "${BOOKMARK_FILE}"
  else
    # Linux version
    sed -i "/^${name}:/d" "${BOOKMARK_FILE}"
  fi

  echo "Bookmark '${name}' removed"
}

# Go to bookmark
goto() {
  if [ -z "$1" ]; then
    echo "Usage: goto <bookmark_name>"
    # Just show usage without listing bookmarks to avoid platform-specific issues
    echo "Use 'bml' or 'bookmark_list' to see available bookmarks"
    return 1
  fi

  local name="$1"

  # Check if bookmark file exists
  if [[ ! -f "${BOOKMARK_FILE}" ]]; then
    echo "No bookmarks found."
    return 1
  fi

  # Get bookmark path
  local dir
  dir=$(grep "^${name}:" "${BOOKMARK_FILE}" | cut -d':' -f2)

  if [[ -z "${dir}" ]]; then
    echo "Bookmark '${name}' not found."
    return 1
  fi

  # Validate directory before navigation
  if [[ ! -d "${dir}" ]]; then
    echo "Error: Bookmarked directory '${dir}' no longer exists"
    echo "Please update or remove this bookmark."
    return 1
  fi

  if [[ ! -r "${dir}" ]] || [[ ! -x "${dir}" ]]; then
    echo "Error: Bookmarked directory '${dir}' is inaccessible"
    echo "Please update or remove this bookmark."
    return 1
  fi

  # Navigate to the bookmark
  cd_with_history "${dir}"
}
