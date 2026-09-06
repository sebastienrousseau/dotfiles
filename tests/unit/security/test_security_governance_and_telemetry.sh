#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for three security-side scripts, all driven with
# sandbox stubs so nothing on the host is scanned, disabled or re-keyed:
#
#   scripts/diagnostics/secret-governance.sh — staged-content secret scan
#   scripts/security/telemetry-kill.sh       — opt-in telemetry disabling
#   scripts/secrets/age-init.sh              — age key + chezmoi config setup
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

GOVERNANCE="$REPO_ROOT/scripts/diagnostics/secret-governance.sh"
TELEMETRY="$REPO_ROOT/scripts/security/telemetry-kill.sh"
AGE_INIT="$REPO_ROOT/scripts/secrets/age-init.sh"
REAL_BASH="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

BIN="$DOTFILES_COV_TMPDIR/bin"
OUTF="$DOTFILES_COV_TMPDIR/out.txt"
ERRF="$DOTFILES_COV_TMPDIR/err.txt"
MERGED="$DOTFILES_COV_TMPDIR/merged.txt"
export GOV_FIX="$DOTFILES_COV_TMPDIR/gov"
mkdir -p "$GOV_FIX"
: >"$GOV_FIX/staged"
: >"$GOV_FIX/content"

run() {
  "$@" >"$OUTF" 2>"$ERRF" </dev/null
  RC=$?
  [[ "${DOTFILES_COV_ECHO_STDERR:-0}" == "1" ]] && cat "$ERRF" >&2
  return 0
}
out_has() {
  {
    cat "$OUTF"
    grep -v '^+*@COV@' "$ERRF" 2>/dev/null
  } >"$MERGED"
  assert_file_contains "$MERGED" "$1" "${2:-output contains $1}"
}

# ── secret-governance ───────────────────────────────────────────────────
# `git diff --cached --name-only` lists the staged paths and `git show :path`
# prints their staged content; both come from fixtures.
cat >"$BIN/git" <<STUB
#!$REAL_BASH
for a in "\$@"; do
  case "\$a" in
    diff) cat "\$GOV_FIX/staged"; exit 0 ;;
    show) cat "\$GOV_FIX/content"; exit 0 ;;
  esac
done
exit 0
STUB
chmod +x "$BIN/git"

test_start "governance_passes_when_nothing_is_staged"
: >"$GOV_FIX/staged"
run bash "$GOVERNANCE"
assert_equals 0 "$RC" "rc"
out_has "no staged files" "message"

test_start "governance_passes_on_clean_staged_content"
printf 'src/app.ts\n' >"$GOV_FIX/staged"
printf 'const answer = 42;\n' >"$GOV_FIX/content"
run bash "$GOVERNANCE"
assert_equals 0 "$RC" "rc"
out_has "Secret governance passed." "verdict"

test_start "governance_flags_a_plaintext_secret_pattern"
printf 'api_key = "super-secret-value"\n' >"$GOV_FIX/content"
run bash "$GOVERNANCE"
assert_equals 1 "$RC" "rc"
out_has "potential plaintext secret pattern detected" "finding"
out_has "Secret governance failed: 1 violation(s)." "verdict"

test_start "governance_strict_mode_catches_a_leaked_managed_value"
# Strict mode compares the staged content against every value the secrets
# provider knows. Drive the file-backed `plain-enc` provider: the index and
# store live in the sandbox and `age -d` is a stub that prints the plaintext.
SECRETS_HOME="$DOTFILES_COV_TMPDIR/secrets"
mkdir -p "$SECRETS_HOME/store"
printf 'API_TOKEN\nSHORT\n' >"$SECRETS_HOME/index.txt"
printf 'leaked-token-value\n' >"$SECRETS_HOME/store/API_TOKEN.plain"
printf 'abc\n' >"$SECRETS_HOME/store/SHORT.plain"
: >"$SECRETS_HOME/store/API_TOKEN.age"
: >"$SECRETS_HOME/store/SHORT.age"
printf 'AGE-SECRET-KEY-TEST\n' >"$SECRETS_HOME/key.txt"
printf '#!%s\n' "$REAL_BASH" >"$BIN/age"
cat >>"$BIN/age" <<'STUB'
# `age -d -i <key> <file>` → print the plaintext stored beside <file>.
last=""
for a in "$@"; do last="$a"; done
cat "${last%.age}.plain"
STUB
chmod +x "$BIN/age"
export DOTFILES_SECRETS_PROVIDER=plain-enc
export DOT_SECRETS_HOME="$SECRETS_HOME"
export DOT_SECRETS_STORE_DIR="$SECRETS_HOME/store"
export DOT_SECRETS_INDEX_FILE="$SECRETS_HOME/index.txt"
export DOT_SECRETS_AGE_KEY="$SECRETS_HOME/key.txt"

