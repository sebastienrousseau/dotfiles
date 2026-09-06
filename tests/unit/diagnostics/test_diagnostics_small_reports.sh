#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for the small diagnostic reports:
#
#   scripts/diagnostics/conflicts.sh      alias/command conflict report
#   scripts/diagnostics/snapshot.sh       system + tooling snapshot
#   scripts/diagnostics/verify_state.sh   final environment verification
#   scripts/diagnostics/smoke-test.sh     post-install toolchain smoke test
#
# Each runs against a synthetic source tree or a controlled PATH inside the
# sandbox, so no host state is read or written.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

CONFLICTS="$REPO_ROOT/scripts/diagnostics/conflicts.sh"
SNAPSHOT="$REPO_ROOT/scripts/diagnostics/snapshot.sh"
VERIFY="$REPO_ROOT/scripts/diagnostics/verify_state.sh"
SMOKE="$REPO_ROOT/scripts/diagnostics/smoke-test.sh"
REAL_BASH="${BASH:-$(command -v bash)}"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
BIN="$DOTFILES_COV_TMPDIR/bin"
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

test_start "diagnostic_scripts_exist"
for f in "$CONFLICTS" "$SNAPSHOT" "$VERIFY" "$SMOKE"; do
  assert_file_exists "$f" "$(basename "$f") must exist"
done

_pass() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
}
_fail() {
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $1"
}

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
# run <script> <args…> — stdout captured, stderr replayed so the coverage
# runner keeps its xtrace records. Echoes the exit status.
run() {
  local script="$1" rc=0
  shift
  local home="${SANDBOX_HOME:-$HOME}"
  PATH="${SCRIPT_PATH:-$BIN:/usr/bin:/bin}" HOME="$home" \
    XDG_STATE_HOME="$home/.local/state" \
    XDG_CONFIG_HOME="$home/.config" \
    XDG_DATA_HOME="$home/.local/share" \
    "$REAL_BASH" "$script" "$@" </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}

# ===========================================================================
# conflicts.sh — needs a chezmoi source tree with an executable alias
# manifest; the report is built from that manifest's TSV output.
# ===========================================================================
CONF_HOME="$WORK/conflicts-home"
mkdir -p "$CONF_HOME/.dotfiles/scripts/diagnostics"
MANIFEST="$CONF_HOME/.dotfiles/scripts/diagnostics/aliases-manifest.sh"

write_manifest() {
  cat >"$MANIFEST" <<EOF
#!$REAL_BASH
printf '%s\n' "$1"
EOF
  chmod +x "$MANIFEST"
}

test_start "conflicts_reports_a_clean_alias_set"
# One alias that shadows nothing (no such command) and no duplicates.
write_manifest "$(printf 'zzzznotacommand\tls -la\taliases.sh\t12')"
rc="$(SANDBOX_HOME="$CONF_HOME" run "$CONFLICTS")"
assert_equals "0" "$rc" "a clean alias set exits 0"
assert_file_contains "$OUT" "No duplicate alias names" "no duplicates are reported"
assert_file_contains "$OUT" "No alias shadows detected" "no shadowing is reported"
assert_file_contains "$OUT" "dot aliases list" "the quick actions are printed"

test_start "conflicts_reports_duplicates_and_shadowing"
write_manifest "$(printf 'dup\tls -la\taliases.sh\t12\ndup\tls -l\tother.sh\t34\nbash\techo hi\taliases.sh\t56')"
rc="$(SANDBOX_HOME="$CONF_HOME" run "$CONFLICTS")"
assert_equals "0" "$rc" "a conflicted alias set still exits 0"
assert_file_contains "$OUT" "defined multiple times" "the duplicate is reported"
assert_file_contains "$OUT" "aliases.sh:12" "each definition site is listed"
assert_file_contains "$OUT" "bash -> echo hi" "an alias shadowing a real command is reported"

test_start "conflicts_requires_an_executable_manifest"
chmod -x "$MANIFEST"
rc="$(SANDBOX_HOME="$CONF_HOME" run "$CONFLICTS")"
assert_equals "1" "$rc" "a non-executable manifest is fatal"
assert_file_contains "$OUT" "Alias manifest" "the error names the manifest"
chmod +x "$MANIFEST"

test_start "conflicts_resolves_the_source_from_the_environment"
ENVSRC="$WORK/conflicts-envsrc"
mkdir -p "$ENVSRC/scripts/diagnostics"
cp "$MANIFEST" "$ENVSRC/scripts/diagnostics/aliases-manifest.sh"
chmod +x "$ENVSRC/scripts/diagnostics/aliases-manifest.sh"
rc=0
PATH="$BIN:/usr/bin:/bin" HOME="$WORK/empty-home" CHEZMOI_SOURCE_DIR="$ENVSRC" \
  "$REAL_BASH" "$CONFLICTS" >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "0" "$rc" "CHEZMOI_SOURCE_DIR is honoured"
