#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# =============================================================================
# shell-surface-audit.sh — Classify shell files and flag duplication signals.
#
# The repo carries close to 1,000 shell scripts across libraries, dot
# subcommands, tests, tooling, and installers. That surface is a real
# maintainability cost; this audit exists to keep it honest.
#
# What it does:
#   1. Counts shell files by role (lib, dot-command, test, install,
#      ops-script, one-off).
#   2. Emits duplication signals:
#        - Same file basename in ≥2 top-level roles (candidate for
#          promotion to `lib/dot/`).
#        - Function names defined in ≥2 files (candidate for shared
#          helper extraction).
#   3. Optionally enforces a ceiling (`--max-total N`). Non-zero exit
#      when exceeded — wire into CI to prevent the number growing.
#
# Emits JSON with `--json` for pipelines; human-readable by default.
# =============================================================================

set -euo pipefail

ROOT=${DOTFILES_REPO_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}
JSON=0
MAX_TOTAL=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [--json] [--max-total N] [--root DIR]

Options:
  --json           Emit machine-readable JSON instead of a report.
  --max-total N    Exit non-zero if total shell file count exceeds N.
  --root DIR       Repository root to scan (default: git toplevel).
EOF
  exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json)      JSON=1; shift ;;
    --max-total) MAX_TOTAL=$2; shift 2 ;;
    --root)      ROOT=$2; shift 2 ;;
    -h|--help)   usage 0 ;;
    *)           echo "unknown flag: $1" >&2; usage 1 ;;
  esac
done

cd "$ROOT"

# ---------------------------------------------------------------------------
# 1. Classify shell files by role.
# ---------------------------------------------------------------------------
declare -A BUCKETS=(
  [lib]='./lib/dot'
  [dot_command]='./scripts/dot/commands'
  [test]='./tests'
  [install]='./install'
  [scripts_ci]='./scripts/ci'
  [scripts_ops]='./scripts/ops'
  [scripts_qa]='./scripts/qa'
  [scripts_security]='./scripts/security'
  [scripts_diagnostics]='./scripts/diagnostics'
  [scripts_tools]='./scripts/tools'
  [scripts_lib]='./scripts/lib'
  [entrypoint]='./bin'
)

count_in() {
  local dir=$1
  [[ -d $dir ]] || { echo 0; return; }
  find "$dir" -type f -name '*.sh' 2>/dev/null | wc -l
}

# Total across the whole repo, minus .git.
TOTAL=$(find . -type f -name '*.sh' ! -path './.git/*' 2>/dev/null | wc -l)

# Everything not caught by a bucket = "one-off".
declare -A COUNTS
CLASSIFIED_TOTAL=0
for role in "${!BUCKETS[@]}"; do
  n=$(count_in "${BUCKETS[$role]}")
  COUNTS[$role]=$n
  CLASSIFIED_TOTAL=$((CLASSIFIED_TOTAL + n))
done
COUNTS[one_off]=$((TOTAL - CLASSIFIED_TOTAL))

# ---------------------------------------------------------------------------
# 2. Duplication signals.
# ---------------------------------------------------------------------------
# 2a. Same basename across ≥2 top-level roles (excluding tests, which
#     legitimately mirror the layout of what they test).
DUP_BASENAMES=$(
  for role in lib dot_command install scripts_ci scripts_ops scripts_qa \
              scripts_security scripts_diagnostics scripts_tools scripts_lib \
              entrypoint; do
    dir=${BUCKETS[$role]:-}
    [[ -d $dir ]] || continue
    find "$dir" -type f -name '*.sh' -printf '%f\n' 2>/dev/null
  done | sort | uniq -c | awk '$1 > 1 {print $2}'
)

# 2b. Function definitions occurring in ≥2 files. Any line starting with
#     an identifier followed by `()` counts. Skips test files.
DUP_FUNCS=$(
  find lib scripts bin install -type f -name '*.sh' 2>/dev/null \
    | xargs -r grep -HnE '^[[:space:]]*[a-zA-Z_][a-zA-Z0-9_]*[[:space:]]*\(\)[[:space:]]*\{' 2>/dev/null \
    | awk -F: '{
        # Split "path:line:code" and pull the function name.
        code=$3
        for (i=4; i<=NF; i++) code=code ":" $i
        gsub(/^[[:space:]]*/, "", code)
        gsub(/[[:space:]]*\(\).*$/, "", code)
        print code "\t" $1
      }' \
    | sort -u \
    | awk -F'\t' '{print $1}' \
    | sort | uniq -c | awk '$1 > 1 {print $1" "$2}'
)

# ---------------------------------------------------------------------------
# 3. Report.
# ---------------------------------------------------------------------------
if [[ $JSON -eq 1 ]]; then
  # Naive JSON — no jq dependency required to build it.
  printf '{'
  printf '"total":%d,' "$TOTAL"
  printf '"by_role":{'
  first=1
  for role in "${!COUNTS[@]}"; do
    [[ $first -eq 0 ]] && printf ','
    printf '"%s":%d' "$role" "${COUNTS[$role]}"
    first=0
  done
  printf '},'
  printf '"duplicate_basenames":%d,' "$(echo "$DUP_BASENAMES" | grep -c . || true)"
  printf '"duplicate_functions":%d' "$(echo "$DUP_FUNCS" | grep -c . || true)"
  printf '}\n'
else
  printf '=== shell surface audit ===\n'
  printf 'root: %s\n\n' "$ROOT"
  printf 'total *.sh files: %d\n\n' "$TOTAL"
  printf 'by role:\n'
  for role in lib dot_command entrypoint install \
              scripts_ci scripts_ops scripts_qa scripts_security \
              scripts_diagnostics scripts_tools scripts_lib \
              test one_off; do
    printf '  %-22s %5d\n' "$role" "${COUNTS[$role]:-0}"
  done

  printf '\nduplicate basenames across roles (candidates for lib/dot/):\n'
  if [[ -z $DUP_BASENAMES ]]; then
    printf '  (none — good)\n'
  else
    printf '%s\n' "$DUP_BASENAMES" | sed 's/^/  /'
  fi

  printf '\nfunction names defined in ≥2 files (candidates for helper extraction):\n'
  if [[ -z $DUP_FUNCS ]]; then
    printf '  (none — good)\n'
  else
    printf '%s\n' "$DUP_FUNCS" | head -20 | awk '{printf "  %-4s %s\n", $1, $2}'
    over=$(echo "$DUP_FUNCS" | wc -l)
    (( over > 20 )) && printf '  … (%d more)\n' "$((over - 20))"
  fi
fi

# ---------------------------------------------------------------------------
# 4. Enforcement gate.
# ---------------------------------------------------------------------------
if (( MAX_TOTAL > 0 )) && (( TOTAL > MAX_TOTAL )); then
  echo "" >&2
  echo "ERROR: shell surface ($TOTAL) exceeds ceiling ($MAX_TOTAL)." >&2
  echo "Ratchet down first, or amend the ceiling with an RFC." >&2
  exit 1
fi
