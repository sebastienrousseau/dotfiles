# shellcheck shell=bash
# Nmap Scanning Aliases
[[ -n "${_NMAP_SCANNING_LOADED:-}" ]] && return 0
_NMAP_SCANNING_LOADED=1

alias nms='nmap -sS'
alias nma='nmap -A'
alias nmv='nmap -sV'
alias nmo='nmap -O'
alias nmp='nmap -Pn'
alias nmfast='nmap -F'
alias nmping='nmap -sn'

function nmscript() {
  [[ -z "$1" || -z "$2" ]] && {
    echo "Usage: nmscript <script_name> <target>"
    return 1
  }
  nmap --script "$1" "$2"
}

alias nmvuln='nmap --script vuln'
alias nmall='nmap -A -T4 -p-'
