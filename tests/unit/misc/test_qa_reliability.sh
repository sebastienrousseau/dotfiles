#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# (SC2016: the fixture docs hold literal backticks.)
# Behavioural tests for the QA gate scripts under scripts/qa/. Each script
# resolves REPO_ROOT from its own location, so every case copies the script
# into a mktemp fixture tree, stubs its collaborators there, runs it, and
# asserts the exit status and output. Every gate has a fixture that must fail.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

audit_script="$REPO_ROOT/scripts/qa/reliability-audit.sh"
examples_script="$REPO_ROOT/scripts/qa/validate-examples.sh"
docs_coverage_script="$REPO_ROOT/scripts/qa/docs-coverage.sh"
traceability_script="$REPO_ROOT/scripts/qa/traceability-coverage.sh"
platform_example="$REPO_ROOT/examples/example-platform-contract.sh"
wsl_contract_script="$REPO_ROOT/scripts/qa/wsl-contract.sh"
reliability_workflow="$REPO_ROOT/.github/workflows/reliability-gate.yml"

_qa_tmp="$(mktemp -d -t dotfiles-qa-reliability.XXXXXX)"
trap 'rm -rf "$_qa_tmp"' EXIT
export HOME="$_qa_tmp/home"
export XDG_CONFIG_HOME="$HOME/.config" XDG_CACHE_HOME="$HOME/.cache"
export XDG_DATA_HOME="$HOME/.local/share" XDG_STATE_HOME="$HOME/.local/state"
mkdir -p "$HOME"

# Stub bin: `uname` prints $FAKE_UNAME; `grep` reads $FAKE_PROC_VERSION
# wherever the caller asked for /proc/version and is the real grep otherwise.
_qa_bin="$_qa_tmp/bin"
mkdir -p "$_qa_bin"
cat >"$_qa_bin/uname" <<'EOF'
#!/bin/sh
echo "${FAKE_UNAME:?}"
EOF
_qa_real_grep="$(command -v grep)"
cat >"$_qa_bin/grep" <<EOF
#!/usr/bin/env bash
args=()
for a in "\$@"; do
  [[ "\$a" == /proc/version ]] && a="\${FAKE_PROC_VERSION:-/nonexistent}"
  args+=("\$a")
done
exec "$_qa_real_grep" "\${args[@]}"
EOF
chmod +x "$_qa_bin/uname" "$_qa_bin/grep"
printf 'Linux version 5.15.153.1-microsoft-standard-WSL2\n' >"$_qa_tmp/proc-version-wsl"
printf 'Linux version 6.8.0-45-generic (buildd@ubuntu)\n' >"$_qa_tmp/proc-version-linux"

_qa_fixture() { mktemp -d "$_qa_tmp/fx.XXXXXX"; }

_qa_stub() { # path log-tag: executable that logs its tag, fails if FAIL_STEP=tag
  mkdir -p "$(dirname "$1")"
  cat >"$1" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$2" >>"\${LOG_FILE:?}"
[ "\${FAIL_STEP:-}" != "$2" ]
EOF
  chmod +x "$1"
}

# Sets QA_RC, QA_OUT (stdout+stderr) for: _qa_run <script> [args...]
_qa_run() {
  QA_OUT="$(PATH="$_qa_bin:$PATH" bash "$@" 2>&1)"
  QA_RC=$?
}

# ═══════════════════════════════════════════════════════════════
# reliability-audit.sh
# ═══════════════════════════════════════════════════════════════

