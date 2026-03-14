#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Dotfiles Pre-Commit Sentinel (Audit Hook)
# Prevents secrets, hardcoded paths, and shell hygiene violations.

set -euo pipefail

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}🕵️  Running Pre-Commit Audit...${NC}"

# Get list of staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [[ -z "$STAGED_FILES" ]]; then
  echo -e "${GREEN}✓ No files staged. Skipping.${NC}"
  exit 0
fi

FAILED=0

# --- 🔐 1. Secret Scanning ---
echo -n "   🔍 Scanning for secrets... "
# Refined patterns: require assignment-like syntax to reduce false positives on documentation
# Exclude assignments to values containing common placeholder strings or within template expressions
SENSITIVE_PATTERNS="(GITHUB_TOKEN|API_KEY|SECRET|password|private_key|AKIA[0-9A-Z]{16})[[:space:]]*[:=]"
# Exclusions list for legitimate variable checks or documentation
SECRET_EXCLUDES="test_|assertions.sh|.pre-commit|README|CHANGELOG|FEATURES.md|CONFIG_STRATEGY.md|docs/|install/lib/|.chezmoitemplates/|mcp-doctor.sh|\.github/workflows/"
# Also exclude .tmpl files from secret scanning as they contain many false positive markers
if echo "$STAGED_FILES" | grep -v "\.tmpl" | xargs grep -EiE "$SENSITIVE_PATTERNS" /dev/null | grep -vE "$SECRET_EXCLUDES" | grep -viE "dummy|placeholder|example|test|sk-placeholder|\\{\\{" >/dev/null 2>&1; then
  echo -e "${RED}FAILED${NC}"
  echo -e "      ${YELLOW}⚠ Potential secret detected in staged files:${NC}"
  echo "$STAGED_FILES" | grep -v "\.tmpl" | xargs grep -EiE "$SENSITIVE_PATTERNS" /dev/null | grep -vE "$SECRET_EXCLUDES" | grep -viE "dummy|placeholder|example|test|sk-placeholder|\\{\\{" | sed 's/^/      /'
  FAILED=1
else
  echo -e "${GREEN}PASSED${NC}"
fi

# --- 👻 2. Ghost Path Linter ---
echo -n "   👻 Checking for hardcoded paths... "
# Exclude test files, documentation, the hook itself, Nix files, and template backups
GHOST_EXCLUDES="test_|assertions.sh|pre-commit|INTEROP.md|WSL2_NIX_TROUBLESHOOTING.md|\.nix|\.backup|\.github/workflows/"
if echo "$STAGED_FILES" | xargs grep -rIE '"/home/(linuxbrew)?[^$]|/Users/[^$]' /dev/null | grep -v "linuxbrew" | grep -vE "$GHOST_EXCLUDES" >/dev/null 2>&1; then
  echo -e "${RED}FAILED${NC}"
  echo -e "      ${YELLOW}⚠ Literal home paths detected (use \$HOME or ~ instead):${NC}"
  echo "$STAGED_FILES" | xargs grep -rIE '"/home/(linuxbrew)?[^$]|/Users/[^$]' /dev/null | grep -v "linuxbrew" | grep -vE "$GHOST_EXCLUDES" | sed 's/^/      /'
  FAILED=1
else
  echo -e "${GREEN}PASSED${NC}"
fi

# --- 🐚 3. ShellCheck Hygiene ---
if command -v shellcheck >/dev/null 2>&1; then
  echo -n "   🐚 Running ShellCheck... "
  # ONLY run on actual .sh files, NOT .tmpl files (Go templates break shellcheck)
  # Also exclude files that contain Zsh-specific syntax that might trigger false positives in sh mode
  SHELL_FILES=$(echo "$STAGED_FILES" | grep -E '\.sh$' | grep -v "\.tmpl" || true)
  if [[ -n "$SHELL_FILES" ]]; then
    if ! echo "$SHELL_FILES" | xargs shellcheck -x --severity=error -e SC1091,SC2296,SC2142 >/dev/null 2>&1; then
      echo -e "${RED}FAILED${NC}"
      echo -e "      ${YELLOW}⚠ Shell syntax errors detected:${NC}"
      echo "$SHELL_FILES" | xargs shellcheck -x --severity=error -e SC1091,SC2296,SC2142 | sed 's/^/      /'
      FAILED=1
    else
      echo -e "${GREEN}PASSED${NC}"
    fi
  else
    echo -e "${YELLOW}SKIPPED${NC} (no .sh files)"
  fi
