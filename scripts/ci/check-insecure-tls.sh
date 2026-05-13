#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# =============================================================================
# check-insecure-tls.sh — block `curl -k` / `curl --insecure` /
# `wget --no-check-certificate` patterns from landing.
#
# Invoked as a pre-commit local hook (no filename args; scans the repo).
# Extracted from `config/pre-commit-config.yaml` under #866 so the line
# is yamllint-clean and the matcher can be tested in isolation.
#
# Matcher uses awk for proper tokenization (the previous inline grep
# regex false-positive'd `-k` inside package names like `-keyring`).
# =============================================================================

set -euo pipefail

ROOT="${1:-.}"

matches=$(
  grep -rln \
    --include='*.sh' --include='*.bash' --include='*.zsh' --include='*.tmpl' \
    --exclude-dir='.git' \
    --exclude='check-insecure-tls.sh' \
    -E '\b(curl|wget)\b' \
    "$ROOT" 2>/dev/null |
    xargs -I{} awk '
      # Each input line tokenized on whitespace. Flag if the line uses
      # curl/wget and a known insecure flag appears as a standalone token.
      {
        has_curl = 0; has_wget = 0
        bad = ""
        for (i = 1; i <= NF; i++) {
          tok = $i
          if (tok == "curl") has_curl = 1
          if (tok == "wget") has_wget = 1
          if (has_curl && (tok == "-k" || tok == "--insecure" || tok ~ /^--insecure=/)) {
            bad = tok
          }
          if (has_wget && (tok == "--no-check-certificate" || tok ~ /^--no-check-certificate=/)) {
            bad = tok
          }
        }
        if (bad != "") printf "%s:%d:%s\n", FILENAME, NR, bad
      }
    ' {} 2>/dev/null
)

if [[ -n "$matches" ]]; then
  echo "ERROR: Insecure TLS patterns found." >&2
  echo "$matches" >&2
  echo "Remove the flag or, if absolutely required, pin the cert and document the why." >&2
  exit 1
fi
