#!/usr/bin/env bash
# Dotfiles CLI - Meta Commands
# upgrade, docs, learn, keys, sandbox

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

cmd_upgrade() {
  local src_dir
  src_dir="$(require_source_dir)"

  if [ -f "$src_dir/nix/flake.nix" ] && has_command nix; then
    echo "Updating Nix flake..."
    (cd "$src_dir" && nix flake update) || true
    echo "Running Nix garbage collection..."
    nix-collect-garbage -d || true
  fi

  echo "Updating dotfiles..."
  chezmoi update || true

  if has_command nvim; then
    echo "Updating Neovim plugins..."
    nvim --headless "+Lazy! sync" +qa || true
  fi

  if [ "${DOTFILES_FONTS:-}" = "1" ]; then
    if [ -f "$src_dir/scripts/fonts/install-nerd-fonts.sh" ]; then
      echo "Installing Nerd Fonts..."
      sh "$src_dir/scripts/fonts/install-nerd-fonts.sh"
    fi
  fi
}

cmd_docs() {
  local src_dir
  src_dir="$(resolve_source_dir)"

  if [ -n "$src_dir" ] && [ -f "$src_dir/README.md" ]; then
    exec cat "$src_dir/README.md"
  else
    die "README not found."
  fi
}

cmd_learn() {
  local dot_bin
  dot_bin="$(dirname "${BASH_SOURCE[0]}")/../../../dot_local/bin"
  if [ -f "$dot_bin/executable_tour" ]; then
    exec bash "$dot_bin/executable_tour" "$@"
  fi
  # Fallback to PATH
  exec tour "$@"
}

cmd_keys() {
  local src_dir
  src_dir="$(resolve_source_dir)"

  if [ -n "$src_dir" ] && [ -f "$src_dir/docs/KEYS.md" ]; then
    if [ -n "$1" ]; then
      rg -i --fixed-strings --context 1 "$1" "$src_dir/docs/KEYS.md" || true
    else
      exec cat "$src_dir/docs/KEYS.md"
    fi
  else
    die "Keybindings catalog not found."
  fi
}

cmd_sandbox() {
  local src_dir
  src_dir="$(require_source_dir)"

  if has_command docker; then
    echo "Launching sandbox via Docker..."
    docker build -f "$src_dir/tests/Dockerfile.sandbox" -t dotfiles-sandbox "$src_dir"
    exec docker run --rm -it dotfiles-sandbox
  elif has_command podman; then
    echo "Launching sandbox via Podman..."
    podman build -f "$src_dir/tests/Dockerfile.sandbox" -t dotfiles-sandbox "$src_dir"
    exec podman run --rm -it dotfiles-sandbox
  else
    die "Docker or Podman is required for sandbox."
  fi
}

# Dispatch
case "${1:-}" in
  upgrade) shift; cmd_upgrade "$@" ;;
  docs) shift; cmd_docs "$@" ;;
  learn) shift; cmd_learn "$@" ;;
  keys) shift; cmd_keys "$@" ;;
  sandbox) shift; cmd_sandbox "$@" ;;
  *) echo "Unknown meta command: ${1:-}" >&2; exit 1 ;;
esac
