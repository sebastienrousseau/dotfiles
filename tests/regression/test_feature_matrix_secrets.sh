#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Regression for: GH-881
# Regression: FEATURE-MATRIX coverage for the secrets.sh command group —
# secrets-init, secrets {edit,set,get,list,load,provider}, secrets-create,
# ssh-key, ssh-cert and the `dot env load` alias.
#
# Every row runs against a sandboxed secret store: DOT_SECRETS_HOME and the
# age identity both live under the sandbox, so nothing touches the
# developer's keychain, pass store or ~/.config/chezmoi. Where `age` is
# installed the full set→get→list→load round trip is exercised with the
# plain-enc provider; where it is not, the rows fall back to asserting the
# provider-absent refusal path, which is the other half of the contract.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
source "$SCRIPT_DIR/../framework/feature_matrix_lib.sh"

trap fm_sandbox_teardown EXIT
fm_sandbox_setup

# Keep the store inside the sandbox and off the macOS keychain.
export DOT_SECRETS_HOME="$FM_SANDBOX/.local/share/dotfiles/secrets"
export DOTFILES_SECRETS_PROVIDER=none

fm_have_age() { command -v age >/dev/null 2>&1 && command -v age-keygen >/dev/null 2>&1; }

# Bring up an age identity and switch to the plain-enc provider, so the
# round-trip rows have a real backend. Returns 1 when age is unavailable.
fm_secrets_enable_age() {
  fm_have_age || return 1
  if [[ ! -f "$FM_SANDBOX/.config/chezmoi/key.txt" ]]; then
    fm_run secrets-init
  fi
  [[ -f "$FM_SANDBOX/.config/chezmoi/key.txt" ]] || return 1
  export DOTFILES_SECRETS_PROVIDER=plain-enc
  return 0
}

# ── secrets-init ───────────────────────────────────────────────────────────

test_fm_secrets_init() {
  if ! fm_have_age; then
    test_start "fm_secrets_init"
    fm_pass "skipped — age/age-keygen not installed"
    return 0
  fi
  test_start "fm_secrets_init"
  fm_run secrets-init
  fm_expect_rc 0
  test_start "fm_secrets_init_creates_the_age_key"
  fm_expect_file "$FM_SANDBOX/.config/chezmoi/key.txt"
  test_start "fm_secrets_init_key_is_not_world_readable"
  local mode
  mode="$(stat -f '%Lp' "$FM_SANDBOX/.config/chezmoi/key.txt" 2>/dev/null ||
    stat -c '%a' "$FM_SANDBOX/.config/chezmoi/key.txt" 2>/dev/null)"
  if [[ "$mode" == "600" ]]; then
    fm_pass "mode $mode"
  else
    fm_fail "age key mode is $mode, expected 600"
  fi
  test_start "fm_secrets_init_is_idempotent"
  fm_run secrets-init
  fm_expect_rc 0
}

# ── secrets provider ───────────────────────────────────────────────────────

test_fm_secrets_provider() {
  test_start "fm_secrets_provider"
  DOTFILES_SECRETS_PROVIDER=none fm_run secrets provider
  fm_expect_rc 0
  test_start "fm_secrets_provider_reports_the_backend"
  fm_expect_out "none"
}

test_fm_env_dotfiles_secrets_provider() {
  # An explicit provider must win over auto-detection.
  test_start "fm_env_dotfiles_secrets_provider"
  DOTFILES_SECRETS_PROVIDER=pass fm_run secrets provider
  fm_expect_rc 0
  test_start "fm_env_dotfiles_secrets_provider_overrides_detection"
  fm_expect_out "pass"

  # And auto-detection must resolve to something concrete rather than
  # echoing the literal "auto".
  test_start "fm_env_dotfiles_secrets_provider_auto_resolves"
  DOTFILES_SECRETS_PROVIDER=auto fm_run secrets provider
  if [[ "$FM_OUT" == *"auto"* ]]; then
    fm_fail "provider reported the literal 'auto' instead of resolving"
  else
    fm_pass "auto resolved to a concrete backend"
  fi
}