_qa_audit_repo() {
  local dir
  dir="$(_qa_fixture)"
  mkdir -p "$dir/scripts/qa" "$dir/tests/framework"
  cp "$audit_script" "$dir/scripts/qa/reliability-audit.sh"
  cat >"$dir/tests/framework/test_runner.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'test_runner:%s\n' "$*" >>"${LOG_FILE:?}"
EOF
  cat >"$dir/tests/framework/module_coverage.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'module_coverage:%s\n' "${MIN_COVERAGE:-unset}" >>"${LOG_FILE:?}"
EOF
  chmod +x "$dir/tests/framework/test_runner.sh" "$dir/tests/framework/module_coverage.sh"
  _qa_stub "$dir/scripts/qa/docs-coverage.sh" docs_coverage
  _qa_stub "$dir/scripts/qa/traceability-coverage.sh" traceability_coverage
  _qa_stub "$dir/scripts/qa/validate-examples.sh" validate_examples
  printf '%s\n' "$dir"
}

# Sets QA_RC, QA_OUT, QA_LOG for: _qa_audit <fixture> [args...]
_qa_audit() {
  local dir="$1"
  shift
  : >"$dir/run.log"
  QA_OUT="$(
    unset MIN_COVERAGE
    export LOG_FILE="$dir/run.log" FAKE_UNAME="${FAKE_UNAME:-Linux}"
    PATH="$_qa_bin:$PATH" bash "$dir/scripts/qa/reliability-audit.sh" "$@" 2>&1
  )"
  QA_RC=$?
  QA_LOG="$(<"$dir/run.log")"
}

qa_unit_steps=$'test_runner:--jobs auto\nmodule_coverage:100\ndocs_coverage\ntraceability_coverage\nvalidate_examples'
qa_full_steps="$qa_unit_steps"$'\ntest_runner:--jobs auto --integration-only'

test_start "qa_reliability_audit_exists"
assert_file_exists "$audit_script" "reliability-audit.sh exists"

test_start "qa_reliability_help_documents_flags"
_qa_run "$audit_script" --help
assert_equals "0|yes" "$QA_RC|$([[ "$QA_OUT" == *--quick* && "$QA_OUT" == *--unit-only* && "$QA_OUT" == *--with-integration* ]] && echo yes)" \
  "--help exits 0 and documents --quick, --unit-only, --with-integration"

test_start "qa_reliability_quick_runs_unit_gates_only"
fx="$(_qa_audit_repo)"
_qa_audit "$fx" --quick
assert_equals "0|$qa_unit_steps" "$QA_RC|$QA_LOG" "--quick runs every gate except integration, in order"

test_start "qa_reliability_unit_only_skips_integration"
_qa_audit "$fx" --unit-only
assert_equals "0|$qa_unit_steps" "$QA_RC|$QA_LOG" "--unit-only runs every gate except integration"

test_start "qa_reliability_with_integration_adds_integration"
_qa_audit "$fx" --quick --with-integration
assert_equals "0|$qa_full_steps" "$QA_RC|$QA_LOG" "--with-integration adds the integration suite to quick mode"

test_start "qa_reliability_full_mode_runs_integration"
_qa_audit "$fx"
assert_equals "0|$qa_full_steps" "$QA_RC|$QA_LOG" "full mode (no flags) runs the integration suite"

test_start "qa_reliability_full_mode_reports_success"
assert_contains "Reliability audit passed." "$QA_OUT" "a clean run reports success"

test_start "qa_reliability_min_coverage_forwarded"
: >"$fx/run.log"
QA_LOG="$(
  export LOG_FILE="$fx/run.log" FAKE_UNAME=Linux MIN_COVERAGE=87
  PATH="$_qa_bin:$PATH" bash "$fx/scripts/qa/reliability-audit.sh" --quick >/dev/null 2>&1
  printf '%s' "$(<"$fx/run.log")"
)"
assert_contains "module_coverage:87" "$QA_LOG" "MIN_COVERAGE reaches the module-coverage gate"

test_start "qa_reliability_unknown_option_fails"
_qa_audit "$fx" --bogus
assert_equals "1|yes|" "$QA_RC|$([[ "$QA_OUT" == *"Unknown option: --bogus"* ]] && echo yes)|$QA_LOG" \
  "unknown option exits 1, names the option, runs no gate"

