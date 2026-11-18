# YubiKey FIDO2/U2F security key helper
if [[ -x /usr/lib/ssh/ssh-sk-helper ]]; then
  export SSH_SK_HELPER=/usr/lib/ssh/ssh-sk-helper
fi

# SSH agent: when no agent is set (interactive only), reuse one agent per
# host on a fixed socket, starting it only when that socket is not live.
# A bare `ssh-agent -s` here started, and leaked, a new agent in every
# shell. Agents started any other way are never touched.
_dotfiles_ssh_agent() {
  local dir="${XDG_RUNTIME_DIR:-$HOME/.ssh}"
  local sock="$dir/dotfiles-ssh-agent.${HOST%%.*}.sock"
  # ssh-add exits 2 only when it cannot reach an agent.
  SSH_AUTH_SOCK="$sock" ssh-add -l >/dev/null 2>&1
  if (( $? != 2 )); then
    export SSH_AUTH_SOCK="$sock"
    return 0
  fi
  [[ -d "$dir" ]] || mkdir -m 700 -p "$dir" || return 0
  # A socket nothing answers on is left over from an agent that exited.
  [[ -S "$sock" ]] && rm -f -- "$sock"
  eval "$(ssh-agent -s -a "$sock" 2>/dev/null)" >/dev/null
  [[ -S "$sock" ]] || return 0
  export SSH_AUTH_SOCK="$sock"

  # Add default key with timeout guard (2s max) to prevent startup hangs
  if [[ -f ~/.ssh/id_ed25519 ]]; then
    if [[ "$OSTYPE" == darwin* ]]; then
      timeout 2 ssh-add --apple-use-keychain ~/.ssh/id_ed25519 2>/dev/null || true
    else
      timeout 2 ssh-add ~/.ssh/id_ed25519 2>/dev/null || true
    fi
  fi
}

if [[ -o interactive ]] && [[ -z "$SSH_AUTH_SOCK" ]] && (( ${+commands[ssh-agent]} )); then
  _dotfiles_ssh_agent
fi
