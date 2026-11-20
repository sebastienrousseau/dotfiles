#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
#
# .github/workflows/pr-signature.yml checks the PR body as it is now, not
# the body in the event payload. A rerun replays the original payload, so
# a check that read it kept failing after the signature was added (#1442).
# The step's own script runs here against a stub gh.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

WORKFLOW="$REPO_ROOT/.github/workflows/pr-signature.yml"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

SIG1="THE ARCHITECT ᛫ Sebastien Rousseau ᛫ https://sebastienrousseau.com"
SIG2="THE ENGINE ᛞ EUXIS ᛫ Enterprise Unified Execution Intelligence System ᛫ https://github.com/sebastienrousseau/euxis"

# The `run: |` block of the signature step, dedented.
awk '
  /name: Check PR body for required signature/ { in_step = 1; next }
  in_step && /^ *run: \|/ { match($0, /^ */); ind = RLENGTH + 2; in_run = 1; next }
  in_run && /^ *[^ ]/ { match($0, /^ */); if (RLENGTH < ind) exit }
  in_run { print substr($0, ind + 1) }
' "$WORKFLOW" >"$WORK/step.sh"

# Stub gh: prints $LIVE_BODY for the pulls endpoint and logs its arguments.
mkdir -p "$WORK/bin"
cat >"$WORK/bin/gh" <<'EOF'
#!/usr/bin/env bash
echo "$*" >>"$GH_LOG"
printf '%s' "$LIVE_BODY"
EOF
chmod +x "$WORK/bin/gh"

# run_step EVENT_BODY LIVE_BODY: set RC and OUT.
run_step() {
  RC=0
  : >"$WORK/gh.log"
  OUT="$(PATH="$WORK/bin:$PATH" GH_LOG="$WORK/gh.log" PR_BODY="$1" \
    LIVE_BODY="$2" GH_TOKEN=x GH_REPO=o/r PR_NUMBER=7 \
    bash -e "$WORK/step.sh" 2>&1)" || RC=$?
}

test_start "signature_step_was_extracted"
assert_file_contains "$WORK/step.sh" "SIGNATURE_LINE_1" "the step script is found"

test_start "rerun_after_signing_passes"
run_step "unsigned body" "$(printf 'body\n\n%s\n%s\n' "$SIG1" "$SIG2")"
assert_equals "0" "$RC" "the live, signed body passes even though the payload is unsigned"
assert_contains "repos/o/r/pulls/7" "$(cat "$WORK/gh.log")" "the body comes from the pulls API"

test_start "unsigned_live_body_fails"
run_step "$(printf 'body\n%s\n%s\n' "$SIG1" "$SIG2")" "unsigned body"
assert_equals "1" "$RC" "a signed payload does not excuse an unsigned live body"
assert_contains "must end with the required Euxis signature" "$OUT" "explains the failure"

test_start "harden_runner_allows_the_api"
assert_file_contains "$WORKFLOW" "api.github.com:443" "the blocked egress policy lets gh reach the API"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