test_start "qa_reliability_failing_gate_stops_audit"
FAIL_STEP=docs_coverage _qa_audit "$fx" --quick
assert_equals "fail|test_runner:--jobs auto"$'\n'"module_coverage:100"$'\n'"docs_coverage|no" \
  "$([[ $QA_RC -ne 0 ]] && echo fail)|$QA_LOG|$([[ "$QA_OUT" == *"audit passed"* ]] && echo yes || echo no)" \
  "a failing gate fails the audit and later gates do not run"

test_start "qa_reliability_syntax_error_fails_audit"
fx_bad="$(_qa_audit_repo)"
printf 'if then fi\n' >"$fx_bad/broken.sh"
_qa_audit "$fx_bad" --quick
assert_equals "fail|yes|" "$([[ $QA_RC -ne 0 ]] && echo fail)|$([[ "$QA_OUT" == *"Syntax failures: 1"* ]] && echo yes)|$QA_LOG" \
  "a shell file with a syntax error fails the audit before any suite runs"

test_start "qa_reliability_platform_macos"
FAKE_UNAME=Darwin _qa_audit "$fx" --quick
assert_contains "Platform: macOS" "$QA_OUT" "Darwin reports macOS"

test_start "qa_reliability_platform_linux"
FAKE_PROC_VERSION="$_qa_tmp/proc-version-linux" FAKE_UNAME=Linux _qa_audit "$fx" --quick
assert_contains "Platform: Linux" "$QA_OUT" "Linux without a Microsoft kernel reports Linux"

test_start "qa_reliability_platform_wsl"
FAKE_PROC_VERSION="$_qa_tmp/proc-version-wsl" FAKE_UNAME=Linux _qa_audit "$fx" --quick
assert_contains "Platform: WSL" "$QA_OUT" "Linux with a Microsoft kernel reports WSL"

# ═══════════════════════════════════════════════════════════════
# validate-examples.sh
# ═══════════════════════════════════════════════════════════════

_qa_examples_repo() {
  local dir
  dir="$(_qa_fixture)"
  mkdir -p "$dir/scripts/qa"
  cp "$examples_script" "$dir/scripts/qa/validate-examples.sh"
  printf '%s\n' "$dir"
}

test_start "qa_validate_examples_exists"
assert_file_exists "$examples_script" "validate-examples.sh exists"

test_start "qa_validate_examples_runs_each_example"
fx="$(_qa_examples_repo)"
mkdir -p "$fx/examples"
printf 'echo ok-a\n' >"$fx/examples/a.sh"
printf 'echo ok-b\n' >"$fx/examples/b.sh"
_qa_run "$fx/scripts/qa/validate-examples.sh"
assert_equals "0"$'\n'"Running example: a.sh"$'\n'"ok-a"$'\n'"Running example: b.sh"$'\n'"ok-b"$'\n'"Examples passed." \
  "$QA_RC"$'\n'"$QA_OUT" "every example runs in order and the gate passes"

test_start "qa_validate_examples_failing_example_fails"
printf 'exit 3\n' >"$fx/examples/c-bad.sh"
_qa_run "$fx/scripts/qa/validate-examples.sh"
assert_equals "1|yes|yes" \
  "$QA_RC|$([[ "$QA_OUT" == *"FAIL: c-bad.sh exited 3"* ]] && echo yes)|$([[ "$QA_OUT" == *"1 example(s) failed."* ]] && echo yes)" \
  "a failing example fails the gate and is named"

test_start "qa_validate_examples_missing_dir_fails"
fx="$(_qa_examples_repo)"
_qa_run "$fx/scripts/qa/validate-examples.sh"
assert_equals "1|yes" "$QA_RC|$([[ "$QA_OUT" == *"No examples directory found"* ]] && echo yes)" \
  "a missing examples/ directory fails the gate"

