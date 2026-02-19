# SSH agent: auto-start and load key from macOS Keychain
if [ -z "$SSH_AUTH_SOCK" ]; then
  eval "$(ssh-agent -s)" > /dev/null
  ssh-add --apple-use-keychain ~/.ssh/id_ed25519 2>/dev/null
fi
