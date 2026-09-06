#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# normalize-spdx-headers.sh — make every file's SPDX-License-Identifier
# match the project's declared licence grant.
#
# The project relicensed to `Apache-2.0 OR MIT` (LICENSE-APACHE +
# LICENSE-MIT ship; package.json and REUSE.toml declare the pair), but
# the per-file headers were never swept and still said `MIT` alone.
# A file that declares a narrower grant than the project offers is a
# REUSE compliance failure and is legally the one a downstream reader
# would rely on, so this is not cosmetic.
#
# The script only rewrites an SPDX line that already exists and whose
# value is in the known-old set. It never invents a header for a file
# that has none (that is check-copyright-headers.sh's job to report),
# and it never touches a line that already declares something else —
# vendored code keeps its upstream grant.
#
# Usage:
#   tools/ci/normalize-spdx-headers.sh           # rewrite in place
#   tools/ci/normalize-spdx-headers.sh --check   # exit 1 if any file is stale
#   tools/ci/normalize-spdx-headers.sh --list    # print the stale files, no changes
#
# Exit codes:
#   0  every SPDX header matches (or the rewrite succeeded)
#   1  --check mode and stale headers remain
#   2  bad usage

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
cd "$REPO_ROOT"

# The grant every first-party file must declare.
WANT="Apache-2.0 OR MIT"

# Values we are willing to rewrite. Anything else is left alone: an
# unrecognised identifier means either vendored code or a deliberate
# exception, and silently relicensing it would be the worse bug.
OLD_VALUES=(
  "MIT"
  "Apache-2.0"
)

# Paths excluded from the sweep. Vendored trees keep upstream headers;
# fixtures assert on exact bytes; the changelog is history.
# `.snap` files are golden CLI output compared byte-for-byte, so a
# header would change the thing under test; the .sh helpers beside them
# are ordinary source and are swept.
EXCLUDE_RE='(^|/)(node_modules|\.git|vendor|target|build|site|_build)/|^docs/archive/|^CHANGELOG\.md$|fixtures/|\.snap$'

mode="write"
for arg in "$@"; do
  case "$arg" in
    --check) mode="check" ;;
    --list) mode="list" ;;
    -h | --help)
      sed -n '5,29p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "unknown flag: $arg" >&2
      exit 2
      ;;
  esac
done

# Build one alternation of the old values for grep, e.g. "MIT|Apache-2.0".
old_alt=""
for v in "${OLD_VALUES[@]}"; do
  [[ -n "$old_alt" ]] && old_alt+="|"
  old_alt+="$(printf '%s' "$v" | sed 's/[][\.*^$/]/\\&/g')"
done

# Candidate files: tracked, and carrying an SPDX line whose value is
# exactly one of the old values (anchored, so "MIT OR X" is not a hit).
stale=()
while IFS= read -r file; do
  [[ -n "$file" ]] || continue
  [[ "$file" =~ $EXCLUDE_RE ]] && continue
  [[ -f "$file" ]] || continue
  stale[${#stale[@]}]="$file"
done < <(
  # REUSE-IgnoreStart -- match pattern, not a declaration
  git grep -lE "SPDX-License-Identifier:[[:space:]]+(${old_alt})[[:space:]]*(-->)?[[:space:]]*$" -- . 2>/dev/null || true
  # REUSE-IgnoreEnd
)

if [[ ${#stale[@]} -eq 0 ]]; then
  echo "SPDX headers: all tracked files already declare '${WANT}'"
  exit 0
fi

if [[ "$mode" == "list" ]]; then
  printf '%s\n' "${stale[@]}"
  exit 0
fi

if [[ "$mode" == "check" ]]; then
  echo "::error::${#stale[@]} file(s) declare a licence narrower than '${WANT}'." >&2
  echo "Run tools/ci/normalize-spdx-headers.sh to fix. Offenders:" >&2
  printf '  %s\n' "${stale[@]:0:40}" >&2
  [[ ${#stale[@]} -gt 40 ]] && echo "  ... and $((${#stale[@]} - 40)) more" >&2
  exit 1
fi

# Rewrite. Preserve whatever comment syntax and trailing markup the
# line already uses (`# `, `// `, `<!-- ... -->`, `.\" `), replacing
# only the identifier itself.
for file in "${stale[@]}"; do
  # REUSE-IgnoreStart -- substitution pattern, not a declaration
  perl -0pi -e "s{(SPDX-License-Identifier:[ \t]+)(?:${old_alt})([ \t]*(?:-->)?[ \t]*)\$}{\${1}${WANT}\${2}}gm" "$file"
  # REUSE-IgnoreEnd
done

echo "SPDX headers: rewrote ${#stale[@]} file(s) to '${WANT}'"