test_start "qa_validate_examples_empty_dir_fails"
mkdir -p "$fx/examples"
_qa_run "$fx/scripts/qa/validate-examples.sh"
assert_equals "1|yes" "$QA_RC|$([[ "$QA_OUT" == *"No executable examples found"* ]] && echo yes)" \
  "an examples/ directory with no scripts fails the gate"

test_start "qa_validate_examples_help_runs_nothing"
printf 'echo SHOULD-NOT-RUN\n' >"$fx/examples/a.sh"
_qa_run "$fx/scripts/qa/validate-examples.sh" --help
assert_equals "0|no" "$QA_RC|$([[ "$QA_OUT" == *SHOULD-NOT-RUN* ]] && echo yes || echo no)" \
  "--help exits 0 without running examples"

test_start "qa_validate_examples_unknown_option"
_qa_run "$fx/scripts/qa/validate-examples.sh" --bogus
assert_equals "2" "$QA_RC" "an unknown option exits 2"

# ═══════════════════════════════════════════════════════════════
# docs-coverage.sh
# ═══════════════════════════════════════════════════════════════

test_start "qa_docs_coverage_exists"
assert_file_exists "$docs_coverage_script" "docs-coverage.sh exists"

fx_docs="$(_qa_fixture)"
mkdir -p "$fx_docs/scripts/qa" "$fx_docs/bin" "$fx_docs/docs/reference" \
  "$fx_docs/defaults/.chezmoitemplates/functions"
cp "$docs_coverage_script" "$fx_docs/scripts/qa/docs-coverage.sh"
cat >"$fx_docs/bin/dot" <<'DOT'
#!/usr/bin/env bash
_dot_help_specs() {
  cat <<'EOF'
core|alpha|Alpha command
core|beta|Beta command
EOF
}
DOT
printf '{"netgroup": {}}\n' >"$fx_docs/defaults/.chezmoitemplates/functions/groups.json"
: >"$fx_docs/docs/reference/UTILS.md"
: >"$fx_docs/docs/AI.md"
: >"$fx_docs/docs/reference/SCRIPTS.md"
: >"$fx_docs/docs/ARCHITECTURE.md"

test_start "qa_docs_coverage_empty_docs_fail"
_qa_run "$fx_docs/scripts/qa/docs-coverage.sh"
docs_missing="$QA_OUT"
assert_equals "1|yes|yes|yes" \
  "$QA_RC|$([[ "$QA_OUT" == *"Missing documentation: dot alpha in UTILS.md"* ]] && echo yes)|$([[ "$QA_OUT" == *"Missing documentation: function group netgroup in ARCHITECTURE.md"* ]] && echo yes)|$([[ "$QA_OUT" == *"FAIL: docs coverage below"* ]] && echo yes)" \
  "undocumented commands and function groups fail the gate by name"

# Document exactly what the gate reported missing.
while IFS= read -r line; do
  case "$line" in
    "Missing documentation: function group "*" in ARCHITECTURE.md")
      item="${line#Missing documentation: function group }"
      printf -- '- `%s`\n' "${item% in ARCHITECTURE.md}" >>"$fx_docs/docs/ARCHITECTURE.md"
      ;;
    "Missing documentation: "*" in UTILS.md")
      item="${line#Missing documentation: }"
      printf -- '- `%s`\n' "${item% in UTILS.md}" >>"$fx_docs/docs/reference/UTILS.md"
      ;;
    "Missing documentation: "*" in AI.md")
      item="${line#Missing documentation: }"
      printf -- '- `%s`\n' "${item% in AI.md}" >>"$fx_docs/docs/AI.md"
      ;;
    "Missing documentation: "*" in SCRIPTS.md")
      item="${line#Missing documentation: }"
      printf -- '- `%s`\n' "${item% in SCRIPTS.md}" >>"$fx_docs/docs/reference/SCRIPTS.md"
      ;;
  esac
done <<<"$docs_missing"