assert_file_contains "$OUT" "Alias & Command Conflicts" "the report is produced"

test_start "conflicts_resolves_the_legacy_source_location"
LEGACY="$WORK/conflicts-legacy"
mkdir -p "$LEGACY/.local/share/chezmoi/scripts/diagnostics"
cp "$MANIFEST" "$LEGACY/.local/share/chezmoi/scripts/diagnostics/aliases-manifest.sh"
chmod +x "$LEGACY/.local/share/chezmoi/scripts/diagnostics/aliases-manifest.sh"
rc=0
PATH="$BIN:/usr/bin:/bin" HOME="$LEGACY" CHEZMOI_SOURCE_DIR="" \
  "$REAL_BASH" "$CONFLICTS" >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "0" "$rc" "the legacy chezmoi location is the last resort"
assert_file_contains "$OUT" "Alias & Command Conflicts" "the report is produced"

# ===========================================================================
# snapshot.sh
# ===========================================================================
test_start "snapshot_writes_a_timestamped_json_document"
SNAP_HOME="$WORK/snapshot-home"
mkdir -p "$SNAP_HOME"
rc="$(SANDBOX_HOME="$SNAP_HOME" run "$SNAPSHOT")"
assert_equals "0" "$rc" "snapshot exits 0"
assert_file_contains "$OUT" "Snapshot" "the destination is reported"
snap="$(find "$SNAP_HOME/.local/state/dotfiles/snapshots" -name 'snapshot_*.json' | head -1)"
assert_not_empty "$snap" "a timestamped snapshot file is written"
assert_file_contains "$snap" '"tools"' "the tool inventory is included"
if command -v python3 >/dev/null 2>&1; then
  if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$snap"; then _pass; else _fail "the snapshot is not valid JSON"; fi
else
  _pass
fi

test_start "snapshot_baseline_is_written_once_and_needs_force_to_replace"
rc="$(SANDBOX_HOME="$SNAP_HOME" run "$SNAPSHOT" --baseline)"
assert_equals "0" "$rc" "the baseline is written"
assert_file_exists "$SNAP_HOME/.local/state/dotfiles/snapshots/baseline.json" "baseline.json is created"
rc="$(SANDBOX_HOME="$SNAP_HOME" run "$SNAPSHOT" -b)"
assert_equals "0" "$rc" "a repeat run exits 0"
assert_file_contains "$OUT" "already exists (use --force)" "an existing baseline is protected"
rc="$(SANDBOX_HOME="$SNAP_HOME" run "$SNAPSHOT" --baseline --force)"
assert_equals "0" "$rc" "--force overwrites"
assert_file_contains "$OUT" "Snapshot" "the overwrite is reported"

test_start "snapshot_ignores_unknown_arguments"
rc="$(SANDBOX_HOME="$SNAP_HOME" run "$SNAPSHOT" --definitely-not-a-flag)"
assert_equals "0" "$rc" "an unknown flag is skipped rather than fatal"

# ===========================================================================
# verify_state.sh — run from a synthetic checkout so the paths it checks
# resolve inside the sandbox.
# ===========================================================================
test_start "verify_state_fails_when_the_expected_files_are_missing"
VS="$WORK/verify-empty"
mkdir -p "$VS"
rc=0
(cd "$VS" && PATH="$BIN:/usr/bin:/bin" HOME="$VS" "$REAL_BASH" "$VERIFY") >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "1" "$rc" "a bare tree fails verification"
assert_file_contains "$OUT" "Missing file" "each missing file is named"
assert_file_contains "$OUT" "Verification Failed" "the summary reports failure"

test_start "verify_state_passes_on_a_complete_tree"
VS2="$WORK/verify-full"
mkdir -p "$VS2/defaults/.chezmoitemplates/aliases/security" \
  "$VS2/defaults/.chezmoitemplates/aliases/legal" \
  "$VS2/scripts/security" "$VS2/scripts/tools" "$VS2/tests" \
  "$VS2/.github/workflows" "$VS2/home/.config/shell"
