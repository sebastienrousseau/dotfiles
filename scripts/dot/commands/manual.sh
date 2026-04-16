#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# dot manual — open or download the dotfiles manual in multiple formats.
#
# Usage:
#   dot manual                   # open HTML manual in browser
#   dot manual html              # alias of no-arg
#   dot manual pdf               # download + open PDF
#   dot manual epub              # download + open EPUB
#   dot manual text              # pipe ASCII text to pager
#   dot manual markdown          # pipe Markdown source to pager
#   dot manual download <fmt>    # save to current directory
#   dot manual --offline         # use bundled offline copy
#   dot manual --local           # use locally-built _build/manual/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/utils.sh
source "$SCRIPT_DIR/../lib/utils.sh"

MANUAL_URL="${DOTFILES_MANUAL_URL:-https://sebastienrousseau.github.io/dotfiles/manual}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles/manual"
OFFLINE_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles/manual"

MODE="open"
FORMAT="html"
USE_LOCAL=false
USE_OFFLINE=false

for arg in "$@"; do
  case "$arg" in
    html|html-multi|pdf|epub|text|markdown) FORMAT="$arg" ;;
    download) MODE="download" ;;
    --offline) USE_OFFLINE=true ;;
    --local) USE_LOCAL=true ;;
    --url=*) MANUAL_URL="${arg#*=}" ;;
    --help|-h)
      sed -n 's/^# //p;s/^#$//p' "$0" | head -20
      exit 0
      ;;
  esac
done

format_file() {
  case "$1" in
    html) echo "dotfiles.html" ;;
    html-multi) echo "html/index.html" ;;
    pdf) echo "dotfiles.pdf" ;;
    epub) echo "dotfiles.epub" ;;
    text) echo "dotfiles.txt" ;;
    markdown) echo "dotfiles-md.tar.gz" ;;
    *) return 1 ;;
  esac
}

resolve_source() {
  local fmt="$1"
  local fname
  fname="$(format_file "$fmt")"

  if $USE_LOCAL; then
    local src_dir
    src_dir="$(require_source_dir)/_build/manual"
    if [[ -f "$src_dir/$fname" ]]; then
      echo "$src_dir/$fname"
      return 0
    fi
    ui_err "manual" "local build not found at $src_dir/$fname — run bash scripts/docs/build-manual.sh"
    return 1
  fi

  if $USE_OFFLINE; then
    if [[ -f "$OFFLINE_DIR/$fname" ]]; then
      echo "$OFFLINE_DIR/$fname"
      return 0
    fi
    ui_err "manual" "offline copy not found at $OFFLINE_DIR/$fname"
    return 1
  fi

  local cache_path="$CACHE_DIR/$fname"
  if [[ ! -f "$cache_path" ]] || [[ $(find "$cache_path" -mtime +7 -print 2>/dev/null | wc -l) -gt 0 ]]; then
    mkdir -p "$(dirname "$cache_path")"
    local url="$MANUAL_URL/$fname"
    ui_info "manual" "fetching $url"
    if ! curl -fsSL "$url" -o "$cache_path"; then
      ui_err "manual" "failed to download $url"
      return 1
    fi
  fi
  echo "$cache_path"
}

open_file() {
  local path="$1"
  case "$(uname -s)" in
    Darwin)
      # Use the system open explicitly — ~/.local/bin/open is a wrapper
      # that would recurse on itself.
      /usr/bin/open "$path"
      ;;
    Linux)
      if command -v xdg-open &>/dev/null; then
        xdg-open "$path"
      elif command -v gio &>/dev/null; then
        gio open "$path"
      else
        ui_err "manual" "no opener found (xdg-open, gio); use file://$path"
        return 1
      fi
      ;;
    *)
      ui_info "manual" "saved to: $path"
      ;;
  esac
}

cmd_open() {
  local path
  path="$(resolve_source "$FORMAT")"
  [[ -z "$path" ]] && exit 1

  case "$FORMAT" in
    text)
      ${PAGER:-less} "$path"
      ;;
    markdown)
      local tmpdir
      tmpdir="$(mktemp -d)"
      tar -xzf "$path" -C "$tmpdir"
      ui_info "manual" "Markdown source extracted to: $tmpdir"
      open_file "$tmpdir" 2>/dev/null || true
      ;;
    html)
      if ! $USE_LOCAL && ! $USE_OFFLINE; then
        open_file "$MANUAL_URL/"
      else
        open_file "$path"
      fi
      ;;
    html-multi)
      if ! $USE_LOCAL && ! $USE_OFFLINE; then
        open_file "$MANUAL_URL/html/"
      else
        open_file "$path"
      fi
      ;;
    *)
      open_file "$path"
      ;;
  esac
}

cmd_download() {
  local path
  path="$(resolve_source "$FORMAT")"
  [[ -z "$path" ]] && exit 1
  local dest
  dest="./$(basename "$path")"
  cp "$path" "$dest"
  ui_ok "manual" "saved: $dest"
}

case "$MODE" in
  open) cmd_open ;;
  download) cmd_download ;;
esac
