#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behavioural coverage for scripts/diagnostics/attest-verify.sh. A stub
# `wasmtime` and stub `cargo` stand in for the real toolchain, and REPO_ROOT
# points at a scratch tree so the on-demand build never touches the repo.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_REPO="$(cd "$SCRIPT_DIR/../../.." && pwd)"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TEST_SCRIPT="$REAL_REPO/scripts/diagnostics/attest-verify.sh"
REAL_BASH="${BASH:-$(command -v bash)}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/attest-verify-cov.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

export HOME="$WORK/home"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"
export NO_COLOR=1
mkdir -p "$HOME" "$WORK/bin" "$WORK/nocargo" "$WORK/fake-root"

# Stub runtime: echoes its argv and the evidence it read, exits with
# FAKE_WASM_RC (default 0).
cat >"$WORK/bin/wasmtime" <<EOF
#!$REAL_BASH
if [[ "\${1:-}" == "--version" ]]; then
  printf 'wasmtime 99.0.0 (stub)\n'
  exit 0
fi
input="\$(cat)"
printf 'ARGS=%s\n' "\$*"
printf 'INPUT=%s\n' "\$input"
exit "\${FAKE_WASM_RC:-0}"
EOF
# Stub cargo: records the call and "builds" the module under REPO_ROOT.
cat >"$WORK/bin/cargo" <<EOF
#!$REAL_BASH
printf '%s\n' "\$*" >"$WORK/cargo.log"
exit 0
EOF
chmod +x "$WORK/bin/wasmtime" "$WORK/bin/cargo"

MODULE="$WORK/dot-sys.wasm"
printf 'wasm' >"$MODULE"
EVIDENCE="$WORK/evidence.json"
printf '{"generated_at":"2026-01-01T00:00:00Z"}' >"$EVIDENCE"
BASE_PATH="$WORK/bin:$PATH"

run_av() {
  env PATH="$BASE_PATH" WASMTIME="$WORK/bin/wasmtime" DOT_SYS_WASM="$MODULE" \
    "$REAL_BASH" "$TEST_SCRIPT" "$@"
}

test_start "av_help_prints_usage_and_exits_zero"
out="$(run_av --help 2>&1 </dev/null)"
rc=$?
assert_equals "0|yes" "$rc|$([[ "$out" == *"Usage: dot attest --verify"* ]] && echo yes)" "--help prints usage"

test_start "av_short_help"
out="$(run_av -h 2>&1 </dev/null)"
assert_contains "--max-age SECS" "$out" "-h prints usage"

test_start "av_unknown_option_exits_2"
out="$(run_av --bogus 2>&1 </dev/null)"
rc=$?
assert_equals "2|yes" "$rc|$([[ "$out" == *"unknown option --bogus"* ]] && echo yes)" "unknown option rejected"

test_start "av_missing_evidence_file_exits_2"
out="$(run_av "$WORK/nope.json" 2>&1 </dev/null)"
rc=$?
assert_equals "2|yes" "$rc|$([[ "$out" == *"no such evidence file"* ]] && echo yes)" "missing file rejected"

test_start "av_json_mode_forwards_flags_and_file"
out="$(run_av --verify -j -a 3600 "$EVIDENCE" 2>&1 </dev/null)"
rc=$?
expected="ARGS=run $MODULE verify --json --max-age 3600"
assert_equals "0|yes|yes" "$rc|$([[ "$out" == *"$expected"* ]] && echo yes)|$([[ "$out" == *'INPUT={"generated_at"'* ]] && echo yes)" "json verdict forwarded verbatim"

# Regression: an operand after `--` used to be dropped, so the module was
# fed empty stdin (or fresh evidence on a terminal) instead of FILE.
test_start "av_double_dash_keeps_the_evidence_file"
out="$(run_av --json -- "$EVIDENCE" 2>&1 </dev/null)"
assert_contains 'INPUT={"generated_at"' "$out" "FILE after -- is still read"

test_start "av_bare_double_dash_reads_stdin"
out="$(printf '{"dash":1}' | run_av --json -- 2>&1)"
assert_contains 'INPUT={"dash":1}' "$out" "bare -- falls through to stdin"

test_start "av_json_mode_propagates_failure_status"
out="$(FAKE_WASM_RC=1 run_av --json --max-age any "$EVIDENCE" 2>&1 </dev/null)"
rc=$?
assert_equals "1" "$rc" "json mode exits with the module status"

