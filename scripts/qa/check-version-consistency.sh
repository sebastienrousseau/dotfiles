#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
#
# Verify that every "live" version reference matches the canonical
# version in .chezmoidata.toml. The intent is to catch drift between
# the source-of-truth and the human-visible surfaces (CLI banner, man
# page, badge URL, etc.) BEFORE it ships.
#
# Historical references (CHANGELOG entries, audit-doc closed-cycle
# tables, roadmap docs that mention previous versions) are NOT
# checked — they are intentionally pinned to the version they
# describe.
#
# Usage:
#   scripts/qa/check-version-consistency.sh           # verify
#   scripts/qa/check-version-consistency.sh --fix     # auto-fix
#   scripts/qa/check-version-consistency.sh --quiet   # rc-only
#
# Exit codes:
#   0  every live reference matches
#   1  drift detected (with diff printed unless --quiet)
#   2  bad usage / missing canonical version

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# ── Parse flags ─────────────────────────────────────────────────────────
fix=0
quiet=0
for arg in "$@"; do
  case "$arg" in
    --fix) fix=1 ;;
    --quiet | -q) quiet=1 ;;
    -h | --help)
      sed -n '2,21p' "$0"
      exit 0
      ;;
    *)
      echo "unknown flag: $arg" >&2
      exit 2
      ;;
  esac
done

_log() { ((quiet)) || printf '%s\n' "$*"; }
_err() { printf 'check-version-consistency: %s\n' "$*" >&2; }

# ── Canonical version ──────────────────────────────────────────────────
canonical="$(grep -E '^dotfiles_version[[:space:]]*=' .chezmoidata.toml |
  head -1 | sed -E 's/.*"([^"]+)".*/\1/')"

if [[ -z "$canonical" ]]; then
  _err 'failed to read dotfiles_version from .chezmoidata.toml'
  exit 2
fi
_log "canonical: $canonical (.chezmoidata.toml)"

# ── Per-file expected-substring map ────────────────────────────────────
# Each entry: PATH|MATCH_PATTERN|EXPECTED_STRING
# MATCH_PATTERN is a fixed substring to grep for on the file to
# locate the version-bearing line; we then verify it contains the
# expected substring rendered with $canonical. version-sync.sh
# already handles many files (it reads package.json as source);
# this list captures the surfaces version-sync.sh historically
# missed — bento.sh banner, man-page header, dispatcher header.
specs=(
  "package.json|\"version\"|\"version\": \"${canonical}\""
  "bin/dot|^VERSION=|VERSION=\"${canonical}\""
  "bin/dot|^# Dotfiles CLI Entry Point - v|# Dotfiles CLI Entry Point - v${canonical}"
  "share/man/man1/dot.1|^.TH DOT 1|dotfiles v${canonical}"
  "lib/dot/bento.sh|D O T F I L E S|[v${canonical}]"
  "README.md|img.shields.io/badge/Version|Version-v${canonical}-blue"
  "CLAUDE.md|^Chezmoi-managed dotfiles|Version \`${canonical}\`"
  "AGENTS.md|^Chezmoi-managed dotfiles|Version \`${canonical}\`"
)

drift=0
for spec in "${specs[@]}"; do
  IFS='|' read -r path pattern expected <<<"$spec"
  if [[ ! -f "$path" ]]; then
    _err "MISSING: $path (declared in spec list)"
    drift=$((drift + 1))
    continue
  fi
  line="$(grep -E "$pattern" "$path" | head -1 || true)"
  if [[ -z "$line" ]]; then
    _err "PATTERN NOT FOUND: '$pattern' in $path"
    drift=$((drift + 1))
    continue
  fi
  if [[ "$line" != *"$expected"* ]]; then
    _err "DRIFT in $path"
    _err "  found:    $line"
    _err "  expected: contains '$expected'"
    drift=$((drift + 1))
    if ((fix)); then
      # Auto-fix: only safe when the file contains a previous v0.X.YYY
      # we can sed-replace. Skip otherwise.
      old="$(printf '%s' "$line" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
      if [[ -n "$old" ]] && [[ "$old" != "v${canonical}" ]]; then
        sed -i.bak "s|${old}|v${canonical}|g" "$path" && rm -f "$path.bak"
        _log "  fixed:  $path  ($old → v${canonical})"
      fi
    fi
  fi
done

if ((drift > 0)); then
  if ((fix)); then
    _log ""
    _log "Auto-fixed where safe. Re-run without --fix to verify."
  else
    _log ""
    _log "Tip: rerun with --fix to auto-correct (only safe substitutions)."
    _log "     For non-trivial drift, edit the file manually then re-run."
  fi
  exit 1
fi

_log "all $((${#specs[@]})) live version surfaces match $canonical"
exit 0