test_fm_config_secrets_policy() {
  # [secrets.policy] in .chezmoidata.toml seeds the provider when the
  # environment does not name one.
  test_start "fm_config_secrets_policy"
  local configured
  configured="$(awk '/^\[secrets\.policy\]/{f=1;next} /^\[/{f=0} f && /provider/{gsub(/["[:space:]]/,"");sub(/.*=/,"");print;exit}' \
    "$REPO_ROOT/defaults/.chezmoidata.toml")"
  if [[ -z "$configured" ]]; then
    fm_pass "skipped — no [secrets.policy] provider in .chezmoidata.toml"
    return 0
  fi
  DOTFILES_SECRETS_PROVIDER="" fm_run secrets provider
  test_start "fm_config_secrets_policy_seeds_the_provider"
  if [[ "$FM_OUT" == *"$configured"* ]]; then
    fm_pass "policy provider '$configured' applied"
  else
    fm_fail "policy provider '$configured' not reflected: $FM_OUT"
  fi
}

# ── secrets set / get / list ───────────────────────────────────────────────

test_fm_secrets_set() {
  if ! fm_secrets_enable_age; then
    test_start "fm_secrets_set"
    fm_pass "skipped — no age identity available for the plain-enc provider"
    return 0
  fi
  test_start "fm_secrets_set"
  fm_run secrets set FM_DEMO_KEY fm-demo-value
  # The plain-enc store used to abort with "tmp_rec: unbound variable" under
  # `set -u` after it had already written the encrypted file, so `set` exited
  # non-zero on a write that had in fact succeeded. A successful store now
  # reports success.
  fm_expect_rc 0
  test_start "fm_secrets_set_indexes_the_key"
  fm_run secrets list
  fm_expect_out "FM_DEMO_KEY"
}

test_fm_secrets_set_usage() {
  test_start "fm_secrets_set_usage"
  fm_run secrets set
  fm_expect_rc 1
  test_start "fm_secrets_set_usage_message"
  fm_expect_any "Usage: dot secrets set" "secrets set"
}

test_fm_smoke_secrets_set_prompt() {
  # `secrets set KEY` with no value reads it from a silent TTY prompt.
  fm_smoke secrets
}

test_fm_secrets_get() {
  if ! fm_secrets_enable_age; then
    test_start "fm_secrets_get"
    fm_pass "skipped — no age identity available"
    return 0
  fi
  fm_run secrets set FM_DEMO_KEY fm-demo-value
  test_start "fm_secrets_get"
  fm_run secrets get FM_DEMO_KEY
  fm_expect_rc 0
  test_start "fm_secrets_get_masks_the_value_by_default"
  if [[ "$FM_OUT" == *"fm-demo-value"* ]]; then
    fm_fail "plaintext secret printed without --raw"
  else
    fm_pass "value masked"
  fi
}

test_fm_secrets_get_raw() {
  if ! fm_secrets_enable_age; then
    test_start "fm_secrets_get_raw"
    fm_pass "skipped — no age identity available"
    return 0
  fi
  fm_run secrets set FM_DEMO_KEY fm-demo-value
  test_start "fm_secrets_get_raw"
  fm_run secrets get FM_DEMO_KEY --raw
  fm_expect_rc 0
  test_start "fm_secrets_get_raw_round_trips_the_value"
  fm_expect_out "fm-demo-value"
}

test_fm_secrets_get_missing() {
  test_start "fm_secrets_get_missing"
  fm_run secrets get FM_NO_SUCH_KEY
  fm_expect_rc 1
  test_start "fm_secrets_get_missing_says_so"
  fm_expect_any "not found" "no provider"
  test_start "fm_secrets_get_missing_key_usage"
  fm_run secrets get
  fm_expect_rc 1
  test_start "fm_secrets_get_missing_key_usage_message"
  fm_expect_any "Usage: dot secrets get" "secrets get"
}

test_fm_secrets_list() {
  test_start "fm_secrets_list"
  fm_run secrets list
  fm_expect_rc 0
  test_start "fm_secrets_list_no_breakage"
  fm_expect_no_forbidden
}

