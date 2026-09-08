#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for scripts/dot/commands/secrets.sh: the dispatch table,
# the secrets set/get/list/provider verbs, the policy defaults read out of
# .chezmoidata.toml, and `secrets load` in all three shell dialects.
#
# The secrets provider is forced to `pass` and `pass` itself is a
# PATH-shadowed stub backed by a directory in the sandbox, so no keychain,
# GPG agent or age key on the host is touched. Hand-offs to age-init.sh /
# create-secrets-file.sh / encrypt-ssh-key.sh / chezmoi are intercepted, so
# no key material is created anywhere.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/secrets.sh"
REAL_BASH="${BASH:-$(command -v bash)}"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/dot/commands/secrets.sh must exist"

# ---------------------------------------------------------------------------
# Stubs: a file-backed `pass`, plus interception of every hand-off.
# ---------------------------------------------------------------------------
PASS_STORE="$WORK/pass-store"
mkdir -p "$PASS_STORE"
cat >"$BIN/pass" <<EOF
#!$REAL_BASH
store="$PASS_STORE"
case "\${1:-}" in
  insert)
    key="\${*: -1}"
    mkdir -p "\$store/\$(dirname "\$key")"
    cat >"\$store/\$key"
    ;;
  show)
    key="\${2:-}"
    [[ -f "\$store/\$key" ]] || exit 1
    cat "\$store/\$key"
    ;;
esac
exit 0
EOF
cat >"$BIN/bash" <<EOF
#!$REAL_BASH
case "\${1:-}" in
  *age-init.sh|*create-secrets-file.sh|*encrypt-ssh-key.sh|*ssh-cert.sh)
    printf 'dispatched %s %s\n' "\$(basename "\$1")" "\${*:2}"
    exit "\${DISPATCH_RC:-0}"
    ;;
esac
exec "$REAL_BASH" "\$@"
EOF
cat >"$BIN/chezmoi" <<EOF
#!$REAL_BASH
printf 'chezmoi %s\n' "\$*"
exit 0
EOF
# Belt and braces: `security` is the macOS keychain CLI the provider would
# reach for if the forced provider were ever lost. Fail loudly instead of
# touching the real login keychain.
cat >"$BIN/security" <<EOF
#!$REAL_BASH
echo "refusing to touch the real keychain: security \$*" >&2
exit 1
EOF
chmod +x "$BIN/pass" "$BIN/bash" "$BIN/chezmoi" "$BIN/security"

# A source tree whose .chezmoidata.toml carries a secrets policy and an AI
# bucket, so the policy-env and bucket-key paths have real data to read.
SRC="$WORK/src"
mkdir -p "$SRC/lib/dot" "$SRC/scripts/lib" "$SRC/scripts/dot/commands" \
  "$SRC/scripts/secrets" "$SRC/scripts/security"
for lib in ui.sh utils.sh platform.sh ai-install.sh log.sh verified-download.sh; do
  ln -sf "$REPO_ROOT/lib/dot/$lib" "$SRC/lib/dot/$lib"
done
ln -sf "$REPO_ROOT/scripts/lib/secrets_provider.sh" "$SRC/scripts/lib/secrets_provider.sh"
ln -sf "$SCRIPT_FILE" "$SRC/scripts/dot/commands/secrets.sh"
: >"$SRC/scripts/secrets/age-init.sh"
: >"$SRC/scripts/secrets/create-secrets-file.sh"
: >"$SRC/scripts/secrets/encrypt-ssh-key.sh"
: >"$SRC/scripts/security/ssh-cert.sh"
cat >"$SRC/.chezmoidata.toml" <<'TOML'
[secrets.policy]
provider = "pass"
auto_load = true

[secrets.buckets]
ai = ["OPENAI_API_KEY", "ANTHROPIC_API_KEY"]
empty = []
TOML

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
# _run <script> <args…> — shared runner. The provider is pinned to the
# file-backed `pass` stub so nothing reaches a keychain, GPG agent or age
# key. Stdout is captured; stderr is replayed so the coverage runner keeps
# its xtrace records. Echoes the exit status.
_run() {
  local script="$1" rc=0
  shift
  PATH="$BIN:/usr/bin:/bin" \
    DOTFILES_SHOW_LOGO=0 \
    DOTFILES_SECRETS_PROVIDER="${FORCE_PROVIDER:-pass}" \
    DOT_SECRETS_HOME="$WORK/secrets-home" \
    DOT_SECRETS_STORE_DIR="$WORK/secrets-home/store" \
    DOT_SECRETS_INDEX_FILE="$WORK/secrets-home/index.txt" \
    "$REAL_BASH" "$script" "$@" </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}

