#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# ssh-cert.sh defaulted the certificate principal to ${USER} under set -u,
# so with USER unset (cron, containers, `env -i`) every command, even
# --help, died with "USER: unbound variable". The default now falls back to
# the account name. Runs the script against a step-ca stub that records the
# principal it is asked to sign.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

CERT_SCRIPT="$REPO_ROOT/scripts/security/ssh-cert.sh"
WORK="$(mktemp -d -t dot-ssh-cert.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin" "$WORK/home/.ssh"
: >"$WORK/home/.ssh/id_ed25519"
cat >"$WORK/bin/step" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"$WORK/step.calls"
EOF
chmod +x "$WORK/bin/step"

# cert <args…> — run ssh-cert.sh with no USER in the environment.
cert() {
  env -i PATH="$WORK/bin:/usr/bin:/bin" HOME="$WORK/home" NO_COLOR=1 \
    SSH_CERT_CA_URL=https://ca.example.invalid \
    bash "$CERT_SCRIPT" "$@" >"$WORK/out" 2>&1
}

test_start "usage_without_USER"
cert --help
assert_equals "0" "$?" "--help runs with USER unset"
assert_file_contains "$WORK/out" "Usage: dot ssh-cert" "and prints the usage"

test_start "issue_defaults_the_principal_to_the_account_name"
: >"$WORK/step.calls"
cert issue
assert_equals "0" "$?" "issue runs with USER unset"
assert_contains "ssh certificate $(id -un) $WORK/home/.ssh/id_ed25519" "$(cat "$WORK/step.calls")" \
  "the principal is the account name"

test_start "an_explicit_principal_wins"
: >"$WORK/step.calls"
cert issue --principal deploy
assert_contains "ssh certificate deploy " "$(cat "$WORK/step.calls")" "--principal is used"

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ $TESTS_FAILED -eq 0 ]]
