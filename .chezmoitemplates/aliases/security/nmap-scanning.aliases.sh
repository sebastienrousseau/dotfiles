# shellcheck shell=bash
# Nmap Scanning Aliases
[[ -n "${_NMAP_SCANNING_LOADED:-}" ]] && return 0
_NMAP_SCANNING_LOADED=1
command -v nmap >/dev/null 2>&1 || return 0

# NOTE:
# Nmap aliases were consolidated into `system/system.aliases.sh`
# so runtime diagnostics aliases live in a single module.

function nmscript() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "Usage: nmscript <script_name> <target>"
    return 1
  }
  nmap --script "$1" "$2"
}
