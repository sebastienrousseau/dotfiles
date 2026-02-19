# shellcheck shell=bash
# SSH Tunnels & Forwarding
[[ -n "${_SSH_TUNNELS_LOADED:-}" ]] && return 0
_SSH_TUNNELS_LOADED=1

function sshtunl() {
  [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]] && {
    echo "Usage: sshtunl <local_port> <host> <remote_port> <ssh_host>"
    echo "Example: sshtunl 8080 127.0.0.1 80 user@server"
    return 1
  }
  ssh -L "$1:$2:$3" "$4"
}

function sshtunr() {
  [[ -z "$1" || -z "$2" || -z "$3" || -z "$4" ]] && {
    echo "Usage: sshtunr <remote_port> <host> <local_port> <ssh_host>"
    echo "Example: sshtunr 8080 127.0.0.1 80 user@server"
    return 1
  }
  ssh -R "$1:$2:$3" "$4"
}

function sshtund() {
  [[ -z "$1" ]] && {
    echo "Usage: sshtund <ssh_host>"
    return 1
  }
  ssh -D 8080 "$1"
}

function sshtunnel() {
  [[ -z "$1" || -z "$2" || -z "$3" ]] && {
    echo "Usage: sshtunnel <local_port> <remote_port> <ssh_host>"
    echo "Example: sshtunnel 8000 8080 user@server"
    return 1
  }
  ssh -N -L "$1:localhost:$2" "$3"
}
