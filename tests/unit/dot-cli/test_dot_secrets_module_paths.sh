#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Policy-load and secrets-init paths of scripts/dot/commands/secrets.sh.
#
# Two clusters of the module had never run. The policy loader at the top only
# exports anything when .chezmoidata.toml actually carries a
# [secrets.policy] table, which the checkout's does not in the shape the
# loader reads. And cmd_secrets_init only reaches its own age-key logic when
# scripts/secrets/age-init.sh is absent, which from the checkout it never is.
#
# Both are driven here against a fixture source tree. The PATH deliberately
# excludes `security`, `pass` and `age`, so the provider resolves to "none"
# and nothing in this suite can reach the developer's real keychain.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

cov_setup_sandbox
trap cov_teardown_sandbox EXIT

FX="$(dot_fixture_new secrets-paths)"
mkdir -p "$FX/home" "$FX/stubs"
dot_fixture_basebin "$FX/basebin"
DOT_FIXTURE_HOME="$FX/home"

# The policy table the loader reads. auto_load is deliberately false so the
# "anything but true means off" arm is the one taken.
cat >"$FX/.chezmoidata.toml" <<'TOML'
dotfiles_version = "0.0.1"

[secrets.policy]
provider = "none"
auto_load = false
TOML

secrets_run() {
  DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" dot_fixture_run "$FX" secrets "$@"
}

# ── 1. The policy table reaches the environment ────────────────────────────
test_start "secrets_policy_provider_is_exported"
secrets_run secrets provider
assert_equals "0" "$DOT_FIXTURE_RC" "provider should exit 0"
assert_contains "none" "$DOT_FIXTURE_OUT" \
  "the provider named in [secrets.policy] should win"

# ── 2. secrets-init without the age-init helper ────────────────────────────
test_start "secrets_init_reports_an_existing_key"
mkdir -p "$FX/home/.config/chezmoi"
printf 'AGE-SECRET-KEY-FIXTURE\n' >"$FX/home/.config/chezmoi/key.txt"
secrets_run secrets-init
assert_equals "0" "$DOT_FIXTURE_RC" "an existing key should exit 0"
assert_contains "Age key already exists" "$DOT_FIXTURE_OUT" \
  "the existing key should be reported, not overwritten"

test_start "secrets_init_requires_age_keygen"
rm -f "$FX/home/.config/chezmoi/key.txt"
secrets_run secrets-init
assert_equals "1" "$DOT_FIXTURE_RC" "no age-keygen should exit 1"
assert_contains "age-keygen not found" "$DOT_FIXTURE_OUT" \
  "the failure should name the missing tool"

test_start "secrets_init_creates_a_key"
cat >"$FX/stubs/age-keygen" <<'STUB'
#!/bin/sh
# Minimal age-keygen: `-o FILE` writes a key, `-y FILE` prints its public half.
case "${1:-}" in
  -o) printf 'AGE-SECRET-KEY-GENERATED\n' >"$2" ;;
  -y) printf 'age1fixturepublickey\n' ;;
esac
exit 0
STUB
chmod +x "$FX/stubs/age-keygen"
secrets_run secrets-init
assert_equals "0" "$DOT_FIXTURE_RC" "key creation should exit 0"
assert_file_exists "$FX/home/.config/chezmoi/key.txt" "the key should be written"
assert_contains "age1fixturepublickey" "$DOT_FIXTURE_OUT" \
  "the public half should be printed"
rm -f "$FX/stubs/age-keygen" "$FX/home/.config/chezmoi/key.txt"

# ── 3. secrets set prompts when no value is given on the command line ──────
#
# With the provider resolved to "none" the store itself refuses, which is the
# point: the prompt has to happen first, and the refusal has to be loud.
test_start "secrets_set_prompts_for_a_missing_value"
DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" \
  DOT_FIXTURE_STDIN="hunter2" dot_fixture_run "$FX" secrets secrets set DEMO_KEY
assert_equals "1" "$DOT_FIXTURE_RC" \
  "with no usable provider the store must fail rather than pretend"
# `read -p` only writes its prompt when stdin is a terminal, so the proof
# that the prompt ran is that a non-empty value reached the store — the
# empty-input case below stops earlier, with a different message.
assert_contains "Failed to store key: DEMO_KEY" "$DOT_FIXTURE_OUT" \
  "the prompted value should have been carried into the store"

test_start "secrets_set_refuses_an_empty_prompted_value"
DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" \
  DOT_FIXTURE_STDIN="" dot_fixture_run "$FX" secrets secrets set DEMO_KEY
assert_equals "1" "$DOT_FIXTURE_RC" "an empty prompted value should be refused"
assert_contains "Empty value refused" "$DOT_FIXTURE_OUT" "the refusal should say so"

# ── 4. Delegating subcommands report a missing helper ──────────────────────
test_start "secrets_create_reports_a_missing_helper"
secrets_run secrets-create
assert_equals "1" "$DOT_FIXTURE_RC" "secrets-create without its helper should exit 1"

test_start "secrets_ssh_key_reports_a_missing_helper"
secrets_run ssh-key
assert_equals "1" "$DOT_FIXTURE_RC" "ssh-key without its helper should exit 1"

test_start "secrets_rejects_an_unknown_subcommand"
secrets_run secrets nonsense
assert_equals "1" "$DOT_FIXTURE_RC" "an unknown secrets subcommand should exit 1"

print_summary
