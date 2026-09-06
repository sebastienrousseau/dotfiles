#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# Generate share/man/man1/dot.1 from the command registry in bin/dot.
#
# The COMMANDS section is rendered from `_dot_help_specs()` (the same
# registry that drives `dot help all` and `dot completion`); the
# ALIASES AND HIDDEN COMMANDS section from every `_dot_command_routes()`
# entry that has no specs row, described via `_dot_help_details()`.
# Prose (NAME, DESCRIPTION, ENVIRONMENT, FILES, ...) comes from
# tools/docs/man/dot.1.in. The .TH date is the date of the top
# CHANGELOG heading so the output is reproducible.
#
# Usage:
#   tools/docs/generate-manpage.sh                # write share/man/man1/dot.1
#   tools/docs/generate-manpage.sh --check        # exit 1 if the committed page is stale
#   tools/docs/generate-manpage.sh --output FILE  # write elsewhere (build dirs, packaging)
#
# Exit codes:
#   0  page written / already in sync
#   1  --check mode and drift detected
#   2  bad usage / registry unreadable

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

mode="write"
output="share/man/man1/dot.1"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check) mode="check" ;;
    --output)
      [[ $# -ge 2 ]] || {
        echo "--output needs a path" >&2
        exit 2
      }
      output="$2"
      shift
      ;;
    -h | --help)
      sed -n '5,24p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "unknown flag: $1" >&2
      exit 2
      ;;
  esac
  shift
done

dot_bin="bin/dot"
template="tools/docs/man/dot.1.in"
[[ -r "$dot_bin" ]] || {
  echo "registry not found: $dot_bin" >&2
  exit 2
}
[[ -r "$template" ]] || {
  echo "template not found: $template" >&2
  exit 2
}

# ── Version + date ─────────────────────────────────────────────────────
version="$(grep -E '^dotfiles_version[[:space:]]*=' defaults/.chezmoidata.toml |
  head -1 | sed -E 's/.*"([^"]+)".*/\1/')"
[[ -n "$version" ]] || {
  echo "cannot read dotfiles_version from defaults/.chezmoidata.toml" >&2
  exit 2
}

# Top CHANGELOG heading: "## vX.Y.Z — YYYY-MM-DD". Reproducible, unlike
# `date`, and changes exactly when a release does.
iso_date="$(grep -m1 -E '^## v[0-9]+\.[0-9]+\.[0-9]+' CHANGELOG.md |
  grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' | head -1 || true)"
[[ -n "$iso_date" ]] || iso_date="1970-01-01"
# ISO-8601 is what mandoc(1) parses without complaint and what the
# reproducible-builds guidance recommends for .TH.
man_date="$iso_date"

# ── Registry extraction ────────────────────────────────────────────────
# Emit the heredoc body of one registry function from bin/dot.
_registry() {
  awk -v fn="$1" '
    index($0, fn "()") { in_func = 1; next }
    in_func && /cat <<'\''EOF'\''/ { in_block = 1; next }
    in_block && /^EOF$/ { exit }
    in_block { print }
  ' "$dot_bin"
}

# Escape a string for roff: backslashes, leading control characters,
# and hyphens (rendered as true minus signs so `--flag` copies cleanly).
# Sets REPLY instead of printing — the generator runs this hundreds of
# times and a $(...) per call is a fork per call.
_roff() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//-/\\-}"
  case "$s" in
    .* | \'*) s="\\&$s" ;;
  esac
  REPLY="$s"
}

tmp="$(mktemp)"
commands_tmp="$(mktemp)"
aliases_tmp="$(mktemp)"
specs_tmp="$(mktemp)"
details_tmp="$(mktemp)"
routes_tmp="$(mktemp)"
trap 'rm -f "$tmp" "$commands_tmp" "$aliases_tmp" "$specs_tmp" "$details_tmp" "$routes_tmp"' EXIT

