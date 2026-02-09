#!/bin/sh
# Theme Switcher - Supports Tokyo Night and Catppuccin theme families
# Usage: dot theme [list|set <name>|toggle|family]
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

# =============================================================================
# Theme Database
# =============================================================================

# Default preferences
DEFAULT_DARK="catppuccin-mocha"
DEFAULT_LIGHT="catppuccin-latte"
TOKYO_DARK="tokyonight-night"
TOKYO_LIGHT="tokyonight-day"
CATPPUCCIN_DARK="catppuccin-mocha"
CATPPUCCIN_LIGHT="catppuccin-latte"

# =============================================================================
# Theme Functions
# =============================================================================

current_theme() {
  awk -F'"' '/^theme =/ {print $2}' "$DATA_FILE" | head -n 1
}

get_theme_family() {
  theme="$1"
  case "$theme" in
    tokyonight-*) echo "tokyonight" ;;
    catppuccin-*) echo "catppuccin" ;;
    rose-pine*) echo "rose-pine" ;;
    kanagawa-*) echo "kanagawa" ;;
    gruvbox-*) echo "gruvbox" ;;
    solarized-*) echo "solarized" ;;
    everforest-*) echo "everforest" ;;
    *) echo "other" ;;
  esac
}

is_dark_theme() {
  theme="$1"
  case "$theme" in
    *-night|*-storm|*-moon|*-mocha|*-frappe|*-macchiato|*-dark|*-wave|*-dragon|dracula|nord|onedark)
      return 0 ;;
    *)
      return 1 ;;
  esac
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
  chezmoi apply --force 2>/dev/null || chezmoi apply
}

list_themes() {
  echo "=== Catppuccin (Recommended) ==="
  echo "  catppuccin-latte      (light)"
  echo "  catppuccin-frappe     (dark - muted)"
  echo "  catppuccin-macchiato  (dark - balanced)"
  echo "  catppuccin-mocha      (dark - rich)"
  echo ""
  echo "=== Tokyo Night ==="
  echo "  tokyonight-day        (light)"
  echo "  tokyonight-storm      (dark - muted)"
  echo "  tokyonight-night      (dark - default)"
  echo "  tokyonight-moon       (dark - softer)"
  echo ""
  echo "=== Rose Pine ==="
  echo "  rose-pine             (dark)"
  echo "  rose-pine-moon        (dark - softer)"
  echo "  rose-pine-dawn        (light)"
  echo ""
  echo "=== Kanagawa ==="
  echo "  kanagawa-wave         (dark - default)"
  echo "  kanagawa-dragon       (dark - vibrant)"
  echo "  kanagawa-lotus        (light)"
  echo ""
  echo "=== Other ==="
  echo "  dracula               (dark)"
  echo "  gruvbox-light         (light)"
  echo "  gruvbox-dark          (dark)"
  echo "  nord                  (dark)"
  echo "  onelight              (light)"
  echo "  onedark               (dark)"
  echo "  solarized-light       (light)"
  echo "  solarized-dark        (dark)"
  echo "  everforest-light      (light)"
  echo "  everforest-dark       (dark)"
  echo ""
  echo "Current theme: $(current_theme)"
}

# Toggle between light and dark within the same family, or switch families
toggle_theme() {
  current="$(current_theme)"
  family="$(get_theme_family "$current")"

  if is_dark_theme "$current"; then
    # Currently dark, switch to light variant
    case "$family" in
      tokyonight) set_theme "$TOKYO_LIGHT" ;;
      catppuccin) set_theme "$CATPPUCCIN_LIGHT" ;;
      rose-pine) set_theme "rose-pine-dawn" ;;
      kanagawa) set_theme "kanagawa-lotus" ;;
      gruvbox) set_theme "gruvbox-light" ;;
      solarized) set_theme "solarized-light" ;;
      everforest) set_theme "everforest-light" ;;
      *) set_theme "$DEFAULT_LIGHT" ;;
    esac
  else
    # Currently light, switch to dark variant
    case "$family" in
      tokyonight) set_theme "$TOKYO_DARK" ;;
      catppuccin) set_theme "$CATPPUCCIN_DARK" ;;
      rose-pine) set_theme "rose-pine" ;;
      kanagawa) set_theme "kanagawa-wave" ;;
      gruvbox) set_theme "gruvbox-dark" ;;
      solarized) set_theme "solarized-dark" ;;
      everforest) set_theme "everforest-dark" ;;
      *) set_theme "$DEFAULT_DARK" ;;
    esac
  fi
}

# Switch between Tokyo Night and Catppuccin families
switch_family() {
  current="$(current_theme)"
  family="$(get_theme_family "$current")"

  if is_dark_theme "$current"; then
    # Stay in dark mode, switch family
    case "$family" in
      tokyonight) set_theme "$CATPPUCCIN_DARK" ;;
      catppuccin) set_theme "$TOKYO_DARK" ;;
      *) set_theme "$CATPPUCCIN_DARK" ;;
    esac
  else
    # Stay in light mode, switch family
    case "$family" in
      tokyonight) set_theme "$CATPPUCCIN_LIGHT" ;;
      catppuccin) set_theme "$TOKYO_LIGHT" ;;
      *) set_theme "$CATPPUCCIN_LIGHT" ;;
    esac
  fi
}

# Show current theme info
show_current() {
  current="$(current_theme)"
  family="$(get_theme_family "$current")"
  if is_dark_theme "$current"; then
    mode="dark"
  else
    mode="light"
  fi
  echo "Current: $current ($family, $mode)"
}

# =============================================================================
# Main
# =============================================================================

case "${1:-}" in
  list)
    list_themes
    ;;
  set)
    shift
    set_theme "$1"
    ;;
  toggle)
    toggle_theme
    ;;
  family)
    switch_family
    ;;
  current)
    show_current
    ;;
  "")
    echo "Usage: dot theme [command]"
    echo ""
    echo "Commands:"
    echo "  list      Show all available themes"
    echo "  set NAME  Set theme to NAME"
    echo "  toggle    Toggle between light/dark within current family"
    echo "  family    Switch between Tokyo Night and Catppuccin families"
    echo "  current   Show current theme info"
    echo ""
    show_current
    ;;
  *)
    echo "Unknown theme command: $1"
    echo "Usage: dot theme [list|set <name>|toggle|family|current]"
    exit 1
    ;;
esac
