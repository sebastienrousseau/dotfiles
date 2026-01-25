#!/bin/sh
set -e

KEY_PATH="${1:-$HOME/.ssh/id_ed25519}"
OUT_FILE="${2:-$HOME/.config/chezmoi/encrypted_id_ed25519.age}"
KEYRING_DIR="$HOME/.config/chezmoi"
AGE_KEY="$KEYRING_DIR/key.txt"

if [ ! -f "$KEY_PATH" ]; then
  echo "SSH key not found: $KEY_PATH"
  exit 1
fi

if [ ! -f "$AGE_KEY" ]; then
  echo "Age identity not found: $AGE_KEY"
  echo "Run: dot secrets-init"
  exit 1
fi

if ! command -v age >/dev/null; then
  echo "age not found. Install it first."
  exit 1
fi

recipient="$(age-keygen -y "$AGE_KEY")"
mkdir -p "$(dirname "$OUT_FILE")"

if [ -f "$OUT_FILE" ]; then
  echo "Encrypted file already exists: $OUT_FILE"
  exit 0
fi

age -R <(printf "%s" "$recipient") -o "$OUT_FILE" "$KEY_PATH"
chmod 600 "$OUT_FILE"

cat <<MSG
Encrypted SSH key written to:
  $OUT_FILE

This file is local only. If you want to track it in dotfiles, run:
  chezmoi add --encrypt $OUT_FILE
MSG
