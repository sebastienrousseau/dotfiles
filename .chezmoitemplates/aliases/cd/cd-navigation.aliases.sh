# shellcheck shell=bash
# CD Navigation - Project Navigation and Last Working Directory
[[ -n "${_CD_NAVIGATION_LOADED:-}" ]] && return 0
_CD_NAVIGATION_LOADED=1

# Find and navigate to project root (git, npm, etc.)
proj() {
  local dir="${PWD}"
  local markers=(".git" "package.json" "Makefile" "CMakeLists.txt" "pom.xml" "build.gradle" "requirements.txt" "setup.py" "Cargo.toml")

  while [[ "${dir}" != "/" ]]; do
    for marker in "${markers[@]}"; do
      if [[ -d "${dir}/${marker}" ]] || [[ -f "${dir}/${marker}" ]]; then
        cd_with_history "${dir}"
        echo "Found project root: ${dir} (marker: ${marker})"
        return 0
      fi
    done
    dir=$(dirname "${dir}")
  done

  echo "No project root found."
  return 1
}

# Restore last working directory
lwd() {
  if [[ -f "${LAST_DIR_FILE}" ]]; then
    local last_dir
    last_dir=$(cat "${LAST_DIR_FILE}")

    if [[ ! -d "${last_dir}" ]] || [[ ! -r "${last_dir}" ]] || [[ ! -x "${last_dir}" ]]; then
      echo "Last working directory no longer exists or is inaccessible."
      return 1
    fi

    cd_with_history "${last_dir}"
  else
    echo "No last working directory saved."
    return 1
  fi
}
