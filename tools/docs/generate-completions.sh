#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Keep the committed shell completions in step with the command
# registry in bin/dot, via `dot completion <shell>`
# (scripts/dot/commands/completion.sh).
#
# Two different contracts, because the two files are different kinds
# of artefact:
#
#   defaults/dot_local/share/bash-completion/completions/dot
#       FULLY GENERATED, checked byte-for-byte. Nothing in it that the
#       registry cannot express.
#
#   share/completions/zsh/_dot
#       HAND-MAINTAINED, checked for COVERAGE only. The zsh completion
#       carries per-command argument and flag completions (ssh-cert
#       verbs, `dot new` templates, `dot perf` flags) that the registry
#       does not model, and regenerating it would be a downgrade in
#       what users actually get. What CI enforces instead is that it
#       can never fall *behind*: every top-level command in the
#       registry must appear in it. Richer is allowed; missing is not.
#
# The release tarball and `make install` generate all three shells
# fresh from the registry (tools/release/stage-dot.sh), so a packaged
# install always ships a command list that matches its own CLI.
#
# Usage:
#   tools/docs/generate-completions.sh                 # rewrite the bash file, check zsh coverage
#   tools/docs/generate-completions.sh --check         # exit 1 on bash drift or a zsh coverage gap
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

BASH_TARGET="defaults/dot_local/share/bash-completion/completions/dot"
ZSH_TARGET="share/completions/zsh/_dot"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
stale=0

# ── bash: byte-for-byte generated ──────────────────────────────────────
gen bash >"$tmp"
if [[ "$mode" == "check" ]]; then
  if [[ ! -f "$BASH_TARGET" ]] || ! diff -q "$BASH_TARGET" "$tmp" >/dev/null 2>&1; then
    echo "$BASH_TARGET is stale. Run tools/docs/generate-completions.sh (or make completions)." >&2
    diff -u "$BASH_TARGET" "$tmp" 2>/dev/null | head -20 >&2 || true
    stale=$((stale + 1))
  fi
else
  mkdir -p "$(dirname "$BASH_TARGET")"
  cp "$tmp" "$BASH_TARGET"
  echo "Wrote $BASH_TARGET"
fi

# ── zsh: coverage only ─────────────────────────────────────────────────
# Every top-level command the registry knows must have a `'name:...'`
# entry. Extra entries (argument values, flags, aliases) are fine.
missing=()
while IFS= read -r name; do
  [[ -n "$name" ]] || continue
  grep -q "'${name}:" "$ZSH_TARGET" 2>/dev/null || missing[${#missing[@]}]="$name"
done < <(gen zsh | sed -n "s/^[[:space:]]*'\([a-z][a-z0-9-]*\):.*/\1/p" | LC_ALL=C sort -u)

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "$ZSH_TARGET is missing ${#missing[@]} registry command(s):" >&2
  printf '  %s\n' "${missing[@]}" >&2
  echo >&2
  echo "The zsh completion is hand-maintained for its argument and flag" >&2
  echo "completions, but must never fall behind the registry. Add an entry" >&2
  echo "of the form  'name:description'  to the commands array. Copy the" >&2
  echo "description from: bash bin/dot completion zsh" >&2
  stale=$((stale + 1))
fi

if [[ "$mode" == "check" ]]; then
  if ((stale > 0)); then
    exit 1
  fi
  echo "completions are in sync (bash generated; zsh covers every registry command)"
else
  echo "$ZSH_TARGET is hand-maintained; checked for coverage, not rewritten"
fi
