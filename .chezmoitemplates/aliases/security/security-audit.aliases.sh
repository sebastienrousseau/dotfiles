# shellcheck shell=bash
# Security Audit Tools (Lynis, Fail2ban)
[[ -n "${_SECURITY_AUDIT_LOADED:-}" ]] && return 0
_SECURITY_AUDIT_LOADED=1

# Lynis
if command -v lynis >/dev/null 2>&1; then
  alias lyna='sudo lynis audit system'
  alias lynr='sudo lynis show reports'
  alias lyns='sudo lynis update info'
  alias lynsu='sudo lynis update release'
fi

# Fail2ban
if command -v fail2ban-client >/dev/null 2>&1; then
  alias f2b='sudo fail2ban-client'
  alias f2bs='sudo fail2ban-client status'
  alias f2bsa='sudo fail2ban-client status all'
  alias f2bssh='sudo fail2ban-client status sshd'
  alias f2br='sudo fail2ban-client reload'

  function f2bunban() {
    [[ -z "$1" ]] && {
      echo "Usage: f2bunban <IP>"
      return 1
    }
    sudo fail2ban-client unban "$1"
  }
fi
