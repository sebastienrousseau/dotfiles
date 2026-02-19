# shellcheck shell=bash
# SSH Key Management
[[ -n "${_SSH_KEYS_LOADED:-}" ]] && return 0
_SSH_KEYS_LOADED=1

function sshkeyed25519() {
  [[ -z "$1" ]] && {
    echo "Usage: sshkeyed25519 <comment/email>"
    return 1
  }
  ssh-keygen -t ed25519 -C "$1"
}

function sshkeyrsa() {
  [[ -z "$1" ]] && {
    echo "Usage: sshkeyrsa <comment/email>"
    return 1
  }
  ssh-keygen -t rsa -b 4096 -C "$1"
}

alias sshkeylist='ls -la ~/.ssh'
alias sshkeycp='ssh-copy-id'
alias sshagent='eval "$(ssh-agent -s)" && ssh-add'
alias sshagentls='ssh-add -l'
alias sshagentdel='ssh-add -d'
alias sshagentdelall='ssh-add -D'

# Security Checks
function sshfp() {
  [[ -z "$1" ]] && {
    echo "Usage: sshfp <key_file>"
    return 1
  }
  ssh-keygen -l -f "$1"
}

function sshfpsha256() {
  [[ -z "$1" ]] && {
    echo "Usage: sshfpsha256 <key_file>"
    return 1
  }
  ssh-keygen -l -E sha256 -f "$1"
}
