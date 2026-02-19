# shellcheck shell=bash

# Function: dothelp
# Description: Smart search for dotfiles aliases and functions
# Usage: dothelp [search_term]

dothelp() {
  local search_term="$1"
  local config_dir="$HOME/.config/shell"

  if [[ -z "$search_term" ]]; then
    echo "Usage: dothelp [search_term]"
    echo "Example: dothelp git"
    return 1
  fi

  echo "Searching dotfiles for '$search_term'..."
  echo "----------------------------------------"

  # Search in aliases and functions files
  if command -v rg &>/dev/null; then
    rg --color=always --line-number --no-heading "$search_term" "$config_dir"
  else
    grep -rn --color=auto "$search_term" "$config_dir"
  fi
}