test_start "av_reads_evidence_from_stdin"
out="$(printf '{"from":"stdin"}' | run_av --json 2>&1)"
assert_contains 'INPUT={"from":"stdin"}' "$out" "stdin evidence is piped to the module"

test_start "av_human_mode_pass"
out="$(run_av "$EVIDENCE" 2>&1 </dev/null)"
rc=$?
assert_equals "0|yes|yes" "$rc|$([[ "$out" == *"every check passed"* ]] && echo yes)|$([[ "$out" == *"wasmtime 99.0.0 (stub)"* ]] && echo yes)" "human verdict reports pass and runtime"

test_start "av_human_mode_fail"
out="$(FAKE_WASM_RC=1 run_av "$EVIDENCE" 2>&1 </dev/null)"
rc=$?
assert_equals "1|yes" "$rc|$([[ "$out" == *"see the failed checks above"* ]] && echo yes)" "human verdict reports failure"

test_start "av_missing_runtime_exits_2"
out="$(env PATH="$BASE_PATH" WASMTIME="$WORK/bin/no-such-runtime" DOT_SYS_WASM="$MODULE" \
  "$REAL_BASH" "$TEST_SCRIPT" --json "$EVIDENCE" 2>&1 </dev/null)"
rc=$?
assert_equals "2|yes" "$rc|$([[ "$out" == *"no WebAssembly runtime found"* ]] && echo yes)" "missing runtime reported"

test_start "av_missing_explicit_module_exits_2"
out="$(env PATH="$BASE_PATH" WASMTIME="$WORK/bin/wasmtime" DOT_SYS_WASM="$WORK/absent.wasm" \
  "$REAL_BASH" "$TEST_SCRIPT" --json "$EVIDENCE" 2>&1 </dev/null)"
rc=$?
assert_equals "2|yes" "$rc|$([[ "$out" == *"DOT_SYS_WASM points at a missing file"* ]] && echo yes)" "missing DOT_SYS_WASM reported"

# PATH for the no-cargo case: symlinks to the handful of tools the script
# needs, so a system-wide cargo cannot leak in.
for tool in bash cat dirname head env; do
  src="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$src" ]] && ln -sf "$src" "$WORK/nocargo/$tool"
done

test_start "av_no_module_and_no_cargo_exits_2"
out="$(env -u DOT_SYS_WASM PATH="$WORK/nocargo" WASMTIME="$WORK/bin/wasmtime" REPO_ROOT="$WORK/fake-root" \
  "$REAL_BASH" "$TEST_SCRIPT" --json "$EVIDENCE" 2>&1 </dev/null)"
rc=$?
assert_equals "2|yes" "$rc|$([[ "$out" == *"no cargo to build one"* ]] && echo yes)" "missing cargo reported with build hint"

test_start "av_builds_module_on_demand_with_cargo"
rm -f "$WORK/cargo.log"
out="$(env -u DOT_SYS_WASM PATH="$BASE_PATH" WASMTIME="$WORK/bin/wasmtime" REPO_ROOT="$WORK/fake-root" \
  "$REAL_BASH" "$TEST_SCRIPT" --json "$EVIDENCE" 2>&1 </dev/null)"
cargo_args="$(cat "$WORK/cargo.log" 2>/dev/null || true)"
assert_equals "yes|yes" "$([[ "$out" == *"building the verifier for wasm32-wasip1"* ]] && echo yes)|$([[ "$cargo_args" == *"--manifest-path $WORK/fake-root/lib/wasm-tools/Cargo.toml --bin dot-sys"* ]] && echo yes)" "cargo invoked against REPO_ROOT crate"

# With neither FILE nor piped stdin the script produces fresh evidence via
# workstation-attestation.sh. Give it a real terminal on stdin through a
# Python pty; skip where python3 is unavailable.
test_start "av_tty_stdin_generates_fresh_evidence"
if command -v python3 >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  out="$(env PATH="$BASE_PATH" WASMTIME="$WORK/bin/wasmtime" DOT_SYS_WASM="$MODULE" REPO_ROOT="$REAL_REPO" \
    python3 -c 'import os, pty, sys
status = pty.spawn(sys.argv[1:])
sys.exit(os.waitstatus_to_exitcode(status) if hasattr(os, "waitstatus_to_exitcode") else status >> 8)' \
    "$REAL_BASH" "$TEST_SCRIPT" --json 2>&1 </dev/null)"
  assert_contains '"dotfiles_version"' "$out" "fresh attestation evidence is fed to the module"
else
  ((TESTS_PASSED++)) || true
  printf '  %s: skipped (python3/jq unavailable)\n' "$CURRENT_TEST"
fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
