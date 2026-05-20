#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# =============================================================================
# check-shell-preamble.sh — Enforce `set -euo pipefail` (bash) / `set -eu` (sh)
# on every executable shell script in the repo.
#
# Skip-rules:
#   * Sourced libraries that declare themselves as such via a "Sourced by ..."
#     header comment in the first 15 lines.
#   * Explicit opt-out via `# preamble:skip` marker in the first 15 lines
#     (used by completion files, init fragments, and other library code that
#     is loaded into the caller's shell context).
#   * Files under tests/ (the test runner sets shell options for its children).
#
# Invocation:
#   * pre-commit local hook (files passed as args)
#   * standalone: ./scripts/ci/check-shell-preamble.sh           # full repo
#                 ./scripts/ci/check-shell-preamble.sh file.sh   # explicit
# =============================================================================

set -euo pipefail

check_one() {
  local f="$1"

  [[ -f "$f" ]] || return 0

  local shebang
  shebang="$(head -1 "$f" 2>/dev/null || true)"

  # Only check files with a bash or sh shebang.
  case "$shebang" in
    *bash*) ;;
    *sh) ;;
    *) return 0 ;;
  esac

  # Skip files declaring themselves as sourced libraries or opting out.
  if head -15 "$f" | grep -Eq '^# *(Sourced by |preamble:skip|shellcheck source-only)'; then
    return 0
  fi

  # Skip the test suite — tests are sourced by tests/framework/test_runner.sh
  # which manages shell options for its children.
  case "$f" in
    tests/*) return 0 ;;
    # Bulk-sourced fragments. These directories contain hundreds of
    # alias / function / PATH snippets that are sourced into the
    # caller's shell context — adding `set -e` locally would corrupt
    # the caller. Path-skipped en masse rather than annotated per-file
    # (would be 300+ marker comments).
    .chezmoitemplates/aliases/*) return 0 ;;
    .chezmoitemplates/functions/*) return 0 ;;
    # .chezmoitemplates/paths/ removed — PATH now in dot_config/shell/00-core-paths.sh.tmpl
    # dot_config/shell/* and scripts/dot/lib/* are also sourced but
    # have explicit `# Sourced by` headers as of #854 (defense in
    # depth — the lint also accepts them on header alone).
    dot_local/bin/executable_dot_completion) return 0 ;; # zsh completion, sourced into shell
  esac

  # Required preamble lives within the first 50 lines (after optional docstring).
  local preamble_re
  case "$shebang" in
    *bash*)
      preamble_re='^[[:space:]]*set[[:space:]]+-([eu]+o[[:space:]]+pipefail|euo[[:space:]]+pipefail|eu[[:space:]]*$)'
      ;;
    *sh)
      preamble_re='^[[:space:]]*set[[:space:]]+-eu[o]?'
      ;;
  esac

  if ! head -50 "$f" | grep -Eq "$preamble_re"; then
    echo "MISSING preamble: $f"
    return 1
  fi
}

fail=0
if [[ $# -gt 0 ]]; then
  for f in "$@"; do
    check_one "$f" || fail=1
  done
else
  # Full-repo scan
  while IFS= read -r f; do
    check_one "$f" || fail=1
  done < <(git ls-files | grep -E '\.sh$|^dot_local/bin/executable_|^scripts/.+\.sh$')
fi

if [[ $fail -ne 0 ]]; then
  cat >&2 <<'MSG'

Some shell scripts are missing the safety preamble.
  * bash → `set -euo pipefail`
  * sh   → `set -eu`

If the file is a sourced library, add this header to its first 15 lines:
  # Sourced by <parent>.sh; inherits set -euo pipefail

If the file is a shell init fragment / completion that must NOT enforce its own
options on the caller, add this marker instead:
  # preamble:skip

MSG
  exit 1
fi