test_start "qa_docs_coverage_complete_docs_pass"
_qa_run "$fx_docs/scripts/qa/docs-coverage.sh"
assert_equals "0|yes|yes" \
  "$QA_RC|$([[ "$QA_OUT" =~ Docs\ coverage:\ ([0-9]+)/([0-9]+)\ \(100\.00%\) && "${BASH_REMATCH[1]}" == "${BASH_REMATCH[2]}" ]] && echo yes)|$([[ "$QA_OUT" == *PASS:* ]] && echo yes)" \
  "documenting every reported entry reaches 100% and passes"

test_start "qa_docs_coverage_removed_entry_fails"
printf -- '- `dot alpha`\n' >"$fx_docs/docs/reference/UTILS.md"
_qa_run "$fx_docs/scripts/qa/docs-coverage.sh"
assert_equals "1|yes|no" \
  "$QA_RC|$([[ "$QA_OUT" == *"Missing documentation: dot beta in UTILS.md"* ]] && echo yes)|$([[ "$QA_OUT" == *"dot alpha in UTILS.md"* ]] && echo yes || echo no)" \
  "dropping one command's docs fails the gate and names only that command"

test_start "qa_docs_coverage_threshold_honoured"
MIN_DOCS_COVERAGE=50 bash "$fx_docs/scripts/qa/docs-coverage.sh" >/dev/null 2>&1
assert_equals "0" "$?" "coverage above MIN_DOCS_COVERAGE passes"

# ═══════════════════════════════════════════════════════════════
# traceability-coverage.sh
# ═══════════════════════════════════════════════════════════════

test_start "qa_traceability_coverage_exists"
assert_file_exists "$traceability_script" "traceability-coverage.sh exists"

fx_trace="$(_qa_fixture)"
mkdir -p "$fx_trace/scripts/qa" "$fx_trace/scripts/dot/commands" "$fx_trace/tests/unit" \
  "$fx_trace/docs/operations"
cp "$traceability_script" "$fx_trace/scripts/qa/traceability-coverage.sh"
: >"$fx_trace/scripts/dot/commands/alpha.sh"
: >"$fx_trace/tests/unit/test_alpha.sh"
: >"$fx_trace/docs/alpha.md"
cat >"$fx_trace/docs/operations/TRACEABILITY.md" <<'EOF'
# Traceability

| ID | Behavior | Implementation | Tests | Docs |
|---|---|---|---|---|
| BT-001 | alpha | `scripts/dot/commands/alpha.sh` | `tests/unit/test_alpha.sh` | `docs/alpha.md` |
| BT-002 | gate | `scripts/qa/traceability-coverage.sh` | `tests/unit/test_alpha.sh` | `docs/alpha.md` |
EOF

test_start "qa_traceability_complete_matrix_passes"
_qa_run "$fx_trace/scripts/qa/traceability-coverage.sh"
assert_equals "0|yes|yes" \
  "$QA_RC|$([[ "$QA_OUT" == *"Traceability coverage: 8/8 (100.00%)"* ]] && echo yes)|$([[ "$QA_OUT" == *PASS:* ]] && echo yes)" \
  "every row target exists and every command/QA script has a row"

test_start "qa_traceability_missing_target_fails"
rm "$fx_trace/tests/unit/test_alpha.sh"
_qa_run "$fx_trace/scripts/qa/traceability-coverage.sh"
assert_equals "1|yes" \
  "$QA_RC|$([[ "$QA_OUT" == *"Missing traceability target: BT-001 test"* ]] && echo yes)" \
  "a row pointing at a missing test fails the gate and names the row"

test_start "qa_traceability_unmapped_command_fails"
: >"$fx_trace/tests/unit/test_alpha.sh"
: >"$fx_trace/scripts/dot/commands/beta.sh"
_qa_run "$fx_trace/scripts/qa/traceability-coverage.sh"
assert_equals "1|yes" \
  "$QA_RC|$([[ "$QA_OUT" == *"Missing traceability row for implementation: scripts/dot/commands/beta.sh"* ]] && echo yes)" \
  "a dot command with no traceability row fails the gate"

