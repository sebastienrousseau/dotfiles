#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Copyright header validator (zero-tolerance policy).
#
# Scans source files for a copyright header in the first 10 lines. Patterns
# are deliberately narrow to avoid false positives on C-style `(c)` comments
# or the word "token" appearing in running text.
#
# Usage:
#   check-copyright-headers.sh [--extensions=sh,lua,nix,...] [--excludes=REGEX]
#
# Exit codes:
#   0  all files have a valid header
#   1  one or more files are missing a header
#   2  invalid invocation

set -euo pipefail

EXTENSIONS_DEFAULT="sh,lua,nix,py,js,ts,go,rs,java,cpp,c,h,hpp"
EXCLUDES_DEFAULT='(^|/)(node_modules|\.git|vendor|target|build)/|\.tmpl$|(^|/)\.chezmoitemplates/'

EXTENSIONS="$EXTENSIONS_DEFAULT"
EXCLUDES="$EXCLUDES_DEFAULT"

for arg in "$@"; do
  case "$arg" in
    --extensions=*) EXTENSIONS="${arg#*=}" ;;
    --excludes=*) EXCLUDES="${arg#*=}" ;;
    -h | --help)
      sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg" >&2
      exit 2
      ;;
  esac
done

# Narrow patterns — each must be specific enough that running prose cannot match.
# Deliberately DROPPED: bare "(c) " (false-positives in C comments),
# bare "All rights reserved" (often appears in vendored prose).
# Matched by `grep -F`, so these are literal strings.
PATTERNS=(
  "Copyright (c)"
  "Copyright ©"
  "SPDX-License-Identifier:"
  "© "
)

# Build a ripgrep glob like `{*.sh,*.lua,*.nix}` from the comma list.
IFS=',' read -r -a exts <<<"$EXTENSIONS"
glob="{"
for i in "${!exts[@]}"; do
  [[ $i -gt 0 ]] && glob+=","
  glob+="*.${exts[$i]}"
done
glob+="}"

mapfile -t all_files < <(rg --files -g "$glob" 2>/dev/null || true)

if [[ "${#all_files[@]}" -eq 0 ]]; then
  echo "::notice::No files matched extensions: $EXTENSIONS"
  exit 0
fi

missing=()
for file in "${all_files[@]}"; do
  if [[ "$file" =~ $EXCLUDES ]]; then
    continue
  fi

  found=false
  # Read the first 10 lines once; search each pattern against that buffer.
  head_buf="$(head -n 10 "$file" 2>/dev/null || true)"
  for pattern in "${PATTERNS[@]}"; do
    if grep -qF -- "$pattern" <<<"$head_buf"; then
      found=true
      break
    fi
  done

  $found || missing+=("$file")
done

if [[ "${#missing[@]}" -gt 0 ]]; then
  echo "::error::Copyright header validation failed — ${#missing[@]} file(s) missing header"
  echo "Files missing a recognised copyright header:"
  printf '  - %s\n' "${missing[@]}"
  echo
  echo "Add ONE of the following to the first 10 lines:"
  printf '  - %s\n' "${PATTERNS[@]}"
  exit 1
fi

echo "::notice::All ${#all_files[@]} file(s) have a valid copyright header"