# secrets <args…> — the real command file. resolve_source_dir always prefers
# the tree the sourced lib lives in, so this reads the repo's own
# .chezmoidata.toml (which ships no [secrets.buckets] section).
secrets() { _run "$SCRIPT_FILE" "$@"; }

# secrets_fixture <args…> — the same command file reached through a
# synthetic tree, so the source resolver lands on the fixture data file and
# the bucket-backed `load` paths have keys to emit.
secrets_fixture() { _run "$SRC/scripts/dot/commands/secrets.sh" "$@"; }

# ===========================================================================
# Dispatch surface
# ===========================================================================
test_start "usage_on_help_and_no_arguments"
for flag in --help -h help; do
  rc="$(secrets "$flag")"
  assert_equals "0" "$rc" "$flag exits 0"
done
assert_file_contains "$OUT" "secrets-init, secrets, secrets-create" "usage lists the commands"
rc="$(secrets)"
assert_equals "1" "$rc" "no arguments is a usage error"

test_start "an_unknown_command_is_rejected"
rc="$(secrets definitely-not-a-command)"
assert_equals "1" "$rc" "an unknown command fails"
assert_file_contains "$ERR" "Unknown secrets command" "the error names the command"

test_start "secrets_init_delegates_to_age_init"
rc="$(secrets secrets-init --force)"
assert_equals "0" "$rc" "secrets-init exits 0"
assert_file_contains "$OUT" "dispatched age-init.sh --force" "arguments reach age-init.sh"

test_start "secrets_create_and_ssh_helpers_delegate"
secrets secrets-create /tmp/out.age >/dev/null
assert_file_contains "$OUT" "dispatched create-secrets-file.sh /tmp/out.age" "secrets-create routes to its script"
secrets ssh-key ~/.ssh/id_ed25519 >/dev/null
assert_file_contains "$OUT" "dispatched encrypt-ssh-key.sh" "ssh-key routes to its script"
secrets ssh-cert --sign >/dev/null
assert_file_contains "$OUT" "dispatched ssh-cert.sh --sign" "ssh-cert routes to its script"

test_start "secrets_edit_requires_an_age_key"
rc="$(secrets secrets)"
assert_equals "1" "$rc" "editing without a key fails"
assert_file_contains "$ERR" "No age key found" "the error tells the user how to fix it"

test_start "secrets_edit_opens_the_encrypted_file_when_a_key_exists"
mkdir -p "$HOME/.config/chezmoi"
: >"$HOME/.config/chezmoi/key.txt"
rc="$(secrets secrets edit)"
assert_equals "0" "$rc" "edit exits 0 once a key exists"
assert_file_contains "$OUT" "chezmoi edit --apply" "chezmoi is asked to edit the encrypted file"
rm -f "$HOME/.config/chezmoi/key.txt"

test_start "an_unknown_secrets_subcommand_is_rejected"
rc="$(secrets secrets not-a-verb)"
assert_equals "1" "$rc" "an unknown verb fails"
assert_file_contains "$ERR" "edit|set|get|list|load|provider" "the error lists the valid verbs"

# ===========================================================================
# set / get / list / provider
# ===========================================================================
test_start "provider_reports_the_active_provider"
rc="$(secrets secrets provider)"
assert_equals "0" "$rc" "provider exits 0"
assert_file_contains "$OUT" "pass" "the configured provider is reported"

test_start "set_stores_a_value_and_get_reads_it_back"
rc="$(secrets secrets set DEMO_TOKEN s3cret)"
assert_equals "0" "$rc" "set exits 0"
assert_file_contains "$OUT" "Stored" "the store is confirmed"
assert_file_exists "$PASS_STORE/dotfiles/DEMO_TOKEN" "the value reached the provider"
rc="$(secrets secrets get DEMO_TOKEN --raw)"
assert_equals "0" "$rc" "get exits 0"
assert_file_contains "$OUT" "s3cret" "--raw prints the value"

test_start "get_masks_the_value_by_default"
secrets secrets get DEMO_TOKEN >/dev/null
assert_file_contains "$OUT" "***" "the value is masked without --raw"
assert_output_not_contains "s3cret" "cat '$OUT'"

test_start "set_and_get_require_a_key"
rc="$(secrets secrets set)"
assert_equals "1" "$rc" "set without a key fails"
assert_file_contains "$ERR" "Usage: dot secrets set" "the usage line is shown"
rc="$(secrets secrets get)"
assert_equals "1" "$rc" "get without a key fails"

