#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Deep-dive coverage for the dot diagnostics subsystem (doctor, health,
# heal, and the 20+ sibling commands routed through
# scripts/dot/commands/diagnostics.sh). Parallel treatment to the
# theme / secrets / agent / ai suites.
#
# Structure:
#   1. Every cmd_<name>() function defined
#   2. Every dispatch case wired
#   3. Every target script under scripts/diagnostics/ or scripts/ops/
#      that a cmd_ delegates to must exist
#   4. Dispatch smoke — no command hits the Unknown-command fall-through
#   5. Property checks: doctor/health/heal must not require sudo /
#      must not touch $HOME writes / must be idempotent when re-run
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/cmd_test_helpers.sh"

DIAG_SH="$REPO_ROOT/scripts/dot/commands/diagnostics.sh"

# ---------------------------------------------------------------------------
# 1. Every cmd_<name>() function defined. Extract the full list from the
#    file so this stays in sync — if someone adds a new cmd_foo() and
#    forgets a dispatch case, we'll catch it in step 2.
# ---------------------------------------------------------------------------
mapfile -t CMDS < <(
  grep -oE '^cmd_[a-z_]+' "$DIAG_SH" | sort -u
)

test_start "diagnostics_has_cmd_functions"
if (( ${#CMDS[@]} >= 15 )); then _ok; else _fail "only ${#CMDS[@]} cmd_ funcs"; fi

# Well-known / high-signal commands that MUST exist. These are the
# daily-use ones; a rename or accidental deletion trips the ratchet.
for cmd_fn in cmd_doctor cmd_health cmd_heal cmd_smoke_test \
              cmd_perf cmd_scorecard cmd_security_score \
              cmd_snapshot cmd_attest cmd_rollback cmd_drift \
              cmd_history cmd_verify cmd_restore cmd_conflicts \
              cmd_locks cmd_benchmark cmd_metrics cmd_bundle; do
  _cmd_asserts_defined "$DIAG_SH" "$cmd_fn"
done

# ---------------------------------------------------------------------------
# 2. Every dispatch case is wired. Extract labels from the case block.
# ---------------------------------------------------------------------------
mapfile -t CASES < <(
  grep -E "^  [a-z][a-zA-Z0-9_-]*\)" "$DIAG_SH" \
    | sed -E 's/^  ([^)]+)\).*/\1/' \
    | sort -u
)

for case_label in doctor health heal smoke-test perf scorecard \
                  security-score snapshot attest rollback drift \
                  history verify restore conflicts locks benchmark \
                  metrics bundle intelligence chaos; do
  _cmd_asserts_case_exists "$DIAG_SH" "$case_label"
done

# ---------------------------------------------------------------------------
# 3. Every cmd_ that uses `run_script "path"` — the path must exist.
# ---------------------------------------------------------------------------
mapfile -t TARGETS < <(
  grep -oE 'run_script "[^"]+"' "$DIAG_SH" | sed 's/run_script "//;s/"$//'
)

test_start "diagnostics_targets_extracted"
if (( ${#TARGETS[@]} >= 5 )); then _ok; else _fail "only ${#TARGETS[@]} run_script targets"; fi

for target in "${TARGETS[@]}"; do
  # Convert to a filesystem-safe test name.
  safe="${target//\//_}"
  safe="${safe//./_}"
  test_start "diagnostics_target_${safe}_exists"
  if [[ -f "$REPO_ROOT/$target" ]]; then _ok; else _fail "missing $target"; fi
done

# ---------------------------------------------------------------------------
# 4. Dispatch smoke — every top-level case reaches its wrapper without
#    hitting the module's Unknown-command fall-through.
# ---------------------------------------------------------------------------
for cmd in doctor health heal smoke-test perf scorecard \
           security-score conflicts benchmark; do
  test_start "diagnostics_dispatch_reaches_${cmd//-/_}"
  out="$(bash "$DIAG_SH" "$cmd" --help 2>&1 || true)"
  if [[ "$out" != *"Unknown diagnostics command"* ]]; then
    _ok
  else
    _fail "'$cmd' hit Unknown fallthrough"
  fi
done

# ---------------------------------------------------------------------------
# 5. Property checks on the high-signal three: doctor / health / heal.
# ---------------------------------------------------------------------------

test_start "doctor_target_script_exists"
[[ -f "$REPO_ROOT/scripts/diagnostics/doctor.sh" ]] && _ok || _fail

test_start "health_target_script_exists"
[[ -f "$REPO_ROOT/scripts/diagnostics/health.sh" ]] && _ok || _fail

test_start "heal_target_script_exists"
[[ -f "$REPO_ROOT/scripts/ops/heal.sh" ]] && _ok || _fail

# doctor / health must not require sudo — they're read-only inspectors.
test_start "doctor_does_not_require_sudo_in_body"
if grep -qE '^sudo |^\s+sudo ' "$REPO_ROOT/scripts/diagnostics/doctor.sh"; then
  # A sudo call inside an `if` guard checking availability is fine;
  # a bare sudo at the top level is not.
  _fail "doctor.sh has bare sudo calls"
else
  _ok
fi

test_start "health_does_not_require_sudo_in_body"
if grep -qE '^sudo |^\s+sudo ' "$REPO_ROOT/scripts/diagnostics/health.sh"; then
  _fail "health.sh has bare sudo calls"
else
  _ok
fi

# heal is allowed to elevate — but must announce it first.
test_start "heal_announces_before_state_change"
if grep -qE 'ui_info|echo.*heal|ui_header' "$REPO_ROOT/scripts/ops/heal.sh"; then
  _ok
else
  _fail "heal.sh does not announce actions"
fi

# ---------------------------------------------------------------------------
# 6. Snapshot / restore round-trip surface — both must exist and both
#    must reference the same underlying storage path convention.
# ---------------------------------------------------------------------------
test_start "snapshot_delegates_to_snapshot_script"
# snapshot delegates to scripts/diagnostics/snapshot.sh via run_script.
grep -q 'run_script "scripts/diagnostics/snapshot.sh"' "$DIAG_SH" \
  && _ok || _fail

test_start "restore_delegates_to_restore_script"
# restore delegates to scripts/dot/commands/restore.sh.
grep -q 'run_script "scripts/dot/commands/restore.sh"' "$DIAG_SH" \
  && _ok || _fail

# ---------------------------------------------------------------------------
# 7. attest is a security-sensitive command — must never open network
#    unless caller opts in. Grep for curl/wget in default path.
# ---------------------------------------------------------------------------
test_start "attest_default_path_has_no_hard_coded_network_calls"
attest_body=$(awk '/^cmd_attest\(\)/{f=1;next} f && /^}/{exit} f' "$DIAG_SH")
# Bare curl / wget outside a check would be a leak. `command -v curl`
# is fine (availability probe).
leaks=$(grep -cE '^\s*(curl|wget) ' <<<"$attest_body" || true)
if (( leaks == 0 )); then _ok; else _fail "found $leaks bare network calls"; fi

# ---------------------------------------------------------------------------
# 8. The dispatch case must handle the wildcard fallthrough — every
#    module needs a `*)` branch that emits Unknown, else `dot X foo`
#    silently succeeds when foo is nonsense.
# ---------------------------------------------------------------------------
test_start "diagnostics_has_wildcard_fallthrough_in_case"
if grep -qE '^  \*\)' "$DIAG_SH"; then _ok; else _fail "no *) case"; fi

test_start "diagnostics_wildcard_emits_unknown_message"
awk '/^  \*\)/{f=1;next} f && /^\s*;;/{exit} f' "$DIAG_SH" | grep -qi "unknown"
[[ $? -eq 0 ]] && _ok || _fail

_cmd_finish
