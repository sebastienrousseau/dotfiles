#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural
# shellcheck disable=SC1090,SC1091,SC2034
# The Go fuzz harnesses under fuzz/ port shell and Python input gates. A
# port that drifts from its source fuzzes the wrong thing while staying
# green, so every pattern a harness declares must appear verbatim in the
# source it mirrors.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

# go_const <file> <name> — the raw-string value of a Go const.
go_const() {
  sed -n "s/^[[:space:]]*$2[[:space:]]*=[[:space:]]*\`\\(.*\\)\`\$/\\1/p" "$REPO_ROOT/$1"
}

# lockstep <label> <go-file> <const> <source-file>
lockstep() {
  local label="$1" go_file="$2" name="$3" source="$4" value
  test_start "fuzz_lockstep_$label"
  value="$(go_const "$go_file" "$name")"
  if [[ -z "$value" ]]; then
    assert_exit_code 0 "false  # $go_file declares no $name"
  elif grep -qF -- "$value" "$REPO_ROOT/$source"; then
    assert_exit_code 0 "true"
  else
    assert_exit_code 0 "false  # $name ($value) not found in $source"
  fi
}

lockstep fleet_name fuzz/fleet_inputs_test.go fleetNamePattern scripts/dot/commands/fleet.sh
lockstep fleet_target fuzz/fleet_inputs_test.go fleetTargetPattern scripts/dot/commands/fleet.sh
lockstep fleet_jobs fuzz/fleet_inputs_test.go fleetJobsPattern scripts/dot/commands/fleet.sh
lockstep secret_key fuzz/secret_key_test.go secretKeyPattern scripts/lib/secrets_provider.sh
lockstep secret_env_key fuzz/secret_key_test.go secretEnvKeyPattern scripts/lib/secrets_provider.sh

# The gateway gate is ported from Python rather than a single regex; pin
# the two expressions the port mirrors.
GATEWAY="$REPO_ROOT/defaults/dot_local/bin/executable_dot-ai-serve"
test_start "fuzz_lockstep_gateway_loopback_names"
assert_file_contains "$GATEWAY" 'names = {"127.0.0.1", "localhost", "[::1]"}' \
  "the Host allowlist the harness mirrors"
test_start "fuzz_lockstep_gateway_bearer_prefix"
assert_file_contains "$GATEWAY" 'if auth[:7].lower() == "bearer ":' \
  "the case-insensitive Bearer prefix the harness mirrors"

# Each new harness is wired into CI and both fuzz build scripts.
for harness in FuzzFleetInputs FuzzSecretKey FuzzGatewayGate; do
  for f in .github/workflows/fuzz.yml fuzz/oss-fuzz/build.sh .clusterfuzzlite/build.sh; do
    test_start "fuzz_registered_${harness}_$(basename "$f")"
    assert_file_contains "$REPO_ROOT/$f" "$harness" "$harness is registered in $f"
  done
done

echo ""
echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
