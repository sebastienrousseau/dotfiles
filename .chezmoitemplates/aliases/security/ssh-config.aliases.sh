# shellcheck shell=bash
# SSH Configuration & Connections
[[ -n "${_SSH_CONFIG_LOADED:-}" ]] && return 0
_SSH_CONFIG_LOADED=1

alias sshedit='${EDITOR:-vi} ~/.ssh/config'
alias sshconfig='cat ~/.ssh/config'
alias sshls='grep "^Host " ~/.ssh/config | sed "s/Host //"'
alias sshcheck='ssh -T git@github.com'
alias sshv='ssh -v'
alias sshvv='ssh -vv'
alias sshvvv='ssh -vvv'
alias sshkeyaudit='ssh-audit' # 3rd-party tool
alias sshscan='nmap -p 22 --script ssh-auth-methods'
