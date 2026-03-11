# shellcheck shell=bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# 🆄🆄🅸🅳 🅰🅻🅸🅰🆂🅴🆂

# uuid: Generate a UUID and copy it to the clipboard.
uuid_copy() {
  local value=""
  if command -v uuidgen >/dev/null 2>&1; then
    value="$(uuidgen | tr -d '\n' | tr '[:upper:]' '[:lower:]')"
  elif command -v uuid >/dev/null 2>&1; then
    value="$(uuid | tr -d '\n' | tr '[:upper:]' '[:lower:]')"
  else
    echo "uuid/uuidgen not available" >&2
    return 1
  fi

  # Copy to clipboard and echo the value
  if command -v cb >/dev/null 2>&1; then
    printf "%s" "$value" | cb
    printf "%s\n" "$value"
  elif command -v pbcopy >/dev/null 2>&1; then
    printf "%s" "$value" | pbcopy
    printf "%s\n" "$value"
  elif command -v clip.exe >/dev/null 2>&1; then
    printf "%s" "$value" | clip.exe
    printf "%s\n" "$value"
  elif command -v wl-copy >/dev/null 2>&1; then
    printf "%s" "$value" | wl-copy
    printf "%s\n" "$value"
  elif command -v xclip >/dev/null 2>&1; then
    printf "%s" "$value" | xclip -selection clipboard
    printf "%s\n" "$value"
  else
    printf "%s\n" "$value"
  fi
  return 0
}
alias uuid='uuid_copy'
