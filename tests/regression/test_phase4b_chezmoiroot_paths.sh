#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: 9140ddb
# Regression: Phase-4b chezmoiroot path drift guard.
#
# Phase 4b (v0.2.503) moved chezmoi-tracked content into defaults/.
# Scripts that still read ".chezmoidata.toml" / ".chezmoidata/themes.toml"
# from the repo root silently break — they find an empty/missing file
# and fall through to defaults. This caught us twice (theme switch +
# wallpaper sync); this guard makes a third miss noisy.
#
# Rule: any script under scripts/ or bin/ that references a chezmoi
# data file must either (a) use the resolve_chezmoi_source_dir helper,
# (b) inline the .chezmoiroot descent, or (c) hardcode the defaults/
# prefix. Everything else is a bug.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/assertions.sh"

DATA_FILES_PATTERN='\.chezmoidata\.toml|\.chezmoidata/'

# Files allowed to mention the data file paths without going through a
# resolver. These are *the resolver itself*, *the version-sync tooling*
# (which references the canonical source of truth on purpose), and the
# data files themselves.
is_exempt() {
  local f="$1"
  case "$f" in
    */lib/dot/utils.sh) return 0 ;;             # defines resolve_chezmoi_source_dir
    */version-sync.sh) return 0 ;;              # references both pre/post layout intentionally
    */check-version-consistency.sh) return 0 ;; # asserts on defaults/.chezmoidata.toml directly
    */tests/*) return 0 ;;                      # tests can mention paths freely
    */defaults/*) return 0 ;;                   # files inside defaults/ are already in the right place
    */docs/*) return 0 ;;                       # docs reference paths in prose
  esac
  return 1
}

# A file is well-formed if it either:
#   - calls resolve_chezmoi_source_dir, OR
#   - inlines the .chezmoiroot descent (greps the marker file), OR
#   - references the post-Phase-4b path defaults/.chezmoidata.toml.
is_well_formed() {
  local f="$1"
  grep -qE 'resolve_chezmoi_source_dir|\.chezmoiroot|defaults/\.chezmoidata' "$f"
}

# A line counts as a "real reference" only if it's not a comment. We
# strip leading whitespace and the first '#' onwards before re-checking
# for the data-file pattern, so prose comments are ignored.
has_non_comment_reference() {
  local f="$1"
  # awk that strips '#' comments respecting quoted strings is overkill;
  # ignore lines whose first non-space char is '#'.
  grep -nE "$DATA_FILES_PATTERN" "$f" |
    awk -F: '{ rest = ""; for (i=2; i<=NF; i++) rest = rest (i==2 ? "" : ":") $i; sub(/^[ \t]*/, "", rest); if (substr(rest,1,1) != "#") print $0 }' |
    grep -q .
}

# Discover candidates: any file under scripts/, bin/, lib/ that mentions
# the data files.
candidates=()
while IFS= read -r f; do
  candidates+=("$f")
done < <(grep -rlE "$DATA_FILES_PATTERN" \
  "$REPO_ROOT/scripts" "$REPO_ROOT/bin" "$REPO_ROOT/lib" 2>/dev/null | sort)

test_start "candidate_files_found"
if [[ ${#candidates[@]} -gt 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: scanned ${#candidates[@]} files"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: grep found no candidates — scan is broken"
fi

# Each non-exempt candidate must be well-formed.
violations=()
for f in "${candidates[@]}"; do
  if is_exempt "$f"; then
    continue
  fi
  if ! has_non_comment_reference "$f"; then
    continue
  fi
  if ! is_well_formed "$f"; then
    violations+=("${f#"$REPO_ROOT/"}")
  fi
done

test_start "no_phase4b_path_drift"
if [[ ${#violations[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: every chezmoi-data reference goes through a resolver"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: ${#violations[@]} scripts reference chezmoi data without .chezmoiroot descent:"
  for v in "${violations[@]}"; do
    printf '%b\n' "    - $v"
  done
  printf '%b\n' "    Fix: call \$(resolve_chezmoi_source_dir) from lib/dot/utils.sh, or"
  printf '%b\n' "         inline the descent (test -f \$dir/.chezmoiroot && dir=\$dir/\$(head -1 ...))."
fi

# Same shape, narrower target: the theme sync scripts must be honoring
# the descent. This is a targeted assertion so a future refactor that
# rewrites them can't silently skip it.
test_start "theme_scripts_honor_chezmoiroot"
theme_scripts=(
  "$REPO_ROOT/scripts/theme/switch.sh"
  "$REPO_ROOT/scripts/theme/wallpaper-sync.sh"
  "$REPO_ROOT/bin/dot-theme-sync"
)
missing=()
for s in "${theme_scripts[@]}"; do
  [[ -f "$s" ]] || continue
  if ! grep -q '\.chezmoiroot' "$s"; then
    missing+=("${s#"$REPO_ROOT/"}")
  fi
done
if [[ ${#missing[@]} -eq 0 ]]; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: all three theme scripts read .chezmoiroot"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: theme scripts missing .chezmoiroot handling:"
  for m in "${missing[@]}"; do
    printf '%b\n' "    - $m"
  done
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