# ═══════════════════════════════════════════════════════════════
# examples/example-platform-contract.sh
# ═══════════════════════════════════════════════════════════════

test_start "qa_examples_include_platform_contract"
assert_file_exists "$platform_example" "platform contract example exists"

test_start "qa_platform_example_macos"
QA_OUT="$(unset _DOT_IS_WSL && FAKE_UNAME=Darwin PATH="$_qa_bin:$PATH" bash "$platform_example" 2>&1)"
assert_equals $'Platform: macos\nHost OS: macos' "$QA_OUT" "Darwin prints the macos platform and host"

test_start "qa_platform_example_linux"
QA_OUT="$(_DOT_IS_WSL=1 FAKE_UNAME=Linux PATH="$_qa_bin:$PATH" bash "$platform_example" 2>&1)"
assert_equals $'Platform: linux\nHost OS: linux' "$QA_OUT" "native Linux prints the linux platform and host"

test_start "qa_platform_example_wsl"
QA_OUT="$(_DOT_IS_WSL=0 FAKE_UNAME=Linux PATH="$_qa_bin:$PATH" bash "$platform_example" 2>&1)"
assert_equals $'Platform: wsl\nHost OS: windows' "$QA_OUT" "WSL prints the wsl platform on a windows host"

# ═══════════════════════════════════════════════════════════════
# wsl-contract.sh
# ═══════════════════════════════════════════════════════════════

test_start "qa_wsl_contract_exists"
assert_file_exists "$wsl_contract_script" "wsl contract script exists"

fx_wsl="$(_qa_fixture)"
mkdir -p "$fx_wsl/scripts/qa"
cp "$wsl_contract_script" "$fx_wsl/scripts/qa/wsl-contract.sh"
_qa_stub "$fx_wsl/tests/unit/install/test_os_detection_comprehensive.sh" os_detection
_qa_stub "$fx_wsl/tests/unit/functions/test_platform_detection_behavior.sh" platform_behavior

test_start "qa_wsl_contract_runs_both_suites"
: >"$fx_wsl/run.log"
LOG_FILE="$fx_wsl/run.log" bash "$fx_wsl/scripts/qa/wsl-contract.sh" >/dev/null 2>&1
QA_RC=$?
assert_equals "0|os_detection"$'\n'"platform_behavior" "$QA_RC|$(<"$fx_wsl/run.log")" \
  "the contract runs OS detection then platform behaviour coverage"

test_start "qa_wsl_contract_fails_when_a_suite_fails"
: >"$fx_wsl/run.log"
FAIL_STEP=os_detection LOG_FILE="$fx_wsl/run.log" bash "$fx_wsl/scripts/qa/wsl-contract.sh" >/dev/null 2>&1
QA_RC=$?
assert_equals "fail|os_detection" "$([[ $QA_RC -ne 0 ]] && echo fail)|$(<"$fx_wsl/run.log")" \
  "a failing suite fails the contract and stops it"

test_start "qa_wsl_contract_os_detection_suite_exists"
assert_file_exists "$REPO_ROOT/tests/unit/install/test_os_detection_comprehensive.sh" \
  "the OS detection suite the contract runs is present"

test_start "qa_wsl_contract_platform_suite_exists"
assert_file_exists "$REPO_ROOT/tests/unit/functions/test_platform_detection_behavior.sh" \
  "the platform behaviour suite the contract runs is present"

test_start "qa_reliability_workflow_contract_jobs"
assert_file_contains "$reliability_workflow" "name: Examples Contract" "reliability workflow includes examples contract"
assert_file_contains "$reliability_workflow" "name: WSL Contract" "reliability workflow includes wsl contract"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
