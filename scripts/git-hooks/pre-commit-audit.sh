#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Dotfiles Pre-Commit Sentinel (Audit Hook)
# Prevents secrets, hardcoded paths, and shell hygiene violations.

set -euo pipefail

_cleanup_files=()
trap 'set +u; rm -f "${_cleanup_files[@]}" 2>/dev/null; set -u' EXIT

# ANSI Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m'

printf '%b\\n' "${BOLD}🕵️  Running Pre-Commit Audit...${NC}"

# Get list of staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [[ -z "$STAGED_FILES" ]]; then
  printf '%b\\n' "${GREEN}✓ No files staged. Skipping.${NC}"
  exit 0
fi

FAILED=0

# --- 🔐 1. Secret Scanning ---
echo -n "   🔍 Scanning for secrets... "
# Refined patterns: require assignment-like syntax to reduce false positives on documentation
# Exclude assignments to values containing common placeholder strings or within template expressions
# A key (quoted or not) given a value: `=` then anything but `=`, or `:` then a
# value. Not ${API_KEY:-} or ${API_KEY:=x} (shell defaults), `if not API_KEY:`
# or a `:` before a comment.
SENSITIVE_PATTERNS="(GITHUB_TOKEN|API_KEY|SECRET|password|private_key|AKIA[0-9A-Z]{16})[\"']?[[:space:]]*(=[^=]|:[[:space:]]*[^-=#[:space:]])"
# Exclusions list for legitimate variable checks or documentation
SECRET_EXCLUDES="test_|assertions.sh|.pre-commit|README|CHANGELOG|FEATURES.md|docs/|install/lib/|.chezmoitemplates/|mcp-doctor.sh|\.github/workflows/"
# A value read from somewhere else is not a secret written down: a shell
# variable ("$key", ${KEY}) or a call (os.environ.get(...), load_token()).
SECRET_KEYS="(GITHUB_TOKEN|API_KEY|SECRET|password|private_key)"
SECRET_REFERENCES="${SECRET_KEYS}[\"']?[[:space:]]*(=|:)[[:space:]]*[\"']?(\\$|[A-Za-z_][A-Za-z0-9_.]*\\()"
# added_lines: FILE:LINE for each line the staged diff adds; a match already
# in history is not this commit's. Also skip .tmpl files from secret
# scanning as they contain many false positive markers.
added_lines() {
  local f
  while IFS= read -r f; do
    [[ -n "$f" && "$f" != *.tmpl* ]] || continue
    # Added lines follow the first hunk header; the +++ before it is the
    # file name, not content.
    git diff --cached -U0 --no-color --no-ext-diff -- "$f" |
      awk -v f="$f" '/^@@/ { h = 1; next } h && /^\+/ { print f ":" substr($0, 2) }'
  done <<<"$STAGED_FILES"
}
# secret_hits: the added lines that look like a secret written down.
secret_hits() {
  added_lines | grep -EiE "$SENSITIVE_PATTERNS" | grep -vE "$SECRET_EXCLUDES" |
    grep -viE "$SECRET_REFERENCES" | grep -viE "dummy|placeholder|example|test|sk-placeholder|\\{\\{"
}
# check_secrets: print the scan's result and list the hits; 1 when any.
check_secrets() {
  local hits
  hits="$(secret_hits 2>/dev/null)" || true
  if [[ -z "$hits" ]]; then
    printf '%b\\n' "${GREEN}PASSED${NC}"
    return 0
  fi
  printf '%b\\n' "${RED}FAILED${NC}"
  printf '%b\\n' "      ${YELLOW}⚠ Potential secret detected in staged files:${NC}"
  printf '%s\n' "$hits" | sed 's/^/      /'
  return 1
}
check_secrets || FAILED=1

# --- 👻 2. Ghost Path Linter ---
echo -n "   👻 Checking for hardcoded paths... "
# Exclude test files, documentation, the hook itself, Nix files, and template backups
GHOST_EXCLUDES="test_|assertions.sh|pre-commit|INTEROP.md|WSL2_NIX_TROUBLESHOOTING.md|\.nix|\.backup|\.github/workflows/"
if echo "$STAGED_FILES" | xargs grep -rIE '"/home/(linuxbrew)?[^$]|/Users/[^$]' /dev/null | grep -v "linuxbrew" | grep -vE "$GHOST_EXCLUDES" >/dev/null 2>&1; then
  printf '%b\\n' "${RED}FAILED${NC}"
  printf '%b\\n' "      ${YELLOW}⚠ Literal home paths detected (use \$HOME or ~ instead):${NC}"
  echo "$STAGED_FILES" | xargs grep -rIE '"/home/(linuxbrew)?[^$]|/Users/[^$]' /dev/null | grep -v "linuxbrew" | grep -vE "$GHOST_EXCLUDES" | sed 's/^/      /'
  FAILED=1
