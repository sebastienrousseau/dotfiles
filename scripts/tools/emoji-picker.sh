#!/usr/bin/env bash
set -euo pipefail

EMOJI_FILE="${EMOJI_FILE:-$HOME/.config/emoji/emoji.txt}"

if [[ ! -f "$EMOJI_FILE" ]]; then
  echo "Emoji list not found: $EMOJI_FILE" >&2
  exit 1
fi

pick_with_fzf() {
  fzf --prompt="emoji> " --height=40% --layout=reverse <"$EMOJI_FILE"
}

pick_with_select() {
  local choice
  local entries
  IFS=$'\n' read -r -d '' -a entries < <(cat "$EMOJI_FILE" && printf '\0')
  select choice in "${entries[@]}"; do
    echo "$choice"
    break
  done
}

selection=""
if command -v fzf >/dev/null; then
  selection=$(pick_with_fzf || true)
else
  selection=$(pick_with_select || true)
fi

emoji=$(printf '%s' "$selection" | awk '{print $1}')
if [[ -z "$emoji" ]]; then
  exit 1
fi

printf '%s' "$emoji"

if command -v pbcopy >/dev/null; then
  printf '%s' "$emoji" | pbcopy
elif command -v wl-copy >/dev/null; then
  printf '%s' "$emoji" | wl-copy
elif command -v xclip >/dev/null; then
  printf '%s' "$emoji" | xclip -selection clipboard
fi
