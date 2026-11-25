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

# extension_glob: a ripgrep glob like `{*.sh,*.lua,*.nix}` from $EXTENSIONS.
extension_glob() {
  local -a exts
  local ext glob=""
  IFS=',' read -r -a exts <<<"$EXTENSIONS"
  for ext in "${exts[@]}"; do glob+="${glob:+,}*.${ext}"; done
  printf '{%s}' "$glob"
}
glob="$(extension_glob)"

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

# has_header <head-buffer>: true when the buffer holds any of PATTERNS.
has_header() {
  local pattern
  for pattern in "${PATTERNS[@]}"; do
    grep -qF -- "$pattern" <<<"$1" && return 0
  done
  return 1
}

# grant_set <expression>: the operands of an SPDX expression, sorted, so
# `A OR B` and `B OR A` compare equal and a file is not failed over order.
grant_set() {
  printf '%s' "$1" | tr ' ' '\n' | grep -v '^OR$' | LC_ALL=C sort | tr '\n' ' '
}

# declared_grant <head-buffer>: the SPDX expression the buffer declares,
# trimmed of a trailing comment close (`-->`) and whitespace; empty if none.
declared_grant() {
  local spdx_line declared
  # REUSE-IgnoreStart -- search string, not a declaration
  spdx_line="$(grep -m1 -F 'SPDX-License-Identifier:' <<<"$1" || true)"
  [[ -n "$spdx_line" ]] || return 0
  declared="${spdx_line#*SPDX-License-Identifier:}"
  # REUSE-IgnoreEnd
  declared="${declared%%-->*}"
  declared="${declared#"${declared%%[![:space:]]*}"}"
  printf '%s' "${declared%"${declared##*[![:space:]]}"}"
}

# scan_files: fill `missing` (no header in the first 10 lines) and
# `wrong_spdx` (an SPDX line declaring other than the project's grant;
# a missing SPDX line is the header check's to report).
scan_files() {
  local file head_buf declared expected
  expected="$(grant_set "$EXPECTED_SPDX")"
  for file in "${all_files[@]}"; do
    [[ "$file" =~ $EXCLUDES ]] && continue
    # Read the first 10 lines once; every check searches that buffer.
    head_buf="$(head -n 10 "$file" 2>/dev/null || true)"
    has_header "$head_buf" || missing+=("$file")
    [[ "$CHECK_SPDX_VALUE" -eq 1 ]] || continue
    declared="$(declared_grant "$head_buf")"
    if [[ -n "$declared" && "$(grant_set "$declared")" != "$expected" ]]; then
      wrong_spdx+=("$file: declares '$declared'")
    fi
  done
}

missing=()
wrong_spdx=()
scan_files

# fail_missing <file...>: report files with no header, and the patterns that count.
fail_missing() {
  echo "::error::Copyright header validation failed — $# file(s) missing header"
  echo "Files missing a recognised copyright header:"
  printf '  - %s\n' "$@"
  echo
  echo "Add ONE of the following to the first 10 lines:"
  printf '  - %s\n' "${PATTERNS[@]}"
  exit 1
}

# fail_wrong_spdx <finding...>: report files declaring a narrower grant.
fail_wrong_spdx() {
  echo "::error::SPDX grant mismatch — $# file(s) declare a licence other than '$EXPECTED_SPDX'"
  printf '  - %s\n' "$@"
  echo
  echo "The project ships LICENSE-APACHE and LICENSE-MIT and package.json declares"
  echo "'$EXPECTED_SPDX'. A file claiming less is the statement downstream relies on."
  echo "Fix with: tools/ci/normalize-spdx-headers.sh"
  exit 1
}

[[ "${#missing[@]}" -eq 0 ]] || fail_missing "${missing[@]}"
[[ "${#wrong_spdx[@]}" -eq 0 ]] || fail_wrong_spdx "${wrong_spdx[@]}"

# Third gate: a copyright line that reserves all rights contradicts the
# grant: it withholds what LICENSE-APACHE and LICENSE-MIT give away. It
# runs over every file, hidden ones and templates included, because the
# extension scan above skips both and the line survived there for years.
# Licence texts and vendored trees keep their own wording.
#
# check_reserved_rights: exit 1 naming each file whose first ten lines
# reserve all rights, with the header to use instead.
check_reserved_rights() {
  local excludes='(^|/)(node_modules|\.git|vendor|target|build|LICENSES)/' file lineno
  local -a reserved=()
  while IFS=: read -r file lineno _; do
    [[ "$lineno" -le 10 && ! "$file" =~ $excludes ]] && reserved+=("${file#./}")
  done < <(rg --hidden -g '!.git' -n -i -m1 'copyright.*all rights reserved' . 2>/dev/null || true)
  [[ "${#reserved[@]}" -eq 0 ]] && return 0
  echo "::error::Reserved-rights header: ${#reserved[@]} file(s) say 'All rights reserved' under an '$EXPECTED_SPDX' grant"
  printf '  - %s\n' "${reserved[@]}"
  echo
  echo "Use the project header instead:"
  # REUSE-IgnoreStart -- printed hint, not a declaration
  echo "  SPDX-License-Identifier: $EXPECTED_SPDX"
  # REUSE-IgnoreEnd
  echo "  Copyright (c) <years> Sebastien Rousseau"
  exit 1
}

check_reserved_rights

echo "::notice::All ${#all_files[@]} file(s) have a valid copyright header and declare '$EXPECTED_SPDX'"
