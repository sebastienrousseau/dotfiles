#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Copyright header validator (zero-tolerance policy).
#
# Scans source files for a copyright header in the first 10 lines. Patterns
# are deliberately narrow to avoid false positives on C-style `(c)` comments
# or the word "token" appearing in running text.
#
# Also validates the SPDX identifier itself, not merely its presence:
# a file declaring a licence narrower than the project's grant is a
# REUSE compliance failure and is the statement a downstream reader
# would rely on. The expected grant is read from package.json so this
# check cannot drift from the manifest.
#
# Usage:
#   check-copyright-headers.sh [--extensions=sh,lua,nix,...] [--excludes=REGEX]
#                              [--no-spdx-value]
#
# Exit codes:
#   0  all files have a valid header with the expected SPDX grant
#   1  one or more files are missing a header, or declare a wrong grant
#   2  invalid invocation

set -euo pipefail

EXTENSIONS_DEFAULT="sh,lua,nix,py,js,ts,go,rs,java,cpp,c,h,hpp"
EXCLUDES_DEFAULT='(^|/)(node_modules|\.git|vendor|target|build)/|\.tmpl$|(^|/)(defaults/)?\.chezmoitemplates/'

EXTENSIONS="$EXTENSIONS_DEFAULT"
EXCLUDES="$EXCLUDES_DEFAULT"
CHECK_SPDX_VALUE=1

# The grant every first-party file must declare, read from the manifest
# rather than hardcoded, so relicensing is a one-line change there.
# `|| true`: the checker is also run from a scratch directory by its
# own tests, where package.json does not exist. Under `set -e` a
# failing command substitution would abort before the fallback.
EXPECTED_SPDX="$(sed -n 's/.*"license"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' package.json 2>/dev/null | head -1 || true)"
[[ -n "$EXPECTED_SPDX" ]] || EXPECTED_SPDX="Apache-2.0 OR MIT"

for arg in "$@"; do
  case "$arg" in
    --extensions=*) EXTENSIONS="${arg#*=}" ;;
    --excludes=*) EXCLUDES="${arg#*=}" ;;
    --no-spdx-value) CHECK_SPDX_VALUE=0 ;;
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
  # REUSE-IgnoreStart -- this is a search pattern, not a declaration
  "SPDX-License-Identifier:"
  # REUSE-IgnoreEnd
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

# `mapfile` is a bash 4 builtin; macOS still ships bash 3.2 as
# /bin/bash, where it fails with "command not found" (rc 127) and this
# check silently reports nothing. Read the list portably instead.
all_files=()
while IFS= read -r _line; do
  [[ -n "$_line" ]] && all_files+=("$_line")
done < <(rg --files -g "$glob" 2>/dev/null || true)

if [[ "${#all_files[@]}" -eq 0 ]]; then
  echo "::notice::No files matched extensions: $EXTENSIONS"
  exit 0
fi

missing=()
wrong_spdx=()
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

  # Second gate: if the file declares an SPDX identifier at all, it
  # must be the project's grant. A missing SPDX line is covered by the
  # header check above; a *wrong* one is what this catches.
  if [[ "$CHECK_SPDX_VALUE" -eq 1 ]]; then
    # REUSE-IgnoreStart -- search string, not a declaration
    spdx_line="$(grep -m1 -F 'SPDX-License-Identifier:' <<<"$head_buf" || true)"
    if [[ -n "$spdx_line" ]]; then
      # Strip everything up to the tag, and any trailing comment
      # close (`-->`) or whitespace, leaving the bare expression.
      declared="${spdx_line#*SPDX-License-Identifier:}"
      # REUSE-IgnoreEnd
      declared="${declared%%-->*}"
      # Trim surrounding whitespace without a subshell.
      declared="${declared#"${declared%%[![:space:]]*}"}"
      declared="${declared%"${declared##*[![:space:]]}"}"
      # `A OR B` and `B OR A` are the same grant. Compare the operands
      # as a set so a file is not failed over word order alone.
      declared_sorted="$(printf '%s' "$declared" | tr ' ' '\n' | grep -v '^OR$' | LC_ALL=C sort | tr '\n' ' ')"
      expected_sorted="$(printf '%s' "$EXPECTED_SPDX" | tr ' ' '\n' | grep -v '^OR$' | LC_ALL=C sort | tr '\n' ' ')"
      if [[ -n "$declared" && "$declared_sorted" != "$expected_sorted" ]]; then
        wrong_spdx+=("$file: declares '$declared'")
      fi
    fi
  fi
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

if [[ "${#wrong_spdx[@]}" -gt 0 ]]; then
  echo "::error::SPDX grant mismatch — ${#wrong_spdx[@]} file(s) declare a licence other than '$EXPECTED_SPDX'"
  printf '  - %s\n' "${wrong_spdx[@]}"
  echo
  echo "The project ships LICENSE-APACHE and LICENSE-MIT and package.json declares"
  echo "'$EXPECTED_SPDX'. A file claiming less is the statement downstream relies on."
  echo "Fix with: tools/ci/normalize-spdx-headers.sh"
  exit 1
fi

echo "::notice::All ${#all_files[@]} file(s) have a valid copyright header and declare '$EXPECTED_SPDX'"
