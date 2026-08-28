#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Batched smoke tests for the remaining shallow commands:
#   load-bench       — delegates to bin/dot-load-benchmark
#   load-bench-pty   — delegates to bin/dot-load-benchmark-pty
#   secrets-init     — exec bash scripts/secrets/age-init.sh
#   secrets-create   — run_script scripts/secrets/create-secrets-file.sh
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/cmd_test_helpers.sh"

DIAG_SH="$REPO_ROOT/scripts/dot/commands/diagnostics.sh"
SECRETS_SH="$REPO_ROOT/scripts/dot/commands/secrets.sh"


# ---------------------------------------------------------------------------
# load-bench + load-bench-pty — both delegate to bin/ executables
# ---------------------------------------------------------------------------

test_start "load_bench_dispatch_case_exists"
grep -qE "^  load-bench\)" "$DIAG_SH" && _ok || _fail

test_start "load_bench_pty_dispatch_case_exists"
grep -qE "^  load-bench-pty\)" "$DIAG_SH" && _ok || _fail

test_start "cmd_load_bench_defined"
grep -qE "^cmd_load_bench\(\)" "$DIAG_SH" && _ok || _fail

test_start "cmd_load_bench_pty_defined"
grep -qE "^cmd_load_bench_pty\(\)" "$DIAG_SH" && _ok || _fail

test_start "cmd_load_bench_delegates_to_dot_load_benchmark"
awk '/^cmd_load_bench\(\)/{f=1;next} f && /^}/{exit} f' "$DIAG_SH" | grep -q "dot-load-benchmark" \
  && _ok || _fail

test_start "cmd_load_bench_pty_delegates_to_dot_load_benchmark_pty"
awk '/^cmd_load_bench_pty\(\)/{f=1;next} f && /^}/{exit} f' "$DIAG_SH" | grep -q "dot-load-benchmark-pty" \
  && _ok || _fail

test_start "load_benchmark_pty_binary_exists"
# Underlying binary should be shipped in bin/.
[[ -f "$REPO_ROOT/bin/dot-load-benchmark-pty" ]] && _ok || _fail "missing bin/dot-load-benchmark-pty"

# ---------------------------------------------------------------------------
# secrets-init + secrets-create + ssh-key + ssh-cert — module surface
# ---------------------------------------------------------------------------

test_start "secrets_init_dispatch_case_exists"
grep -qE "^  secrets-init\)" "$SECRETS_SH" && _ok || _fail

test_start "secrets_create_dispatch_case_exists"
grep -qE "^  secrets-create\)" "$SECRETS_SH" && _ok || _fail

test_start "cmd_secrets_init_defined"
grep -qE "^cmd_secrets_init\(\)" "$SECRETS_SH" && _ok || _fail

test_start "cmd_secrets_create_defined"
grep -qE "^cmd_secrets_create\(\)" "$SECRETS_SH" && _ok || _fail

test_start "cmd_secrets_init_execs_age_init"
awk '/^cmd_secrets_init\(\)/{f=1;next} f && /^}/{exit} f' "$SECRETS_SH" | grep -q "age-init.sh" \
  && _ok || _fail

test_start "cmd_secrets_create_delegates_to_run_script"
awk '/^cmd_secrets_create\(\)/{f=1;next} f && /^}/{exit} f' "$SECRETS_SH" | grep -q "run_script" \
  && _ok || _fail

test_start "secrets_age_init_target_script_exists"
[[ -f "$REPO_ROOT/scripts/secrets/age-init.sh" ]] && _ok || _fail

test_start "secrets_create_target_script_exists"
[[ -f "$REPO_ROOT/scripts/secrets/create-secrets-file.sh" ]] && _ok || _fail

# ---------------------------------------------------------------------------
# Dispatch smoke — module doesn't hit its Unknown fall-through for
# any of the four commands.
# ---------------------------------------------------------------------------
for cmd in load-bench load-bench-pty; do
  test_start "diag_dispatch_reaches_${cmd}_wrapper"
  out="$(bash "$DIAG_SH" "$cmd" --help 2>&1 || true)"
  if [[ "$out" != *"Unknown diagnostics command"* ]]; then
    _ok
  else
    _fail
  fi
done

for cmd in secrets-init secrets-create; do
  test_start "secrets_dispatch_reaches_${cmd}_wrapper"
  # We deliberately don't run the target script (would touch age keys).
  # A --dry-run / invalid-flag probe reaches the wrapper without side
  # effects, and the module's own fall-through prints "Unknown".
  out="$(bash "$SECRETS_SH" "$cmd" --help 2>&1 || true)"
  if [[ "$out" != *"Unknown"* ]] || [[ "$out" == *"age-init"* ]] \
     || [[ "$out" == *"create-secrets"* ]]; then
    _ok
  else
    _fail "dispatch missed the wrapper"
  fi
done

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
_cmd_finish
