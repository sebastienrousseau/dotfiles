#!/usr/bin/env bash
# Copyright (c) 2015-2026 . All rights reserved.
# Create an offline bundle of the dotfiles environment for air-gapped systems.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/dot/lib/ui.sh"

OUTPUT_DIR="${1:-$HOME/Downloads}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BUNDLE_FILE="$OUTPUT_DIR/dotfiles_offline_bundle_$TIMESTAMP.tar.zst"

ui_header "Creating Offline Bundle (Zero-Network Mode)"

# Ensure target directory exists
mkdir -p "$OUTPUT_DIR"

ui_info "Gathering artifacts..."
# We use zstd for much faster compression of binary artifacts compared to gzip/xz
if ! command -v tar >/dev/null || ! command -v zstd >/dev/null; then
  ui_err "tar and zstd are required for bundling."
  exit 1
fi

# Define paths to bundle
declare -a paths_to_bundle=(
  "$HOME/.dotfiles"
  "$HOME/.config/chezmoi"
  "$HOME/.local/share/mise"
)

# Optional: Add nix store if present and requested
if [[ -d "/nix/store" ]] && [[ "${DOTFILES_BUNDLE_NIX:-0}" == "1" ]]; then
  ui_warn "Including Nix store. This will be very large."
  paths_to_bundle+=("/nix/store" "/nix/var/nix" "$HOME/.nix-profile")
fi

# Filter only existing paths
declare -a valid_paths=()
for p in "${paths_to_bundle[@]}"; do
  if [[ -e "$p" ]]; then
    valid_paths+=("$p")
    ui_bullet "Adding: $p"
  fi
done

ui_info "Compressing artifacts (this may take a while)..."
# Use absolute paths and store them relative to / to preserve structure
tar --zstd -cf "$BUNDLE_FILE" -P "${valid_paths[@]}" 2>/dev/null || {
  ui_err "Failed to create bundle."
  exit 1
}

ui_ok "Bundle created" "$BUNDLE_FILE"
ui_info "To restore on an offline machine:"
ui_bullet "tar --zstd -xf $BUNDLE_FILE -P"
ui_bullet "cd ~/.dotfiles && ./install.sh --force"
