# shellcheck shell=bash
# UFW (Uncomplicated Firewall) Aliases
[[ -n "${_UFW_RULES_LOADED:-}" ]] && return 0
_UFW_RULES_LOADED=1
command -v ufw >/dev/null 2>&1 || return 0

# Basic Commands
alias fws='sudo ufw status'
alias fwsv='sudo ufw status verbose'
alias fwsn='sudo ufw status numbered'
alias fwe='sudo ufw enable'
alias fwdis='sudo ufw disable'
alias fwds='sudo ufw default deny incoming'
alias fwda='sudo ufw default allow outgoing'

# Rule Management
function fwallow() {
  [[ -z "$1" ]] && {
    echo "Usage: fwallow <service_or_port>"
    return 1
  }
  sudo ufw allow "$1"
}

function fwallowproto() {
  [[ -z "$1" || -z "$2" || -z "$3" ]] && {
    echo "Usage: fwallowproto <protocol> <from_IP> <to_IP>"
    return 1
  }
  sudo ufw allow proto "$1" from "$2" to "$3"
}

function fwdeny() {
  [[ -z "$1" ]] && {
    echo "Usage: fwdeny <service_or_port>"
    return 1
  }
  sudo ufw deny "$1"
}

function fwdenyproto() {
  [[ -z "$1" || -z "$2" || -z "$3" ]] && {
    echo "Usage: fwdenyproto <protocol> <from_IP> <to_IP>"
    return 1
  }
  sudo ufw deny proto "$1" from "$2" to "$3"
}

function fwdelete() {
  [[ -z "$1" ]] && {
    echo "Usage: fwdelete <rule>"
    return 1
  }
  sudo ufw delete "$1"
}

function fwdeln() {
  [[ -z "$1" ]] && {
    echo "Usage: fwdeln <rule_number>"
    return 1
  }
  sudo ufw delete "$1"
}

function fwlog() {
  [[ -z "$1" ]] && {
    echo "Usage: fwlog <off|low|medium|high|full>"
    return 1
  }
  sudo ufw logging "$1"
}

alias fwreset='sudo ufw reset'

# Common Rules
alias fwassh='sudo ufw allow ssh'
alias fwdssh='sudo ufw deny ssh'
alias fwahttp='sudo ufw allow http'
alias fwahttps='sudo ufw allow https'
alias fwamysql='sudo ufw allow mysql'
alias fwasftp='sudo ufw allow sftp'
alias fwamongo='sudo ufw allow 27017'
alias fwaredis='sudo ufw allow 6379'
alias fwasmtp='sudo ufw allow smtp'
alias fwaimaps='sudo ufw allow imaps'
alias fwapop3s='sudo ufw allow pop3s'