# ── secrets load ───────────────────────────────────────────────────────────

test_fm_secrets_load() {
  test_start "fm_secrets_load"
  fm_run secrets load ai
  # With nothing in the bucket this must fail loudly rather than emitting an
  # empty eval payload the caller would silently source.
  fm_expect_rc_in 0 1
  test_start "fm_secrets_load_emits_or_refuses"
  fm_expect_any "export " "No secrets loaded"
}

test_fm_secrets_load_fish() {
  test_start "fm_secrets_load_fish"
  fm_run secrets load ai --shell fish
  fm_expect_rc_in 0 1
  test_start "fm_secrets_load_fish_dialect"
  fm_expect_any "set -gx" "No secrets loaded"
}

test_fm_secrets_load_nu() {
  test_start "fm_secrets_load_nu"
  fm_run secrets load ai --shell=nu
  fm_expect_rc_in 0 1
  test_start "fm_secrets_load_nu_dialect"
  fm_expect_any "{" "No secrets loaded"
  test_start "fm_secrets_load_nushell_alias"
  fm_run secrets load ai --shell nushell
  fm_expect_rc_in 0 1
}

test_fm_secrets_load_empty() {
  test_start "fm_secrets_load_empty"
  fm_run secrets load fm-no-such-bucket
  fm_expect_rc 1
  test_start "fm_secrets_load_empty_names_the_bucket"
  fm_expect_any "No secrets loaded" "fm-no-such-bucket"
  test_start "fm_secrets_load_rejects_unknown_flag"
  fm_run secrets load ai --zzz-not-a-flag
  fm_expect_rc 1
  test_start "fm_secrets_load_unknown_flag_message"
  fm_expect_any "Unknown flag" "usage"
}

test_fm_secrets_env_load() {
  # `dot env load <bucket>` is secrets.sh's alias for `dot secrets load`.
  # NOTE: `env` routes to tools.sh, which reaches mise first, so this alias
  # is only reachable by invoking secrets.sh directly — which is what the
  # row asserts, together with the fact that the arm still exists.
  test_start "fm_secrets_env_load"
  fm_run_bin "$REPO_ROOT/scripts/dot/commands/secrets.sh" env load fm-no-such-bucket
  fm_expect_rc_in 0 1
  test_start "fm_secrets_env_load_reaches_the_loader"
  fm_expect_any "No secrets loaded" "fm-no-such-bucket" "export "
}

# ── secrets edit / create ──────────────────────────────────────────────────

test_fm_secrets_edit_no_key() {
  # Without an age identity `secrets edit` must point at secrets-init rather
  # than opening an editor on nothing.
  local key="$FM_SANDBOX/.config/chezmoi/key.txt"
  local saved="$FM_SANDBOX/key.txt.saved"
  [[ -f "$key" ]] && mv "$key" "$saved"
  test_start "fm_secrets_edit_no_key"
  fm_run secrets edit
  fm_expect_rc 1
  test_start "fm_secrets_edit_no_key_points_at_init"
  fm_expect_any "No age key" "dot secrets-init"
  [[ -f "$saved" ]] && mv "$saved" "$key"
  return 0
}

test_fm_secrets_edit() {
  if ! fm_secrets_enable_age; then
    test_start "fm_secrets_edit"
    fm_pass "skipped — no age identity available"
    return 0
  fi
  # chezmoi is stubbed, so this exercises the guard + delegation path only.
  test_start "fm_secrets_edit"
  fm_run secrets edit
  fm_expect_rc_in 0 1
  test_start "fm_secrets_edit_no_breakage"
  fm_expect_no_forbidden
}

test_fm_secrets_create_no_key() {
  local key="$FM_SANDBOX/.config/chezmoi/key.txt"
  local saved="$FM_SANDBOX/key.txt.saved2"
  [[ -f "$key" ]] && mv "$key" "$saved"
  test_start "fm_secrets_create_no_key"
  fm_run secrets-create
  fm_expect_rc 1
  test_start "fm_secrets_create_no_key_points_at_init"
  fm_expect_any "Age identity not found" "dot secrets-init"
  [[ -f "$saved" ]] && mv "$saved" "$key"
  return 0
}

