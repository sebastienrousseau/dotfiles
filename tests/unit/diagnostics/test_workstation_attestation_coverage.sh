#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behavioural coverage for scripts/diagnostics/workstation-attestation.sh:
# the jq guard, explicit --write paths, the fleet-store env fallback, the
# agent-mode state file, the human fleet summary and the --verify hand-off
# (with a stub wasmtime, so no WebAssembly toolchain is needed).
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_REPO="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TEST_SCRIPT="$REAL_REPO/scripts/diagnostics/workstation-attestation.sh"
REAL_BASH="${BASH:-$(command -v bash)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/workstation-attest-cov.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export NO_COLOR=1
export REPO_ROOT="$REAL_REPO"
unset DOTFILES_FLEET_STORE DOTFILES_FLEET_ID AGENT_STATE_FILE
mkdir -p "$HOME" "$WORK/bin" "$WORK/nojq"

cat >"$WORK/bin/wasmtime" <<EOF
#!$REAL_BASH
if [[ "\${1:-}" == "--version" ]]; then
  printf 'wasmtime 99.0.0 (stub)\n'
  exit 0
fi
input="\$(cat)"
printf 'ARGS=%s\n' "\$*"
printf 'HAS_EVIDENCE=%s\n' "\$([[ "\$input" == *'"dotfiles_version"'* ]] && echo yes || echo no)"
exit "\${FAKE_WASM_RC:-0}"
EOF
chmod +x "$WORK/bin/wasmtime"
MODULE="$WORK/dot-sys.wasm"
printf 'wasm' >"$MODULE"

run_wa() {
  "$REAL_BASH" "$TEST_SCRIPT" "$@"
}

if ! command -v jq >/dev/null 2>&1; then
  test_start "wa_requires_jq_for_remaining_cases"
  ((TESTS_PASSED++)) || true
  printf '  %s: skipped (jq unavailable)\n' "$CURRENT_TEST"
  echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
  exit 0
fi

# PATH with everything the prologue needs except jq.
for tool in bash dirname cat sed head tail tr uname awk grep date id tput cut basename readlink; do
  src="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$src" && "$src" == /* ]] && ln -sf "$src" "$WORK/nojq/$tool"
done

test_start "wa_missing_jq_exits_1"
out="$(env PATH="$WORK/nojq" "$REAL_BASH" "$TEST_SCRIPT" --json 2>&1)"
rc=$?
assert_equals "1|yes" "$rc|$([[ "$out" == *"jq is required"* ]] && echo yes)" "jq guard fires"

# Each full run shells out to mcp-doctor, so the remaining cases are packed
# into three invocations to keep the suite fast under coverage tracing.

# Run A: human mode, explicit nested --write, agent-mode state file and the
# DOTFILES_FLEET_STORE / DOTFILES_FLEET_ID environment fallback.
printf 'OTHER=1\nDOT_AGENT_PROFILE=plan\nDOT_AGENT_PROFILE=audit\n' >"$WORK/agent-mode.env"
target="$WORK/out/nested/attest.json"
out_a="$(AGENT_STATE_FILE="$WORK/agent-mode.env" DOTFILES_FLEET_STORE="$WORK/fleet/" DOTFILES_FLEET_ID=envfleet \
  run_wa -w "$target" 2>&1)"
host="$(hostname 2>/dev/null || true)"
host="${host:-unknown-host}"

test_start "wa_write_creates_parent_dir"
assert_equals "yes" "$(jq -e '.dotfiles_version' "$target" >/dev/null 2>&1 && echo yes)" "--write creates parents and writes JSON"

test_start "wa_state_file_last_profile_wins"
assert_equals "audit" "$(jq -r '.agent.current_profile' "$target" 2>/dev/null)" "last DOT_AGENT_PROFILE line is used"

test_start "wa_env_fleet_store_written_and_reported"
assert_equals "yes|yes" "$([[ -f "$WORK/fleet/envfleet/$host/workstation-attestation.json" ]] && echo yes)|$([[ "$out_a" == *"Fleet store"*"$WORK/fleet/envfleet/$host"* ]] && echo yes)" "env fleet store used and shown in the summary"

# Run B: empty state file (falls back to the default profile) and
# --max-age, which implies --verify, in JSON mode.
: >"$WORK/empty-mode.env"
out_b="$(env PATH="$WORK/bin:$PATH" WASMTIME="$WORK/bin/wasmtime" DOT_SYS_WASM="$MODULE" \
  AGENT_STATE_FILE="$WORK/empty-mode.env" \
  "$REAL_BASH" "$TEST_SCRIPT" --json --max-age 600 2>&1)"
rc_b=$?

test_start "wa_verify_json_hands_evidence_to_verifier"
assert_equals "0|yes|yes" "$rc_b|$([[ "$out_b" == *"ARGS=run $MODULE verify --json --max-age 600"* ]] && echo yes)|$([[ "$out_b" == *"HAS_EVIDENCE=yes"* ]] && echo yes)" "--max-age implies --verify and forwards flags"

# Run C: plain --verify (no --json, no --max-age) with a failing verifier;
# unknown flags are ignored.
out_c="$(env PATH="$WORK/bin:$PATH" WASMTIME="$WORK/bin/wasmtime" DOT_SYS_WASM="$MODULE" FAKE_WASM_RC=1 \
  "$REAL_BASH" "$TEST_SCRIPT" -V --unknown-flag-ignored 2>&1)"
rc_c=$?

test_start "wa_verify_human_mode_propagates_failure"
assert_equals "1|yes|yes" "$rc_c|$([[ "$out_c" == *"ARGS=run $MODULE verify"* && "$out_c" != *"--json"* && "$out_c" != *"--max-age"* ]] && echo yes)|$([[ "$out_c" == *"see the failed checks above"* ]] && echo yes)" "plain --verify forwards no extra flags and keeps the failure status"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
