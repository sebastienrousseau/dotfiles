#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Regenerate the committed shell completions from the command registry
# in bin/dot, via `dot completion <shell>` (scripts/dot/commands/
# completion.sh). One generator, one registry: the zsh and bash files
# that chezmoi deploys for users, the files the release tarball ships,
# and the files `make install` places under $(PREFIX)/share are all the
# same bytes.
#
# Committed outputs (drift-checked in CI by doc-drift.yml):
#   share/completions/zsh/_dot
#   defaults/dot_local/share/bash-completion/completions/dot
#
# Usage:
#   tools/docs/generate-completions.sh                 # rewrite the committed files
#   tools/docs/generate-completions.sh --check         # exit 1 if any committed file is stale
#   tools/docs/generate-completions.sh --outdir DIR    # write DIR/{_dot,dot,dot.fish} (build/packaging)
#
# Exit codes:
#   0  written / in sync
#   1  --check mode and drift detected
#   2  bad usage / generator unavailable

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

mode="write"
outdir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) mode="check" ;;
    --outdir)
      [[ $# -ge 2 ]] || {
        echo "--outdir needs a path" >&2
        exit 2
      }
      outdir="$2"
      shift
      ;;
    -h | --help)
      sed -n '5,23p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "unknown flag: $1" >&2
      exit 2
      ;;
  esac
  shift
done

[[ -r bin/dot ]] || {
  echo "dot CLI not found at bin/dot" >&2
  exit 2
}

gen() {
  CHEZMOI_SOURCE_DIR="$REPO_ROOT" DOTFILES_NONINTERACTIVE=1 NO_COLOR=1 \
    bash bin/dot completion "$1"
}

# Build-dir mode: every shell, FHS-style basenames, nothing committed.
if [[ -n "$outdir" ]]; then
  mkdir -p "$outdir"
  gen zsh >"$outdir/_dot"
  gen bash >"$outdir/dot"
  gen fish >"$outdir/dot.fish"
  echo "Wrote $outdir/{_dot,dot,dot.fish}"
  exit 0
fi

# Committed-file mode.
targets=(
  "zsh|share/completions/zsh/_dot"
  "bash|defaults/dot_local/share/bash-completion/completions/dot"
)

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
stale=0
for spec in "${targets[@]}"; do
  shell="${spec%%|*}"
  target="${spec#*|}"
  gen "$shell" >"$tmp"
  if [[ "$mode" == "check" ]]; then
    if [[ ! -f "$target" ]] || ! diff -q "$target" "$tmp" >/dev/null 2>&1; then
      echo "$target is stale. Run tools/docs/generate-completions.sh (or make completions) to refresh." >&2
      diff -u "$target" "$tmp" 2>/dev/null | head -20 >&2 || true
      stale=$((stale + 1))
    fi
  else
    mkdir -p "$(dirname "$target")"
    cp "$tmp" "$target"
    echo "Wrote $target"
  fi
done

if [[ "$mode" == "check" ]]; then
  if ((stale > 0)); then
    exit 1
  fi
  echo "completions are in sync (${#targets[@]} files)"
fi
