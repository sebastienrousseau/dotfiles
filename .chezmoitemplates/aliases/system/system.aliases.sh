# shellcheck shell=bash
# System & Runtime Aliases
#
# Consolidated bucket for frequently used process/network/system helpers.

# Shell/runtime helpers
alias h='history'
alias p='pwd'
alias path='echo ${PATH//:/\\n}'
alias wth='curl -s "wttr.in/?format=3"'

# Process helpers
if command -v ps >/dev/null 2>&1; then
  alias pid='ps -f'
  alias ps='ps -ef'
  alias psa='ps aux'
fi

# Network/system helpers
if command -v lsof >/dev/null 2>&1; then
  alias nls='sudo lsof -i -P | grep LISTEN'
  alias op='sudo lsof -i -P'
fi
alias ports='netstat -tulan'
alias top='sudo btop'

# Public IP helper via DNS (kept here for consolidated system diagnostics).
if command -v dig >/dev/null 2>&1; then
  alias wip='dig +short myip.opendns.com @resolver1.opendns.com'
fi

# Font cache refresh (Linux/WSL primarily; safe no-op messaging elsewhere).
alias update-fonts='if command -v fc-cache >/dev/null; then fc-cache -fv; else echo "fc-cache not found (is fontconfig installed?)"; fi'

# Nmap shortcuts (guarded by command availability).
if command -v nmap >/dev/null 2>&1; then
  alias nma='sudo nmap -A'
  alias nmall='nmap -A -T4 -p-'
  alias nmfast='nmap -F'
  alias nmo='nmap -O'
  alias nmp='nmap -Pn'
  alias nmping='nmap -sn'
  alias nms='nmap -sS'
  alias nmv='nmap -sV'
  alias nmvuln='nmap --script vuln'
fi
