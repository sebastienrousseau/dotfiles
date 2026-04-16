#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# check-manual.sh — Quality gates for docs/manual/
#
# Runs:
#   - Markdown lint (markdownlint-cli2 if available)
#   - Internal link check (custom — validates all [text](path.md) refs)
#   - Spell check (codespell if available)
#   - Coverage: every `dot <command>` referenced must be documented
#
# Usage:
#   bash scripts/docs/check-manual.sh
#   bash scripts/docs/check-manual.sh --strict   # fail on warnings

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MANUAL_DIR="$REPO_ROOT/docs/manual"
STRICT=false
FAILS=0

for arg in "$@"; do
  case "$arg" in
    --strict) STRICT=true ;;
  esac
done

log() { printf '[check] %s\n' "$*"; }
warn() {
  printf '[check] WARN: %s\n' "$*" >&2
  $STRICT && FAILS=$((FAILS + 1)) || true
}
fail() {
  printf '[check] FAIL: %s\n' "$*" >&2
  FAILS=$((FAILS + 1))
}

# -----------------------------------------------------------------------------
# Internal link check
# -----------------------------------------------------------------------------

check_links() {
  log "checking internal links"
  local broken=0
  local mdfile path abs_path link
  while IFS= read -r mdfile; do
    while IFS= read -r link; do
      [[ -z "$link" ]] && continue
      path="${link#*(}"
      path="${path%)*}"
      path="${path%%#*}"
      [[ -z "$path" ]] && continue
      if [[ "$path" =~ ^/ ]]; then
        abs_path="$REPO_ROOT$path"
      else
        abs_path="$(dirname "$mdfile")/$path"
      fi
      if [[ ! -f "$abs_path" ]]; then
        # Try resolving
        local resolved
        resolved="$(cd "$(dirname "$mdfile")" 2>/dev/null && cd "$(dirname "$path")" 2>/dev/null && pwd)/$(basename "$path")"
        [[ -f "$resolved" ]] && continue
        fail "broken link in $(basename "$mdfile"): $link"
        broken=$((broken + 1))
      fi
    done < <(grep -oE '\[[^]]+\]\([^)]+\.md[^)]*\)' "$mdfile" 2>/dev/null)
  done < <(find "$MANUAL_DIR" -name '*.md' -type f)
  [[ $broken -eq 0 ]] && log "  ✓ all internal links resolve"
}

# -----------------------------------------------------------------------------
# Markdown lint
# -----------------------------------------------------------------------------

check_markdown_lint() {
  if ! command -v markdownlint-cli2 &>/dev/null && ! command -v markdownlint &>/dev/null; then
    warn "skipping markdown lint (markdownlint not installed)"
    return
  fi
  log "running markdownlint"
  local linter
  linter="$(command -v markdownlint-cli2 || command -v markdownlint)"
  if ! "$linter" "$MANUAL_DIR/**/*.md" 2>&1 | head -20; then
    warn "markdown lint reported issues"
  else
    log "  ✓ markdown clean"
  fi
}

# -----------------------------------------------------------------------------
# Spell check
# -----------------------------------------------------------------------------

check_spelling() {
  if ! command -v codespell &>/dev/null; then
    warn "skipping spell check (codespell not installed)"
    return
  fi
  log "running codespell"
  if codespell --skip='*.toml,*.json' "$MANUAL_DIR/" 2>&1 | head -10; then
    log "  ✓ no typos detected"
  else
    warn "codespell found possible typos"
  fi
}

# -----------------------------------------------------------------------------
# Command coverage — every `dot <cmd>` in the repo must be in CLI reference
# -----------------------------------------------------------------------------

check_command_coverage() {
  log "checking command coverage"
  local cli_ref="$MANUAL_DIR/03-reference/01-dot-cli.md"
  if [[ ! -f "$cli_ref" ]]; then
    warn "CLI reference missing"
    return
  fi

  # Extract commands referenced in manual
  local referenced
  referenced="$(grep -rhoE '`dot [a-z][a-z-]+`' "$MANUAL_DIR"/*.md "$MANUAL_DIR"/**/*.md 2>/dev/null |
    sort -u |
    sed -E 's/`dot ([a-z-]+)`/\1/')"

  # Extract commands documented in CLI reference (headings like `### \`dot theme\``)
  local documented
  documented="$(grep -oE '^### `dot [a-z][a-z-]+`' "$cli_ref" 2>/dev/null |
    sed -E 's/### `dot ([a-z-]+)`/\1/' |
    sort -u)"

  # Diff
  local missing
  missing="$(comm -23 <(echo "$referenced") <(echo "$documented") 2>/dev/null)"

  if [[ -n "$missing" ]]; then
    warn "commands referenced but not documented in CLI reference:"
    echo "$missing" | while read -r cmd; do
      [[ -z "$cmd" ]] && continue
      echo "    - dot $cmd"
    done
  else
    log "  ✓ all referenced commands documented"
  fi
}

# -----------------------------------------------------------------------------
# File structure check
# -----------------------------------------------------------------------------

check_structure() {
  log "checking directory structure"
  local required=(
    "00-introduction.md"
    "01-concepts/01-architecture.md"
    "01-concepts/02-trust-model.md"
    "01-concepts/03-theme-engine.md"
    "01-concepts/04-fleet.md"
    "01-concepts/05-self-healing.md"
    "02-tutorials/01-first-install.md"
    "02-tutorials/02-add-wallpaper.md"
    "02-tutorials/03-create-profile.md"
    "02-tutorials/04-encrypt-secret.md"
    "02-tutorials/05-deploy-fleet.md"
    "03-reference/01-dot-cli.md"
    "03-reference/02-config-files.md"
    "03-reference/03-environment.md"
    "03-reference/04-templates.md"
    "03-reference/05-feature-flags.md"
    "04-cookbook/01-recipes.md"
    "04-cookbook/02-troubleshooting.md"
    "04-cookbook/03-faq.md"
    "05-appendices/A-platform-matrix.md"
    "05-appendices/B-security-checklist.md"
    "05-appendices/C-glossary.md"
    "05-appendices/D-bibliography.md"
    "05-appendices/E-license.md"
  )
  local missing=0
  for f in "${required[@]}"; do
    if [[ ! -f "$MANUAL_DIR/$f" ]]; then
      fail "missing required file: $f"
      missing=$((missing + 1))
    fi
  done
  [[ $missing -eq 0 ]] && log "  ✓ all required files present"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

main() {
  log "validating $MANUAL_DIR"
  check_structure
  check_links
  check_command_coverage
  check_markdown_lint
  check_spelling

  echo ""
  if [[ $FAILS -gt 0 ]]; then
    printf '[check] FAILED: %d issue(s)\n' "$FAILS" >&2
    exit 1
  else
    log "all checks passed"
  fi
}

main
