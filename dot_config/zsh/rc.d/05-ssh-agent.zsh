# SSH agent: auto-start and load key
# Only runs when SSH_AUTH_SOCK is unset (no agent running)

if [[ -z "$SSH_AUTH_SOCK" ]]; then
  eval "$(ssh-agent -s)" > /dev/null

  # Determine SSH key path (configurable via env)
  : ${DOTFILES_SSH_KEY:="${HOME}/.ssh/id_ed25519"}

  if [[ -f "$DOTFILES_SSH_KEY" ]]; then
    case "$(uname -s)" in
      Darwin)
        # macOS: use Keychain for passphrase storage
        ssh-add --apple-use-keychain "$DOTFILES_SSH_KEY" 2>/dev/null || \
          ssh-add "$DOTFILES_SSH_KEY" 2>/dev/null
        ;;
      Linux)
        # Linux: standard ssh-add
        ssh-add "$DOTFILES_SSH_KEY" 2>/dev/null
        ;;
    esac
  fi
fi
