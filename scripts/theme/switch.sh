#!/bin/sh
set -e

resolve_source_dir() {
  if [ -n "${CHEZMOI_SOURCE_DIR:-}" ] && [ -d "$CHEZMOI_SOURCE_DIR" ]; then
    echo "$CHEZMOI_SOURCE_DIR"
    return
  fi
  if [ -d "$HOME/.dotfiles" ]; then
    echo "$HOME/.dotfiles"
    return
  fi
  if [ -d "$HOME/.local/share/chezmoi" ]; then
    echo "$HOME/.local/share/chezmoi"
    return
  fi
  echo ""
}

SRC_DIR="$(resolve_source_dir)"
if [ -z "$SRC_DIR" ]; then
  echo "Dotfiles source not found."
  exit 1
fi

DATA_FILE="$SRC_DIR/.chezmoidata.toml"
if [ ! -f "$DATA_FILE" ]; then
  echo "Missing $DATA_FILE"
  exit 1
fi

current_theme() {
  awk -F'"' '/^theme =/ {print $2}' "$DATA_FILE" | head -n 1
}

set_theme() {
  new_theme="$1"
  if [ -z "$new_theme" ]; then
    echo "Theme name required."
    exit 1
  fi
  # Validate theme name: only allow alphanumeric, hyphens, underscores
  case "$new_theme" in
    *[!a-zA-Z0-9_-]*)
      echo "Invalid theme name: $new_theme" >&2
      echo "Theme names may only contain letters, digits, hyphens, and underscores." >&2
      exit 1
      ;;
  esac
  tmp_file="$(mktemp)"
  if grep -q '^theme = ' "$DATA_FILE"; then
    sed "s/^theme = .*/theme = \"$new_theme\"/" "$DATA_FILE" >"$tmp_file"
  else
    cat "$DATA_FILE" >"$tmp_file"
    echo "theme = \"$new_theme\"" >>"$tmp_file"
  fi
  mv "$tmp_file" "$DATA_FILE"
  echo "Theme set to: $new_theme"
  echo "Applying dotfiles..."
  chezmoi apply
}

list_themes() {
  cat <<'THEMES'
catppuccin-latte
catppuccin-mocha
tokyonight-day
tokyonight-storm
tokyonight-night
tokyonight-moon
dracula
gruvbox-light
gruvbox-dark
nord
onelight
onedark
solarized-light
solarized-dark
rose-pine
rose-pine-moon
rose-pine-dawn
everforest-dark
everforest-light
kanagawa-wave
kanagawa-dragon
kanagawa-lotus
THEMES
}

case "${1:-}" in
  list)
    list_themes
    ;;
  set)
    shift
    set_theme "$1"
    ;;
  toggle)
    current="$(current_theme)"
    best_dark="tokyonight-night"
    best_light="tokyonight-day"
    case "$current" in
      catppuccin-mocha | tokyonight-night | tokyonight-storm | tokyonight-moon | dracula | gruvbox-dark | nord | onedark | solarized-dark | rose-pine | rose-pine-moon | everforest-dark | kanagawa-wave | kanagawa-dragon)
        set_theme "$best_light"
        ;;
      *)
        set_theme "$best_dark"
        ;;
    esac
    ;;
  "")
    echo "Usage: dot theme [list|set <name>|toggle]"
    ;;
  *)
    echo "Unknown theme command: $1"
    echo "Usage: dot theme [list|set <name>|toggle]"
    exit 1
    ;;
esac