# Extract each registry exactly once; the loops below only grep/awk
# these files, keeping the fork count low enough for constrained
# sandboxes (test runners with a process ulimit).
_registry _dot_help_specs >"$specs_tmp"
_registry _dot_help_details >"$details_tmp"
_registry _dot_command_routes | LC_ALL=C sort -u >"$routes_tmp"

# COMMANDS: group by category in first-appearance order. Fields are
# Category|name|description|note; descriptions may themselves contain
# `|` (e.g. "--ai|-A"), so everything between field 2 and the last
# field is the description.
prev_cat=""
while IFS= read -r line; do
  [[ -n "$line" ]] || continue
  cat="${line%%|*}"
  rest="${line#*|}"
  name="${rest%%|*}"
  rest="${rest#*|}"
  desc="${rest%|*}"
  [[ -n "$name" ]] || continue
  if [[ "$cat" != "$prev_cat" ]]; then
    _roff "$cat"
    printf '.SS %s\n' "$REPLY" >>"$commands_tmp"
    prev_cat="$cat"
  fi
  _roff "$name"
  roff_name="$REPLY"
  _roff "$desc"
  printf '.TP\n.B %s\n%s\n' "$roff_name" "$REPLY" >>"$commands_tmp"
done < <(
  awk -F'|' '
    # Stable grouping: keep the first-seen order of categories, but
    # emit every row of a category together so .SS headers are unique.
    { if (!($1 in seen)) { seen[$1] = ++n; order[n] = $1 }
      rows[$1] = rows[$1] $0 "\n" }
    END { for (i = 1; i <= n; i++) printf "%s", rows[order[i]] }' "$specs_tmp"
)

# ALIASES: routes with no specs row. Description from _dot_help_details
# (field 2) when present, else a pointer at --help.
cut -d'|' -f2 "$specs_tmp" | LC_ALL=C sort -u >"$tmp"
while IFS='|' read -r route module; do
  [[ -n "$route" ]] || continue
  case "$route" in --* | -?) continue ;; esac
  if grep -qxF "$route" "$tmp"; then
    continue
  fi
  detail="$(awk -F'|' -v r="$route" '$1 == r { print $2; exit }' "$details_tmp")"
  [[ -n "$detail" ]] || detail="Routed to the ${module} module; run dot ${route} --help."
  _roff "$route"
  roff_name="$REPLY"
  _roff "$detail"
  printf '.TP\n.B %s\n%s\n' "$roff_name" "$REPLY" >>"$aliases_tmp"
done <"$routes_tmp"

[[ -s "$commands_tmp" ]] || {
  echo "no commands extracted from $dot_bin — registry format changed?" >&2
  exit 2
}

# ── Render ─────────────────────────────────────────────────────────────
while IFS= read -r line; do
  case "$line" in
    '@COMMANDS@') cat "$commands_tmp" ;;
    '@ALIASES@') cat "$aliases_tmp" ;;
    *)
      line="${line//@VERSION@/$version}"
      line="${line//@DATE@/$man_date}"
      printf '%s\n' "$line"
      ;;
  esac
done <"$template" >"$tmp"

if [[ "$mode" == "check" ]]; then
  if [[ ! -f "$output" ]] || ! diff -q "$output" "$tmp" >/dev/null 2>&1; then
    echo "$output is stale. Run tools/docs/generate-manpage.sh (or make man) to refresh." >&2
    diff -u "$output" "$tmp" 2>/dev/null | head -40 >&2 || true
    exit 1
  fi
  echo "$output is in sync"
  exit 0
fi

mkdir -p "$(dirname "$output")"
mv "$tmp" "$output"
trap 'rm -f "$commands_tmp" "$aliases_tmp" "$specs_tmp" "$details_tmp" "$routes_tmp"' EXIT
echo "Wrote $output ($(grep -c '^\.TP' "$output") entries, dotfiles v$version, $man_date)"
