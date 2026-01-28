#!/usr/bin/env bash
set -euo pipefail

OUT_FILE="${1:-$HOME/.config/chezmoi/encrypted_secrets.env.age}"
KEYRING_DIR="$HOME/.config/chezmoi"
AGE_KEY="$KEYRING_DIR/key.txt"

if [ ! -f "$AGE_KEY" ]; then
  echo "Age identity not found: $AGE_KEY"
  echo "Run: dot secrets-init"
  exit 1
fi

if ! command -v age >/dev/null; then
  echo "age not found. Install it first."
  exit 1
fi

if [ -f "$OUT_FILE" ]; then
  echo "Secrets file already exists: $OUT_FILE"
  exit 0
fi

recipient="$(age-keygen -y "$AGE_KEY")"
mkdir -p "$(dirname "$OUT_FILE")"

tmp_secrets="$(mktemp)" || exit 1
tmp_recipient="$(mktemp)" || exit 1
trap 'rm -f "$tmp_secrets" "$tmp_recipient"' EXIT

printf "%s\n" "# Add secrets as KEY=VALUE" "EXAMPLE_TOKEN=change_me" >"$tmp_secrets"
printf "%s" "$recipient" >"$tmp_recipient"

age -R "$tmp_recipient" -o "$OUT_FILE" "$tmp_secrets"

chmod 600 "$OUT_FILE"

cat <<MSG
Created encrypted secrets file:
  $OUT_FILE

Edit it with:
  dot secrets
MSG
