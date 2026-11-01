#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Create an offline bundle of the dotfiles environment for air-gapped systems.

set -euo pipefail

_cleanup_files=()
trap 'set +u; rm -f "${_cleanup_files[@]}" 2>/dev/null; set -u' EXIT

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/dot/ui.sh"
# shellcheck disable=SC1091
source "$SCRIPT_DIR/../lib/dot/log.sh"
export DOT_COMMAND="bundle"

usage() {
  cat <<'EOF'
Usage: bundle.sh [output-dir]

Create an offline dotfiles bundle as a .tar.zst archive.
EOF
}

case "${1:-}" in
  --help | -h)
    usage
    exit 0
    ;;
  -*)
    printf 'Unknown option: %s\n' "$1" >&2
    usage >&2
    exit 2
    ;;
esac

# Concurrency guard
LOCK_DIR="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}"
if [[ ! -d "$LOCK_DIR" || ! -w "$LOCK_DIR" ]]; then
  LOCK_DIR="${TMPDIR:-/tmp}"
fi
LOCK_FILE="$LOCK_DIR/dotfiles-bundle.lock"
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_FILE"
  if ! flock -n 9; then
    ui_warn "Already running" "Another bundle instance is active"
    exit 0
  fi
fi

OUTPUT_DIR="${1:-$HOME/Downloads}"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BUNDLE_FILE="$OUTPUT_DIR/dotfiles_offline_bundle_$TIMESTAMP.tar.zst"

dot_log info "bundle_start"
ui_header "Creating Offline Bundle (Zero-Network Mode)"

# Ensure target directory exists
mkdir -p "$OUTPUT_DIR"

ui_info "Gathering artifacts..."
# We use zstd for much faster compression of binary artifacts compared to gzip/xz
if ! command -v tar >/dev/null || ! command -v zstd >/dev/null; then
  ui_err "tar and zstd are required for bundling."
  exit 1
fi

# Define paths to bundle: the checkout is the one the shells export as
# DOTFILES_DIR, wherever it lives.
declare -a paths_to_bundle=(
  "${DOTFILES_DIR:-$HOME/.dotfiles}"
  "$HOME/.config/chezmoi"
  "$HOME/.local/share/mise"
)

# Optional: Add nix store if present and requested
if [[ -d "/nix/store" ]] && [[ "${DOTFILES_BUNDLE_NIX:-0}" == "1" ]]; then
  ui_warn "Including Nix store. This will be very large."
  paths_to_bundle+=("/nix/store" "/nix/var/nix" "$HOME/.nix-profile")
fi

# _existing_paths: fill valid_paths with the paths_to_bundle that exist.
_existing_paths() {
  local p
  valid_paths=()
  for p in "${paths_to_bundle[@]}"; do
    if [[ -e "$p" ]]; then
      valid_paths+=("$p")
      ui_bullet "Adding: $p"
    fi
  done
}

# _age_keys: fill keys with the age identities in chezmoi's config. They
# stay out of the bundle: whoever holds the archive could decrypt every
# secret in it. A file with an AGE-SECRET-KEY line is one, whatever its
# name; the user carries it to the offline host separately.
_age_keys() {
  local f
  keys=()
  [[ -d "$HOME/.config/chezmoi" ]] || return 0
  while IFS= read -r -d '' f; do
    if grep -q '^AGE-SECRET-KEY-' "$f" 2>/dev/null; then keys+=("$f"); fi
  done < <(find "$HOME/.config/chezmoi" ! -type d -print0)
}

# _bundle_tar: archive valid_paths to BUNDLE_FILE without the keys. Paths
# are absolute and stored relative to / to preserve the structure.
_bundle_tar() {
  local f
  local -a excludes=()
  for f in ${keys[@]+"${keys[@]}"}; do excludes+=("--exclude=$f"); done
  tar --zstd -cf "$BUNDLE_FILE" -P ${excludes[@]+"${excludes[@]}"} "${valid_paths[@]}" 2>/dev/null
}

# _bundle_report: the bundle's size and path, the keys left out of it, and
# how to restore it.
_bundle_report() {
  local size key
  size=$(stat -c '%s' "$BUNDLE_FILE" 2>/dev/null || stat -f '%z' "$BUNDLE_FILE" 2>/dev/null || echo 0)
  dot_log info "bundle_end" "file=$BUNDLE_FILE"
  dot_metric "bundle_size" "$size" "bytes"
  ui_ok "Bundle created" "$BUNDLE_FILE"
  for key in ${keys[@]+"${keys[@]}"}; do
    ui_warn "Not in the bundle" "$key (your age key): copy it to the offline host yourself to decrypt the secrets there"
  done
  ui_info "To restore on an offline machine:"
  ui_bullet "tar --zstd -xf $BUNDLE_FILE -P"
  ui_bullet "cd ${DOTFILES_DIR:-$HOME/.dotfiles} && ./install.sh --force"
}

declare -a valid_paths=() keys=()
_existing_paths
_age_keys
ui_info "Compressing artifacts (this may take a while)..."
_bundle_tar || {
  ui_err "Failed to create bundle."
  exit 1
}

_bundle_report