printf 'token = leaked-token-value\n' >"$GOV_FIX/content"
run env DOTFILES_SECRETS_STRICT_MODE=1 "$REAL_BASH" "$GOVERNANCE"
assert_equals 1 "$RC" "rc"
out_has "exact managed secret value leaked for key: API_TOKEN" "finding names the key"
out_has "Secret governance failed: 1 violation(s)." "verdict"

test_start "governance_strict_mode_ignores_short_and_absent_values"
printf 'nothing to see here\n' >"$GOV_FIX/content"
run env DOTFILES_SECRETS_STRICT_MODE=1 "$REAL_BASH" "$GOVERNANCE"
assert_equals 0 "$RC" "rc"
out_has "Secret governance passed." "verdict"
unset DOTFILES_SECRETS_PROVIDER DOT_SECRETS_HOME DOT_SECRETS_STORE_DIR \
  DOT_SECRETS_INDEX_FILE DOT_SECRETS_AGE_KEY

# ── telemetry-kill ──────────────────────────────────────────────────────
test_start "telemetry_kill_is_opt_in"
run bash "$TELEMETRY"
assert_equals 1 "$RC" "rc"
out_has "disabled by default" "refusal"
out_has "DOTFILES_TELEMETRY=1" "opt-in hint"

test_start "telemetry_kill_dry_run_lists_the_commands_it_would_run"
run bash "$TELEMETRY" --dry-run
assert_equals 0 "$RC" "rc"
out_has "dry-run (no changes will be made)" "mode announced"
out_has "[dry-run]" "commands echoed, not executed"
out_has "Disabling" "platform section reached"

test_start "telemetry_kill_dry_run_accepts_the_short_flag"
run bash "$TELEMETRY" -n
assert_equals 0 "$RC" "rc"
out_has "dry-run" "mode announced"

test_start "telemetry_kill_reports_an_unsupported_platform"
cat >"$BIN/uname" <<STUB
#!$REAL_BASH
[[ "\${1:-}" == "-s" ]] && echo "Plan9" && exit 0
echo "Plan9"
STUB
chmod +x "$BIN/uname"
run bash "$TELEMETRY" --dry-run
assert_equals 1 "$RC" "rc"
out_has "Unsupported OS" "error"
rm -f "$BIN/uname"

# ── age-init ────────────────────────────────────────────────────────────
cat >"$BIN/age-keygen" <<STUB
#!$REAL_BASH
if [[ "\${1:-}" == "-o" ]]; then
  printf '# created: 2026-01-01\\nAGE-SECRET-KEY-TEST\\n' >"\$2"
  exit 0
fi
if [[ "\${1:-}" == "-y" ]]; then
  echo "age1testrecipientvalue"
  exit 0
fi
exit 0
STUB
chmod +x "$BIN/age-keygen"

test_start "age_init_creates_a_key_and_writes_the_chezmoi_config"
CFG="$HOME/.config/chezmoi/chezmoi.toml"
KEY="$HOME/.config/chezmoi/key.txt"
rm -f "$CFG" "$KEY"
run bash "$AGE_INIT"
assert_equals 0 "$RC" "rc"
out_has "Age key created at" "key creation reported"
out_has "Updated" "config update reported"
assert_file_exists "$KEY" "key written"
assert_file_contains "$CFG" 'encryption = "age"' "encryption declared at top level"
assert_file_contains "$CFG" "[age]" "age section written"
assert_file_contains "$CFG" "age1testrecipientvalue" "recipient recorded"

test_start "age_init_keeps_an_existing_key_and_rewrites_the_age_block"
printf 'encryption = "gpg"\n\n[age]\nidentity = "stale"\n\n[data]\nname = "keep"\n' >"$CFG"
run bash "$AGE_INIT"
assert_equals 0 "$RC" "rc"
out_has "Age key already exists" "key reused"
assert_file_contains "$CFG" "keep" "unrelated config preserved"
assert_file_contains "$CFG" "age1testrecipientvalue" "recipient refreshed"
assert_true "[[ \$(grep -c '^encryption =' '$CFG') -eq 1 ]]" "no duplicate encryption key"
assert_true "! grep -q 'stale' '$CFG'" "previous age block removed"

test_start "age_init_requires_age_keygen"
NOAGE="$DOTFILES_COV_TMPDIR/noage"
mkdir -p "$NOAGE"
ln -sf "$REAL_BASH" "$NOAGE/bash"
for c in printf echo mkdir chmod python3 cat; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$NOAGE/$c"
done
run env PATH="$NOAGE" "$REAL_BASH" "$AGE_INIT"
assert_equals 1 "$RC" "rc"
out_has "age-keygen not found" "error"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
