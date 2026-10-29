#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Restore an offline bundle written by `dot config export` (bundle.sh).
#
# The bundle holds ~/.dotfiles, ~/.config/chezmoi and ~/.local/share/mise
# under their absolute paths. A bundle any member of which lies elsewhere
# (another home, the Nix store, a `..` component) is refused whole. It is
# extracted relative to / without -P, so tar keeps its own guards against
# `..` and extraction through symlinks.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source-path=SCRIPTDIR source=../../lib/dot/ui.sh
source "$SCRIPT_DIR/../lib/dot/ui.sh"
# shellcheck source-path=SCRIPTDIR source=../../lib/dot/preflight.sh
source "$SCRIPT_DIR/../lib/dot/preflight.sh"

usage() {
  cat <<'EOF'
Usage: dot config import <bundle.tar.zst> [--yes|-y]

Restore a bundle written by `dot config export`. It overwrites
~/.dotfiles, ~/.config/chezmoi and ~/.local/share/mise with the copies
the bundle holds. Asks first; --yes restores without asking.
EOF
}

BUNDLE=""
_LIST=""
trap 'rm -f "$_LIST"' EXIT

# _parse_args ARGS...: BUNDLE and DOTFILES_YES, or usage and exit 2.
_parse_args() {
  dot_apply_yes_flag "$@"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help) usage && exit 0 ;;
      -y | --yes) ;;
      -*) _usage_error "unknown option '$1'" ;;
      *)
        [[ -z "$BUNDLE" ]] || _usage_error "unexpected argument '$1'"
        BUNDLE="$1"
        ;;
    esac
    shift
  done
  [[ -n "$BUNDLE" ]] || _usage_error "a bundle file is required"
}

_usage_error() {
  printf 'dot config import: %s\n' "$1" >&2
  usage >&2
  exit 2
}

_refuse() {
  ui_err "Not restored" "$1"
  exit 1
}

# _check_members: every member of the bundle lies under one of the paths
# export writes; prints the ones the bundle holds, one per line.
_check_members() {
  awk -v a="$HOME/.dotfiles" -v b="$HOME/.config/chezmoi" -v c="$HOME/.local/share/mise" '
    function under(n, r) { return n == r || index(n, r "/") == 1 }
    {
      n = $0
      sub(/\/+$/, "", n)
      if (n ~ /(^|\/)\.\.?(\/|$)/ || !(under(n, a) || under(n, b) || under(n, c))) {
        if (stray == "") stray = $0
        next
      }
      seen[under(n, a) ? a : under(n, b) ? b : c] = 1
    }
    END {
      if (stray != "") { print stray; exit 1 }
      if (!(a in seen) && !(b in seen) && !(c in seen)) exit 1
      for (r in seen) print r
    }' "$_LIST"
}

# _read_bundle: ROOTS, the export paths the bundle holds, or refuse.
_read_bundle() {
  [[ -f "$BUNDLE" && "$BUNDLE" == *.tar.zst ]] || _refuse "$BUNDLE is not a .tar.zst bundle from 'dot config export'"
  command -v zstd >/dev/null 2>&1 || _refuse "zstd is required to read the bundle"
  _LIST="$(mktemp "${TMPDIR:-/tmp}/dot-import.XXXXXX")"
  tar --zstd -tf "$BUNDLE" -P >"$_LIST" 2>/dev/null || _refuse "$BUNDLE is not a readable zstd tar archive"
  ROOTS="$(_check_members)" || {
    [[ -n "$ROOTS" ]] || _refuse "$BUNDLE is empty"
    _refuse "$BUNDLE holds $ROOTS, outside what 'dot config export' writes for this home ($HOME)"
  }
}

# _restore: list what is overwritten, ask, then extract.
_restore() {
  local root
  ui_header "Restore Offline Bundle"
  while IFS= read -r root; do ui_bullet "Overwrites: $root"; done <<<"$ROOTS"
  if ! dot_consent "Overwrite these with the contents of $BUNDLE?"; then
    ui_warn "Not restored" "nothing changed; run again with --yes to restore without asking"
    exit 1
  fi
  tar --zstd -xf "$BUNDLE" -C / || _refuse "tar failed while extracting $BUNDLE"
  ui_ok "Restored" "$BUNDLE"
  ui_info "Next" "dot config apply"
}

ROOTS=""
_parse_args "$@"
_read_bundle
_restore
