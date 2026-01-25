# shellcheck shell=bash
# rd: Function to remove a directory and its files
rd() {
  if [[ "$#" != 1 ]]; then
    echo "[ERROR] Please add one argument" >&2
    return 1
  fi

  local target="$1"
  local resolved

  # Resolve the actual path
  if [[ -d "$target" ]]; then
    resolved="$(cd "$target" 2>/dev/null && pwd -P)" || {
      echo "[ERROR] Cannot resolve path: $target" >&2
      return 1
    }
  else
    echo "[ERROR] Directory does not exist: $target" >&2
    return 1
  fi

  # Prevent catastrophic deletions
  local dangerous_paths=("/" "$HOME" "/etc" "/usr" "/var" "/opt" "/bin" "/sbin" "/lib" "/tmp" "/root")
  for dangerous in "${dangerous_paths[@]}"; do
    if [[ "$resolved" == "$dangerous" || "$resolved" == "$dangerous/" ]]; then
      echo "[ERROR] Refusing to delete protected path: $resolved" >&2
      return 1
    fi
  done

  # Warn for paths directly under home
  if [[ "$resolved" == "$HOME/"* && "$resolved" != "$HOME/"*/* ]]; then
    echo "[WARNING] About to delete top-level home directory: $resolved"
    read -r -p "Are you sure? [y/N] " confirm
    [[ "$confirm" != [yY]* ]] && { echo "Aborted."; return 1; }
  fi

  rm -rf "$target" || { echo "[ERROR] Failed to delete: $target" >&2; return 1; }
  echo "[INFO] Successfully deleted: $target"
  ls -lh 2>/dev/null || true
}