: >"$VS2/defaults/.chezmoitemplates/aliases/security/README.md"
: >"$VS2/defaults/.chezmoitemplates/aliases/legal/README.md"
: >"$VS2/scripts/security/lock-configs.sh"
: >"$VS2/scripts/tools/detect-collisions.py"
: >"$VS2/tests/test-aliases.sh"
: >"$VS2/.github/workflows/security-release.yml"
printf 'lock-configs\nunlock-configs\nenable-signing\nscan-licenses\nadd-headers\n' \
  >"$VS2/home/.config/shell/aliases.sh"
rc=0
(cd "$VS2" && PATH="$BIN:/usr/bin:/bin" HOME="$VS2/home" "$REAL_BASH" "$VERIFY") >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "0" "$rc" "a complete tree passes"
assert_file_contains "$OUT" "Verification Passed" "the summary reports success"
assert_file_contains "$OUT" "Verified alias: lock-configs" "each alias is verified"

test_start "verify_state_reports_a_missing_alias_definition"
printf 'lock-configs\n' >"$VS2/home/.config/shell/aliases.sh"
rc=0
(cd "$VS2" && PATH="$BIN:/usr/bin:/bin" HOME="$VS2/home" "$REAL_BASH" "$VERIFY") >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "1" "$rc" "a missing alias fails verification"
assert_file_contains "$OUT" "Missing alias definition" "the missing alias is named"

# ===========================================================================
# smoke-test.sh
# ===========================================================================
test_start "smoke_test_fails_when_the_toolchain_is_absent"
BARE="$WORK/bare-bin"
mkdir -p "$BARE"
for tool in bash sh grep sed awk cat printf locale dirname basename head cut \
  tr sort uniq date mkdir rm; do
  p="$(command -v "$tool" 2>/dev/null || true)"
  [[ -n "$p" ]] && ln -sf "$p" "$BARE/$tool"
done
rc="$(SCRIPT_PATH="$BARE" run "$SMOKE")"
assert_equals "1" "$rc" "a missing toolchain fails"
assert_file_contains "$OUT" "not found" "each missing tool is reported"

test_start "smoke_test_passes_when_every_tool_reports_its_version"
FULL="$WORK/full-bin"
mkdir -p "$FULL"
for f in "$BARE"/*; do ln -sf "$f" "$FULL/$(basename "$f")"; done
mk() {
  cat >"$FULL/$1" <<EOF
#!$REAL_BASH
printf '%s\n' "$2"
exit 0
EOF
  chmod +x "$FULL/$1"
}
mk git "git version 2.42.0"
mk zsh "zsh 5.9"
mk chezmoi "chezmoi version 2.47.1"
mk rg "ripgrep 14.1.0"
mk bat "bat 0.24.0"
mk eza "eza v0.18.0"
mk zoxide "zoxide 0.9.4"
mk zellij "zellij 0.40.1"
mk shfmt "3.8.0"
mk pueue "pueue 3.4.1"
mk sgpt "ShellGPT 1.4.4"
mk copilot "copilot 1.0.0"
mk kiro-cli "kiro-cli 0.2.0"
rc="$(SCRIPT_PATH="$FULL" run "$SMOKE")"
assert_equals "0" "$rc" "a complete toolchain passes"
assert_file_contains "$OUT" "All" "the pass summary is printed"
assert_file_contains "$OUT" "tests passed" "the count is reported"

test_start "smoke_test_flags_a_version_mismatch"
mk git "not-a-version-string"
rc="$(SCRIPT_PATH="$FULL" run "$SMOKE")"
assert_equals "1" "$rc" "an unexpected version string fails"
assert_file_contains "$OUT" "output mismatch" "the mismatch is reported"

test_start "smoke_test_accepts_a_tool_managed_by_mise"
# check_cmd falls back to `mise ls --installed` when the binary is absent.
MISEONLY="$WORK/mise-bin"
mkdir -p "$MISEONLY"
for f in "$BARE"/*; do ln -sf "$f" "$MISEONLY/$(basename "$f")"; done
cat >"$MISEONLY/mise" <<EOF
#!$REAL_BASH
[[ "\${1:-}" == ls ]] && printf 'git 2.42.0\nzsh 5.9\nchezmoi 2.47.1\nrg 14.1.0\nbat 0.24\neza 0.18\nzoxide 0.9\nzellij 0.40\nshfmt 3.8\npueue 3.4\nsgpt 1.4\ncopilot 1.0\nkiro-cli 0.2\n'
exit 0
EOF
chmod +x "$MISEONLY/mise"
rc="$(SCRIPT_PATH="$MISEONLY" run "$SMOKE")"
assert_equals "1" "$rc" "tools known only to mise still fail their version probe"
assert_file_contains "$OUT" "output mismatch" "the version probe is what fails, not the presence check"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