test_start "get_reports_a_missing_secret"
rc="$(secrets secrets get NOT_STORED)"
assert_equals "1" "$rc" "an unknown key fails"
assert_file_contains "$ERR" "Secret not found" "the error names the miss"

test_start "list_prints_indexed_keys"
rc="$(secrets secrets list)"
assert_equals "0" "$rc" "list exits 0"
assert_file_contains "$OUT" "DEMO_TOKEN" "the stored key is listed"

test_start "list_reports_an_empty_index"
rm -rf "$WORK/secrets-home"
rc="$(secrets secrets list)"
assert_equals "0" "$rc" "an empty index is not an error"
assert_file_contains "$OUT" "No secrets indexed" "the empty index is explained"

# ===========================================================================
# load / env load
# ===========================================================================
test_start "load_emits_posix_exports"
secrets secrets set OPENAI_API_KEY sk-test-1 >/dev/null
secrets secrets set ANTHROPIC_API_KEY sk-test-2 >/dev/null
rc="$(secrets_fixture secrets load ai)"
assert_equals "0" "$rc" "load exits 0"
assert_file_contains "$OUT" "export OPENAI_API_KEY=" "the posix dialect exports each key"
assert_file_contains "$OUT" "sk-test-2" "every bucket key is emitted"

test_start "load_emits_fish_and_nu_dialects"
secrets_fixture secrets load ai --shell fish >/dev/null
assert_file_contains "$OUT" "set -gx OPENAI_API_KEY " "fish uses set -gx"
secrets_fixture secrets load ai --shell=nu >/dev/null
assert_file_contains "$OUT" '"OPENAI_API_KEY": "sk-test-1"' "nu emits a NUON record"

test_start "load_rejects_an_unknown_dialect"
# The dialect is validated after the bucket is resolved, so this needs the
# fixture tree's bucket data to get that far.
rc="$(secrets_fixture secrets load ai --shell klingon)"
assert_equals "1" "$rc" "an unknown dialect fails"
assert_file_contains "$ERR" "Unknown shell dialect" "the error names the dialect"

test_start "load_rejects_an_unknown_flag"
rc="$(secrets secrets load --nope)"
assert_equals "1" "$rc" "an unknown flag fails"
assert_file_contains "$ERR" "Unknown flag" "the error names the flag"

test_start "load_reports_a_bucket_the_data_file_does_not_define"
rc="$(secrets secrets load ai)"
assert_equals "1" "$rc" "a data file with no buckets cannot load anything"
assert_file_contains "$ERR" "No secrets loaded for bucket: ai" "the error names the bucket"

test_start "load_reports_an_empty_bucket"
rc="$(secrets_fixture secrets load empty)"
assert_equals "1" "$rc" "a bucket with no resolvable secrets fails"
assert_file_contains "$ERR" "No secrets loaded for bucket: empty" "the error names the bucket"

test_start "env_load_is_an_alias_for_secrets_load"
rc="$(secrets_fixture env load ai)"
assert_equals "0" "$rc" "env load exits 0"
assert_file_contains "$OUT" "export ANTHROPIC_API_KEY=" "env load emits the same exports"

test_start "env_rejects_an_unknown_subcommand"
rc="$(secrets env dump)"
assert_equals "1" "$rc" "an unknown env subcommand fails"
assert_file_contains "$ERR" "Usage: dot env load" "the usage line is shown"

# ===========================================================================
# Policy defaults
# ===========================================================================
test_start "the_policy_in_the_data_file_supplies_the_provider_default"
# The fixture policy names `pass`; with no explicit environment override the
# command must adopt it.
rc="$(FORCE_PROVIDER="" secrets_fixture secrets provider)"
assert_equals "0" "$rc" "provider exits 0 with the policy applied"
assert_file_contains "$OUT" "pass" "the provider comes from [secrets.policy]"

test_start "an_explicit_provider_overrides_the_policy"
printf '[secrets.policy]\nprovider = "macos-keychain"\nauto_load = false\n' >"$SRC/.chezmoidata.toml"
secrets_fixture secrets provider >/dev/null
assert_file_contains "$OUT" "pass" "the environment wins over the policy"

test_start "a_missing_data_file_leaves_the_provider_to_the_environment"
rm -f "$SRC/.chezmoidata.toml"
rc="$(secrets_fixture secrets provider)"
assert_equals "0" "$rc" "a source tree with no data file still works"
assert_file_contains "$OUT" "pass" "the provider falls back to the environment"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
