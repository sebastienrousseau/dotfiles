#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# Regression for: v0.2.548 L4 — the gitleaks config's generic stopwords
# (`test`, `example`), substring allowlist (`deadbeef`, `cafebabe`) and the
# wholesale `docs/**/*.md` exclusion suppressed real-shaped credentials.
# Runs gitleaks with the repository config against generated fixtures and
# asserts each one is reported.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

GITLEAKS_CONF="$REPO_ROOT/config/gitleaks.toml"

if ! command -v gitleaks >/dev/null 2>&1; then
  echo "SKIP: gitleaks not installed"
  exit 0
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Assembled at runtime so this file never holds a secret-shaped literal.
stripe_test_key() { printf '%s%s' 'sk_te' 'st_51Hq8ZrKj2Lm9Np4Qr7St0Uv3Wx6Yz'; }
github_pat_with() { printf '%s%s%s' 'gh' 'p_' "$1"; }

# Scans one fixture directory with the repo config; prints the rule ids.
scan_rules() {
  local dir="$1" report="$WORK/report.json"
  (cd "$dir" && gitleaks dir --config "$GITLEAKS_CONF" --no-banner \
    --gitleaks-ignore-path "$WORK/none" -f json -r "$report" . >/dev/null 2>&1) || true
  jq -r '.[].RuleID' "$report" 2>/dev/null | sort -u | tr '\n' ' '
}

new_fixture() {
  local d="$WORK/$1"
  mkdir -p "$d/docs/guides"
  printf '%s\n' "$d"
}

echo "Testing gitleaks config detection..."

test_start "gitleaks_reports_stripe_test_key"
d="$(new_fixture stripe)"
printf 'export STRIPE_SECRET_KEY="%s"\n' "$(stripe_test_key)" >"$d/env.sh"
assert_contains "stripe-access-token" "$(scan_rules "$d")" \
  "a Stripe sk_test_ key must not be hidden by a 'test' stopword"

test_start "gitleaks_reports_token_containing_deadbeef"
d="$(new_fixture deadbeef)"
printf 'GITHUB_TOKEN=%s\n' "$(github_pat_with 'aB3deadbeefXk9Lm2Np5Qr8St1Uv4Wx7Yz0Cd6')" >"$d/env.sh"
assert_contains "github-pat" "$(scan_rules "$d")" \
  "a token containing 'deadbeef' must not be allowlisted by substring"

test_start "gitleaks_reports_secret_in_docs_markdown"
d="$(new_fixture docs)"
printf '# Setup\n\nGITHUB_TOKEN=%s\n' "$(github_pat_with 'Zq8Xw2Vu5Ts9Rq3Po7Nm1Lk4Jh6Gf0Ed2Cb8Ay')" >"$d/docs/guides/setup.md"
assert_contains "github-pat" "$(scan_rules "$d")" \
  "a credential in docs/**/*.md must be scanned"

test_start "gitleaks_keeps_published_ssh_fingerprint_allowlisted"
d="$(new_fixture fingerprint)"
printf 'signing key = SHA256:%s\n' 'f6FG+guRNtT3R36oQFS4oWCx1d10nm+BoaIL3Tkh1r4' >"$d/docs/VERIFY.md"
assert_equals "" "$(scan_rules "$d")" "the published SSH fingerprint stays allowlisted"

echo ""
print_summary
