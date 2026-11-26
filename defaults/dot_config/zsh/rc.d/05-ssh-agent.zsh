# YubiKey FIDO2/U2F security key helper
if [[ -x /usr/lib/ssh/ssh-sk-helper ]]; then
  export SSH_SK_HELPER=/usr/lib/ssh/ssh-sk-helper
fi

# SSH agent: when no agent is set (interactive only), reuse one agent per
# host on a fixed socket, starting it only when that socket is not live.
# A bare `ssh-agent -s` here started, and leaked, a new agent in every
# shell. Agents started any other way are never touched.
_dotfiles_ssh_agent() {
  local dir="${XDG_RUNTIME_DIR:-$HOME/.ssh}" host="${HOST%%.*}"
  # Unix socket paths are capped at 104 bytes (macOS) or 108 (Linux), and
  # managed hosts can have long names: keep the name short, and move to a
  # private directory under /tmp when the home path itself is too long.
  local sock="$dir/dotfiles-ssh-agent.${host[1,16]}.sock"
  if (( ${#sock} > 100 )); then
    dir="/tmp/dotfiles-ssh-$UID"
    sock="$dir/agent.${host[1,16]}.sock"
  fi
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

  # Add default key with timeout guard (2s max) to prevent startup hangs.
  # timeout(1) where installed; else perl's alarm, since macOS before 27
  # ships no timeout(1) and the key was silently never added there. No
  # output is kept: a child left behind must not hold the shell's stdout.
  if [[ -f ~/.ssh/id_ed25519 ]]; then
    local -a add=(ssh-add)
    [[ "$OSTYPE" == darwin* ]] && add+=(--apple-use-keychain)
    if (( ${+commands[timeout]} )); then
      timeout 2 "${add[@]}" ~/.ssh/id_ed25519 >/dev/null 2>&1 || true
    else
      perl -e 'alarm shift; exec @ARGV or exit 127' 2 "${add[@]}" ~/.ssh/id_ed25519 >/dev/null 2>&1 || true
    fi
  fi
}

if [[ -o interactive ]] && [[ -z "$SSH_AUTH_SOCK" ]] && (( ${+commands[ssh-agent]} )); then
  _dotfiles_ssh_agent
fi