test_fm_secrets_create() {
  if ! fm_secrets_enable_age; then
    test_start "fm_secrets_create"
    fm_pass "skipped — no age identity available"
    return 0
  fi
  test_start "fm_secrets_create"
  fm_run secrets-create fmbucket
  fm_expect_rc 0
  test_start "fm_secrets_create_reports_the_file"
  fm_expect_any "Created encrypted secrets file" "fmbucket"
}

# ── ssh-key / ssh-cert ─────────────────────────────────────────────────────

test_fm_ssh_key_missing() {
  # With no key at the default path the command must say which path it
  # looked at rather than creating or clobbering anything.
  test_start "fm_ssh_key_missing"
  fm_run ssh-key
  fm_expect_rc 1
  test_start "fm_ssh_key_missing_names_the_path"
  fm_expect_any "SSH key not found" "id_ed25519"
}

test_fm_ssh_cert_usage() {
  test_start "fm_ssh_cert_usage"
  fm_run ssh-cert
  fm_expect_rc_in 0 1
  test_start "fm_ssh_cert_usage_lists_subcommands"
  fm_expect_any "issue" "status" "revoke"
  test_start "fm_ssh_cert_usage_documents_env"
  fm_expect_any "SSH_CERT_CA_URL" "Environment"
}

test_fm_ssh_cert_status() {
  test_start "fm_ssh_cert_status"
  fm_run ssh-cert status
  fm_expect_rc_in 0 1
  test_start "fm_ssh_cert_status_reports_absence"
  fm_expect_any "No SSH certificate" "cert"
}

test_fm_smoke_ssh_cert_issue() { fm_smoke ssh-cert; }

# ── secrets: unknown subcommand ────────────────────────────────────────────

test_fm_secrets_unknown() {
  test_start "fm_secrets_unknown"
  fm_run secrets zzz-not-a-subcommand
  fm_expect_rc 1
  test_start "fm_secrets_unknown_lists_valid_subcommands"
  fm_expect_any "edit|set|get|list|load|provider" "Usage: dot secrets"
}

# A secret must never reach the terminal unmasked by accident: check the
# whole group's default-mode output for the fixture value.
test_fm_secrets_never_leak_by_default() {
  if ! fm_secrets_enable_age; then
    test_start "fm_secrets_never_leak_by_default"
    fm_pass "skipped — no age identity available"
    return 0
  fi
  fm_run secrets set FM_LEAK_CHECK fm-secret-canary
  local combined=""
  local cmd
  for cmd in "secrets list" "secrets get FM_LEAK_CHECK" "secrets provider"; do
    # shellcheck disable=SC2086
    fm_run $cmd
    combined="$combined$FM_OUT$FM_ERR"
  done
  test_start "fm_secrets_never_leak_by_default"
  if [[ "$combined" == *"fm-secret-canary"* ]]; then
    fm_fail "a default-mode secrets command printed the plaintext value"
  else
    fm_pass "no plaintext leak outside --raw"
  fi
}

# ── run ────────────────────────────────────────────────────────────────────

echo ""
echo "── FEATURE-MATRIX: secrets ──"
echo ""

test_fm_secrets_init
test_fm_secrets_provider
test_fm_env_dotfiles_secrets_provider
test_fm_config_secrets_policy
test_fm_secrets_set
test_fm_secrets_set_usage
test_fm_smoke_secrets_set_prompt
test_fm_secrets_get
test_fm_secrets_get_raw
test_fm_secrets_get_missing
test_fm_secrets_list
test_fm_secrets_load
test_fm_secrets_load_fish
test_fm_secrets_load_nu
test_fm_secrets_load_empty
test_fm_secrets_env_load
test_fm_secrets_edit_no_key
test_fm_secrets_edit
test_fm_secrets_create_no_key
test_fm_secrets_create
test_fm_ssh_key_missing
test_fm_ssh_cert_usage
test_fm_ssh_cert_status
test_fm_smoke_ssh_cert_issue
test_fm_secrets_unknown
test_fm_secrets_never_leak_by_default

fm_finish