else
  printf '%b\\n' "${GREEN}PASSED${NC}"
fi

# --- 🐚 3. ShellCheck Hygiene ---
if command -v shellcheck >/dev/null 2>&1; then
  echo -n "   🐚 Running ShellCheck... "
  # ONLY run on actual .sh files, NOT .tmpl files (Go templates break shellcheck)
  # Also exclude files that contain Zsh-specific syntax that might trigger false positives in sh mode
  SHELL_FILES=$(echo "$STAGED_FILES" | grep -E '\.sh$' | grep -v "\.tmpl" || true)
  if [[ -n "$SHELL_FILES" ]]; then
    if ! echo "$SHELL_FILES" | xargs shellcheck -x --severity=error -e SC1091,SC2296,SC2142 >/dev/null 2>&1; then
      printf '%b\\n' "${RED}FAILED${NC}"
      printf '%b\\n' "      ${YELLOW}⚠ Shell syntax errors detected:${NC}"
      echo "$SHELL_FILES" | xargs shellcheck -x --severity=error -e SC1091,SC2296,SC2142 | sed 's/^/      /'
      FAILED=1
    else
      printf '%b\\n' "${GREEN}PASSED${NC}"
    fi
  else
    printf '%b\\n' "${YELLOW}SKIPPED${NC} (no .sh files)"
  fi
fi
# --- 🧹 4. Formatting Audit ---
echo -n "   🧹 Checking formatting... "
# Find files with trailing whitespace, excluding SVGs and other formats where it might be intentional or harmless.
# A space or tab before the line end (or before the CR of a CRLF line):
# .gitattributes checks *.ps1, *.bat and *.cmd out with CRLF, and the CR
# itself is not trailing whitespace. -I skips binary files (an icon's bytes
# are not lines), here and in the merge-marker check.
OFFENDING_WHITESPACE=$(echo "$STAGED_FILES" | grep -vE '\.(svg|md)$' | xargs grep -Il '[[:blank:]][[:cntrl:]]\{0,1\}$' /dev/null || true)
# Use defused patterns to avoid self-detection
MERGE_START="^<<<<<<< "
MERGE_END="^>>>>>>> "
MERGE_DIV="^=======$"
if [[ -n "$OFFENDING_WHITESPACE" ]]; then
  printf '%b\\n' "${RED}FAILED${NC}"
  printf '%b\\n' "      ${YELLOW}⚠ Trailing whitespace found in staged files:${NC}"
  echo "      ${OFFENDING_WHITESPACE//$'\n'/$'\n'      }"
  FAILED=1
elif echo "$STAGED_FILES" | xargs grep -IlE "$MERGE_START|$MERGE_END|$MERGE_DIV" /dev/null >/dev/null 2>&1; then
  printf '%b\\n' "${RED}FAILED${NC}"
  printf '%b\\n' "      ${YELLOW}⚠ Unresolved merge markers found in staged files:${NC}"
  echo "$STAGED_FILES" | xargs grep -IlE "$MERGE_START|$MERGE_END|$MERGE_DIV" /dev/null | sed 's/^/      /'
  FAILED=1
else
  printf '%b\\n' "${GREEN}PASSED${NC}"
fi

# --- 🏛️ 5. Signature Guard ---
if echo "$STAGED_FILES" | grep -q "^README.md$"; then
  echo -n "   🏛️  Checking README signature... "
  EXPECTED_ARCHITECT='**THE ARCHITECT** ᛫ [Sebastien Rousseau](https://sebastienrousseau.com)'
  EXPECTED_ENGINE='**THE ENGINE** ᛞ [EUXIS](https://github.com/sebastienrousseau/euxis) ᛫ Enterprise Unified Execution Intelligence System'
  README_CONTENT=$(git show :README.md 2>/dev/null || cat README.md)
  if echo "$README_CONTENT" | grep -qF "$EXPECTED_ARCHITECT" && echo "$README_CONTENT" | grep -qF "$EXPECTED_ENGINE"; then
    printf '%b\\n' "${GREEN}PASSED${NC}"
  else
    # Auto-add the signature footer before ## License (or at EOF)
    tmp_footer=$(mktemp)
    _cleanup_files+=("$tmp_footer")
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
    printf '%b\\n' "${GREEN}FIXED${NC} (auto-added)"
  fi
fi

echo ""
if [[ $FAILED -eq 1 ]]; then
  printf '%b\\n' "${RED}${BOLD}❌ Audit failed.${NC} Please fix the issues above before committing."
  printf '%b\\n' "   (Use --no-verify to bypass if absolutely necessary)"
  exit 1
else
  printf '%b\n' "${GREEN}${BOLD}✅ Audit passed.${NC} v0.2.542 standards maintained."
  exit 0
fi
