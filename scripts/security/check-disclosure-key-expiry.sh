#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
#
# scripts/security/check-disclosure-key-expiry.sh
#
# Reads the disclosure public key from `docs/security/security-pubkey.asc`,
# parses its expiry, and exits non-zero when the remaining lifetime is
# below threshold. Closes the R3 audit N2 finding (no automated alert
# for the 2029-05-15 expiry).
#
# Two thresholds:
#   --warn-days N    Emit a `::warning::` if expiry is < N days away.
#                    Default 90.
#   --fail-days N    Exit 1 (CI failure) if expiry is < N days away.
#                    Default 30.
#
# Usage:
#   bash scripts/security/check-disclosure-key-expiry.sh
#   bash scripts/security/check-disclosure-key-expiry.sh --warn-days 180 --fail-days 60
#
# Designed to run from `.github/workflows/verify-gpg-wkd.yml` on the
# weekly schedule, and from a maintainer's local pre-release sanity
# check. Does NOT require network — reads the in-repo .asc only.

set -euo pipefail

WARN_DAYS=90
FAIL_DAYS=30

while [[ $# -gt 0 ]]; do
  case "$1" in
    --warn-days)
      WARN_DAYS="$2"
      shift 2
      ;;
    --fail-days)
      FAIL_DAYS="$2"
      shift 2
      ;;
    -h | --help)
      sed -n '5,25p' "${BASH_SOURCE[0]}"
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ASC="$REPO_ROOT/docs/security/security-pubkey.asc"

if [[ ! -f "$ASC" ]]; then
  echo "::error::no public key at $ASC" >&2
  exit 2
fi

if ! command -v gpg >/dev/null 2>&1; then
  echo "::warning::gpg not installed — cannot verify key expiry" >&2
  exit 0
fi

# Import into a throwaway keyring so we don't pollute the user's real one.
GNUPGHOME="$(mktemp -d -t dot-disclosure-key.XXXXXX)"
export GNUPGHOME
chmod 700 "$GNUPGHOME"
trap 'rm -rf "$GNUPGHOME"' EXIT

# gpg can emit harmless warnings ("keyboxd older than us", "gpg-agent
# IPC failed" in fresh GNUPGHOME, etc.) and exit non-zero under
# `set -e` even when the import itself succeeded. Verify success by
# checking the err log for the literal `imported: N` (N >= 1) line
# rather than trusting gpg's exit code.
gpg --batch --import "$ASC" >/dev/null 2>"$GNUPGHOME/import.err" || true
if ! grep -qE '^gpg:[[:space:]]*imported: [1-9]' "$GNUPGHOME/import.err"; then
  echo "::error::gpg import failed for $ASC" >&2
  cat "$GNUPGHOME/import.err" >&2
  exit 2
fi

# `--with-colons` field 7 of the `pub:` line is the expiry in Unix
# seconds; 0 means no expiry.
expires=$(gpg --with-colons --fingerprint 2>/dev/null | awk -F: '/^pub:/{print $7; exit}')

if [[ -z "$expires" || "$expires" == "0" ]]; then
  echo "::warning::disclosure key has no expiry — set one per docs/security/KEY_ROTATION.md" >&2
  exit 0
fi

now=$(date -u +%s)
remaining_days=$(((expires - now) / 86400))

expires_date=$(date -u -r "$expires" '+%Y-%m-%d' 2>/dev/null || date -u -d "@$expires" '+%Y-%m-%d' 2>/dev/null || echo "(date format unknown)")

echo "Disclosure key expires: $expires_date ($remaining_days days from now)"
echo "  warn threshold: $WARN_DAYS days"
echo "  fail threshold: $FAIL_DAYS days"

if ((remaining_days < FAIL_DAYS)); then
  echo "::error::Disclosure key expires in $remaining_days days. Rotate now per docs/security/KEY_ROTATION.md." >&2
  exit 1
fi

if ((remaining_days < WARN_DAYS)); then
  echo "::warning::Disclosure key expires in $remaining_days days. Schedule rotation per docs/security/KEY_ROTATION.md." >&2
fi

exit 0
