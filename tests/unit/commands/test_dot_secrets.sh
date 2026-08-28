#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Comprehensive smoke tests for the dot secrets subsystem — parallel
# treatment to what dot theme received. Covers:
#   * All top-level secrets-related commands: secrets, secrets-init,
#     secrets-create, ssh-key, ssh-cert, env
#   * All secrets subcommands: edit, set, get, list, load, provider
#   * Dispatch → cmd_ wiring for each
#   * Target scripts under scripts/secrets/ exist
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SECRETS_SH="$REPO_ROOT/scripts/dot/commands/secrets.sh"

_ok()   { ((TESTS_PASSED++)) || true; printf '  \033[0;32m✓\033[0m %s\n' "$CURRENT_TEST"; }
_fail() { ((TESTS_FAILED++)) || true; printf '  \033[0;31m✗\033[0m %s: %s\n' "$CURRENT_TEST" "${1:-}"; }

# ---------------------------------------------------------------------------
# 1. Top-level dispatch cases exist for every secrets-family command
# ---------------------------------------------------------------------------
for cmd in secrets-init secrets secrets-create ssh-key ssh-cert env; do
  test_start "secrets_toplevel_case_${cmd}"
  grep -qE "^  ${cmd}\)" "$SECRETS_SH" && _ok || _fail
done

# ---------------------------------------------------------------------------
# 2. cmd_<name>() function defined for every dispatch case
# ---------------------------------------------------------------------------
declare -A CMD_MAP=(
  [secrets-init]=cmd_secrets_init
  [secrets-create]=cmd_secrets_create
  [ssh-key]=cmd_ssh_key
  [ssh-cert]=cmd_ssh_cert
  [env]=cmd_env_load
)
for cmd in "${!CMD_MAP[@]}"; do
  fn="${CMD_MAP[$cmd]}"
  test_start "secrets_function_${fn}_defined"
  grep -qE "^${fn}\(\)" "$SECRETS_SH" && _ok || _fail
done

# ---------------------------------------------------------------------------
# 3. Secrets sub-subcommands (dot secrets <sub>): edit, set, get, list,
#    load, provider, create
# ---------------------------------------------------------------------------
for sub in edit set get list load provider; do
  test_start "secrets_subcommand_cmd_secrets_${sub}"
  grep -qE "^cmd_secrets_${sub}\(\)" "$SECRETS_SH" && _ok || _fail
done

# ---------------------------------------------------------------------------
# 4. Target scripts referenced by run_script / exec must exist
# ---------------------------------------------------------------------------
declare -A TARGETS=(
  [age_init]="scripts/secrets/age-init.sh"
  [create]="scripts/secrets/create-secrets-file.sh"
  [encrypt_ssh_key]="scripts/secrets/encrypt-ssh-key.sh"
)
for label in "${!TARGETS[@]}"; do
  rel="${TARGETS[$label]}"
  test_start "secrets_target_script_${label}"
  if [[ -f "$REPO_ROOT/$rel" ]]; then _ok; else _fail "missing $rel"; fi
done

# ---------------------------------------------------------------------------
# 5. Every command reachable via `bash secrets.sh <cmd>` without hitting
#    the Unknown fall-through (dispatch smoke)
# ---------------------------------------------------------------------------
for cmd in secrets-init secrets secrets-create ssh-key ssh-cert env; do
  test_start "secrets_dispatch_reaches_${cmd}_wrapper"
  # We can't run the target script (would touch age keys, real SSH keys,
  # or secret stores). --help is a safe no-op probe on most subcommands;
  # if the module ignores it and calls run_script, the target will fail
  # non-fatally and print a script-specific message — that's still not
  # the module's Unknown-command line.
  out="$(bash "$SECRETS_SH" "$cmd" --help 2>&1 || true)"
  if [[ "$out" != *"Unknown"* ]]; then
    _ok
  else
    _fail "dispatch missed the wrapper for '$cmd'"
  fi
done

# ---------------------------------------------------------------------------
# 6. Secrets input validation — set + get require a KEY argument
# ---------------------------------------------------------------------------
test_start "secrets_set_requires_key"
awk '/^cmd_secrets_set\(\)/{f=1;next} f && /^}/{exit} f' "$SECRETS_SH" \
  | grep -q "Usage.*set.*KEY"
[[ $? -eq 0 ]] && _ok || _fail "set does not enforce KEY arg"

test_start "secrets_get_requires_key"
awk '/^cmd_secrets_get\(\)/{f=1;next} f && /^}/{exit} f' "$SECRETS_SH" \
  | grep -q "Usage.*get.*KEY"
[[ $? -eq 0 ]] && _ok || _fail "get does not enforce KEY arg"

# ---------------------------------------------------------------------------
# 7. secrets-init has a "no age key" recovery path documented for edit
# ---------------------------------------------------------------------------
test_start "secrets_edit_hints_at_secrets_init_when_no_key"
awk '/^cmd_secrets_edit\(\)/{f=1;next} f && /^}/{exit} f' "$SECRETS_SH" \
  | grep -q "secrets-init"
[[ $? -eq 0 ]] && _ok || _fail "no 'run secrets-init' hint in edit"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
printf '  Tests: %d  \033[0;32mPassed: %d\033[0m  \033[0;31mFailed: %d\033[0m\n' \
  "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
