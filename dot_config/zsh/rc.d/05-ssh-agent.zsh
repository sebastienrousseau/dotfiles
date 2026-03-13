# YubiKey FIDO2/U2F security key helper
if [[ -x /usr/lib/ssh/ssh-sk-helper ]]; then
  export SSH_SK_HELPER=/usr/lib/ssh/ssh-sk-helper
fi

# SSH agent: auto-start if no agent is running (interactive only)
if [[ -o interactive ]] && [[ -z "$SSH_AUTH_SOCK" ]]; then
  eval "$(ssh-agent -s)" > /dev/null 2>&1

  # Add default key with timeout guard (2s max) to prevent startup hangs
  if [[ -f ~/.ssh/id_ed25519 ]]; then
    if [[ "$OSTYPE" == darwin* ]]; then
      timeout 2 ssh-add --apple-use-keychain ~/.ssh/id_ed25519 2>/dev/null || true
    else
      timeout 2 ssh-add ~/.ssh/id_ed25519 2>/dev/null || true
    fi
  fi
fi
