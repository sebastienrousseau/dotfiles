#!/bin/sh
set -e

if [ "${DOTFILES_FIREWALL:-}" != "1" ]; then
  echo "Firewall script is disabled by default."
  echo "Re-run with DOTFILES_FIREWALL=1 to apply."
  exit 1
fi

case "$(uname -s)" in
  Darwin)
    echo "Enabling macOS firewall..."
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsigned on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setallowsignedapp on
    sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setstealthmode on
    ;;
  Linux)
    if command -v ufw >/dev/null; then
      echo "Enabling UFW..."
      sudo ufw default deny incoming
      sudo ufw default allow outgoing
      sudo ufw allow OpenSSH
      sudo ufw --force enable
    else
      echo "ufw not installed. Install ufw and re-run."
      exit 1
    fi
    ;;
  *)
    echo "Unsupported OS for firewall setup."
    exit 1
    ;;
esac
