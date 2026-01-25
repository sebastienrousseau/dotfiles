#!/bin/sh
set -e

if [ "${DOTFILES_DOH:-}" != "1" ]; then
  echo "DoH script is disabled by default."
  echo "Re-run with DOTFILES_DOH=1 to apply."
  exit 1
fi

case "$(uname -s)" in
  Linux)
    if command -v resolvectl >/dev/null; then
      echo "Enabling DNS-over-HTTPS with systemd-resolved (Cloudflare)..."
      sudo resolvectl dns-over-https on
      sudo resolvectl dns 1.1.1.1 1.0.0.1
    else
      echo "systemd-resolved not detected."
      exit 1
    fi
    ;;
  Darwin)
    echo "Configure DoH in your browser (system-wide DoH requires profiles)."
    exit 0
    ;;
  *)
    echo "Unsupported OS for DoH config."
    exit 1
    ;;
esac
