#!/bin/sh
set -e

case "$(uname -s)" in
  Darwin)
    if command -v fdesetup >/dev/null; then
      status=$(fdesetup status || true)
      echo "$status"
      echo "$status" | grep -qi "FileVault is On" && exit 0
      echo "Warning: FileVault appears to be off."
      exit 1
    else
      echo "fdesetup not found."
      exit 1
    fi
    ;;
  Linux)
    if command -v lsblk >/dev/null; then
      if lsblk -f | rg -i "crypto|luks" >/dev/null; then
        echo "Encrypted block device detected (LUKS)."
        exit 0
      fi
      echo "Warning: No LUKS/crypto volume detected."
      exit 1
    fi
    ;;
  *)
    echo "Unsupported OS for encryption check."
    exit 1
    ;;
esac
