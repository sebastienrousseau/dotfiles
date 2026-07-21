#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Execution (deep-branch) tests for version-sync.sh.
#
# Unlike test_version_sync.sh (which only greps the source), this file
# actually RUNS version-sync.sh against a throwaway sandbox project tree,
# exercising arg parsing, get_package_version, validate_version,
# find_version_files, verify_version_consistency (both branches), and the
# chezmoidata sync write path — the paths issue #954 flags as the biggest
# measurable coverage gap.
#
# Writes are confined to the sandbox: version-sync's own coverage guard
# forces --dry-run when DOTFILES_COV_TMPDIR is set, and we opt the sandbox
# back into real writes with DOTFILES_ALLOW_COVERAGE_WRITES=1.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/mocks.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

VERSION_FILE="$REPO_ROOT/scripts/version-sync.sh"

SANDBOX="$(mktemp -d -t vsync-exec.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$SANDBOX"; cov_teardown_sandbox' EXIT

CHEZMOIDATA="$SANDBOX/defaults/.chezmoidata.toml"

# build_sandbox <pkg_version> <readme_version> <chezmoidata_version>
# version-sync.sh sources ../lib/dot/ui.sh, so the real lib is symlinked in.
build_sandbox() {
  local pkg="$1" readme="$2" cmd="$3"
  rm -rf "${SANDBOX:?}/scripts" "${SANDBOX:?}/defaults" "${SANDBOX:?}/lib" \
    "${SANDBOX:?}/README.md" "${SANDBOX:?}/package.json"
  mkdir -p "$SANDBOX/scripts" "$SANDBOX/defaults"
  cp "$VERSION_FILE" "$SANDBOX/scripts/version-sync.sh"
  ln -s "$REPO_ROOT/lib" "$SANDBOX/lib"
  printf '{\n  "version": "%s"\n}\n' "$pkg" >"$SANDBOX/package.json"
  printf 'dotfiles_version = "%s"\n' "$cmd" >"$CHEZMOIDATA"
  printf '# Demo\n\n**Version**: v%s\n' "$readme" >"$SANDBOX/README.md"
}

# Run the sandboxed script; captures VS_OUT / VS_RC. Set ALLOW_W=1 to permit
# real writes inside the sandbox (otherwise the coverage guard forces dry-run).
run_vs() {
  VS_OUT="$(DOTFILES_ALLOW_COVERAGE_WRITES="${ALLOW_W:-0}" \
    bash "$SANDBOX/scripts/version-sync.sh" "$@" 2>&1)"
  VS_RC=$?
  return 0
}

# 1. --help exits 0 and prints the usage banner
build_sandbox "9.9.9" "9.9.9" "9.9.9"
test_start "version_sync_exec_help"
run_vs --help
assert_equals "0" "$VS_RC" "--help exits 0"
assert_contains "USAGE" "$VS_OUT" "--help prints the usage banner"

# 2. Unknown flag is rejected (exit 1)
test_start "version_sync_exec_unknown_flag"
run_vs --definitely-not-a-flag
assert_equals "1" "$VS_RC" "unknown option exits 1"

# 3. Invalid version argument is rejected by validate_version (exit 1)
test_start "version_sync_exec_invalid_version"
run_vs "1.2"
assert_equals "1" "$VS_RC" "malformed semver is rejected"

# 4. --verify detects a markdown mismatch (README v0.0.1 vs package 9.9.9)
build_sandbox "9.9.9" "0.0.1" "9.9.9"
test_start "version_sync_exec_verify_mismatch"
run_vs --verify
assert_equals "1" "$VS_RC" "--verify fails on version mismatch"

# 5. --verify passes when everything already agrees (all 0.0.1)
build_sandbox "0.0.1" "0.0.1" "0.0.1"
test_start "version_sync_exec_verify_consistent"
run_vs --verify
assert_equals "0" "$VS_RC" "--verify passes when versions are consistent"

# 6. --force with sandbox writes enabled rewrites .chezmoidata.toml
build_sandbox "9.9.9" "9.9.9" "0.0.1"
test_start "version_sync_exec_force_rewrites"
ALLOW_W=1 run_vs --force --no-backup
assert_file_contains "$CHEZMOIDATA" 'dotfiles_version = "9.9.9"' \
  "--force syncs dotfiles_version to the package.json version"

# 7. --dry-run makes no changes
build_sandbox "9.9.9" "9.9.9" "0.0.1"
test_start "version_sync_exec_dry_run_no_write"
ALLOW_W=1 run_vs --dry-run
assert_file_contains "$CHEZMOIDATA" 'dotfiles_version = "0.0.1"' \
  "--dry-run leaves files untouched"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