fi
# --- 🧹 4. Formatting Audit ---
echo -n "   🧹 Checking formatting... "
# Find files with trailing whitespace, excluding SVGs and other formats where it might be intentional or harmless
OFFENDING_WHITESPACE=$(echo "$STAGED_FILES" | grep -vE '\.(svg|md)$' | xargs grep -l '[[:space:]]$' /dev/null || true)
# Use defused patterns to avoid self-detection
MERGE_START="^<<<<<<< "
MERGE_END="^>>>>>>> "
MERGE_DIV="^=======$"
if [[ -n "$OFFENDING_WHITESPACE" ]]; then
  echo -e "${RED}FAILED${NC}"
  echo -e "      ${YELLOW}⚠ Trailing whitespace found in staged files:${NC}"
  echo "      ${OFFENDING_WHITESPACE//$'\n'/$'\n'      }"
  FAILED=1
elif echo "$STAGED_FILES" | xargs grep -lE "$MERGE_START|$MERGE_END|$MERGE_DIV" /dev/null >/dev/null 2>&1; then
  echo -e "${RED}FAILED${NC}"
  echo -e "      ${YELLOW}⚠ Unresolved merge markers found in staged files:${NC}"
  echo "$STAGED_FILES" | xargs grep -lE "$MERGE_START|$MERGE_END|$MERGE_DIV" /dev/null | sed 's/^/      /'
  FAILED=1
else
  echo -e "${GREEN}PASSED${NC}"
fi

# --- 🏛️ 5. Signature Guard ---
if echo "$STAGED_FILES" | grep -q "^README.md$"; then
  echo -n "   🏛️  Checking README signature... "
  EXPECTED_ARCHITECT='**THE ARCHITECT** ᛫ [Sebastien Rousseau](https://sebastienrousseau.com)'
  EXPECTED_ENGINE='**THE ENGINE** ᛞ [EUXIS](https://euxis.co) ᛫ Enterprise Unified Execution Intelligence System'
  README_CONTENT=$(git show :README.md 2>/dev/null || cat README.md)
  if echo "$README_CONTENT" | grep -qF "$EXPECTED_ARCHITECT" && echo "$README_CONTENT" | grep -qF "$EXPECTED_ENGINE"; then
    echo -e "${GREEN}PASSED${NC}"
  else
    # Auto-add the signature footer before ## License (or at EOF)
    tmp_footer=$(mktemp)
    if grep -qF '## License' README.md; then
      awk -v arch="$EXPECTED_ARCHITECT" -v eng="$EXPECTED_ENGINE" '
        /^## License/ {
          print "---"
          print ""
          print arch
          print eng
          print ""
          print "---"
          print ""
        }
        { print }
      ' README.md >"$tmp_footer" && mv "$tmp_footer" README.md
    else
      {
        printf '\n---\n\n%s\n%s\n\n---\n' "$EXPECTED_ARCHITECT" "$EXPECTED_ENGINE"
      } >>README.md
    fi
    rm -f "$tmp_footer"
    git add README.md
    echo -e "${GREEN}FIXED${NC} (auto-added)"
  fi
fi

echo ""
if [[ $FAILED -eq 1 ]]; then
  echo -e "${RED}${BOLD}❌ Audit failed.${NC} Please fix the issues above before committing."
  echo -e "   (Use --no-verify to bypass if absolutely necessary)"
  exit 1
else
  echo -e "${GREEN}${BOLD}✅ Audit passed.${NC} v0.2.496 standards maintained."
  exit 0
fi
