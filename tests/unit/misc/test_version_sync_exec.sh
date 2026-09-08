#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
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

# The portable-fallback cases below need a PATH carrying neither rg nor jq.
#
# `/usr/bin:/bin` is not that PATH: macOS 26 ships /usr/bin/jq, so the jq arms
# stayed selected and the sed/grep fallbacks were never reached. It also swaps
# `bash` for /bin/bash 3.2, which has no BASH_XTRACEFD — its xtrace goes to
# stderr, where run_vs's capture swallows it, and the run contributes no
# coverage at all.
#
# So the portable PATH is built explicitly: the bash this suite is already
# running under, plus symlinks to exactly the tools version-sync shells out
# to. Anything absent from this list is invisible to the script, which is the
# point.
PORTABLE_BIN="$SANDBOX/portable-bin"
mkdir -p "$PORTABLE_BIN"
ln -sf "${BASH:-$(command -v bash)}" "$PORTABLE_BIN/bash"
for _tool in sed grep egrep find sort head tail cut tr wc awk uniq \
  mktemp cp mv rm cat cmp diff basename dirname date chmod mkdir stat \
  tput uname id printf env sh; do
  _resolved="$(command -v "$_tool" 2>/dev/null || true)"
  [[ -n "$_resolved" ]] && ln -sf "$_resolved" "$PORTABLE_BIN/$_tool"
done
unset _tool _resolved
PORTABLE_PATH="$PORTABLE_BIN"
trap 'rm -rf "$SANDBOX"; cov_teardown_sandbox' EXIT

CHEZMOIDATA="$SANDBOX/defaults/.chezmoidata.toml"

# build_sandbox <pkg_version> <readme_version> <chezmoidata_version>
#
# version-sync.sh derives PROJECT_ROOT from its own directory, so the whole
# fake project hangs off $SANDBOX. Two deliberate asymmetries:
#
#   * The script itself is SYMLINKED, not copied. `dirname "${BASH_SOURCE[0]}"`
#     does not follow the link, so PROJECT_ROOT is still the sandbox and every
#     write stays inside it — but the xtrace records now name the real file,
#     so this suite's branch coverage is attributed to scripts/version-sync.sh
#     instead of being thrown away with the copy.
#   * lib/ is a real copy, because lib/dot/bento.sh is one of the script_files
#     version-sync rewrites in place. Symlinking that tree WOULD mutate the
#     checkout; the assertion in case 8 guards the distinction.
build_sandbox() {
  local pkg="$1" readme="$2" cmd="$3"
  rm -rf "${SANDBOX:?}/scripts" "${SANDBOX:?}/defaults" "${SANDBOX:?}/lib" \
    "${SANDBOX:?}/README.md" "${SANDBOX:?}/package.json" "${SANDBOX:?}/docs" \
    "${SANDBOX:?}/.well-known" "${SANDBOX:?}/share"
  mkdir -p "$SANDBOX/scripts" "$SANDBOX/defaults" \
    "$SANDBOX/docs/reference" "$SANDBOX/docs/archive" "$SANDBOX/docs/operations" \
    "$SANDBOX/docs/manual" "$SANDBOX/.well-known/mcp" "$SANDBOX/share/man/man1"
  ln -s "$VERSION_FILE" "$SANDBOX/scripts/version-sync.sh"
  cp -R "$REPO_ROOT/lib" "$SANDBOX/lib"
  printf '{\n  "version": "%s"\n}\n' "$pkg" >"$SANDBOX/package.json"
  printf 'dotfiles_version = "%s"\n' "$cmd" >"$CHEZMOIDATA"
  cat >"$SANDBOX/README.md" <<EOF
# Demo

![Version](https://img.shields.io/badge/Version-v$readme-blue)
[release](https://github.com/example/dotfiles/releases/tag/v$readme)
[site](https://example.invalid/dotfiles/v$readme/)
EOF
  cat >"$SANDBOX/docs/reference/FEATURES.md" <<EOF
# Features

**Dotfiles Version**: $readme
Version: v$readme
Dotfiles Version: v$readme
Version \`v$readme\`
(v$readme)
/v$readme/
dotfiles:$readme
notes — v$readme
MILESTONE v0.0.1 stays historical
EOF
  # The one file version-sync gives its own `case` arm besides README and the
  # audit hook. Its only version stamp is the one that arm rewrites.
  printf '# Intro\n\nThe `.dotfiles` v%s tree.\n' "$readme" \
    >"$SANDBOX/docs/manual/00-introduction.md"
  printf 'Copyright test\n' >"$SANDBOX/docs/COPYRIGHT"
  printf '# Milestone\n\nVersion: v0.0.1\n' >"$SANDBOX/docs/archive/MILESTONE_v0.0.1.md"
  printf '# Excluded\n\nVersion: v0.0.1\n' >"$SANDBOX/docs/operations/VERSION_SYNC.md"
  # Machine-readable discovery cards: JSON, so they are reached by the
  # card_files loop rather than by the markdown scan.
  printf '{\n  "name": "dot",\n  "version": "%s"\n}\n' "$cmd" \
    >"$SANDBOX/.well-known/mcp/server-card.json"
  printf '{\n  "name": "dot",\n  "version": "%s"\n}\n' "$cmd" \
    >"$SANDBOX/.well-known/agent-card.json"
  # A script_files entry with no version stamp at all, so the "nothing to
  # change here" arm of that loop is exercised alongside the rewriting one.
  printf '.TH DOT 1\n.SH NAME\ndot \\- dotfiles manager\n' \
    >"$SANDBOX/share/man/man1/dot.1"
  mkdir -p "$SANDBOX/scripts/git-hooks" "$SANDBOX/bin" "$SANDBOX/dot_local/bin"
  printf 'echo "v%s standards maintained"\n' "$cmd" >"$SANDBOX/scripts/git-hooks/pre-commit-audit.sh"
  printf 'VERSION="v%s"\n' "$cmd" >"$SANDBOX/bin/dot"
  printf 'VERSION="v%s"\n' "$cmd" >"$SANDBOX/dot_local/bin/executable_tour"
  printf 'DOTFILES_VERSION="%s"\n' "$cmd" >"$SANDBOX/install.sh"
}

# Run the sandboxed script; captures VS_OUT / VS_RC. Set ALLOW_W=1 to permit
# real writes inside the sandbox (otherwise the coverage guard forces dry-run).
#
# Invoked from inside $SANDBOX by its RELATIVE path. That is what makes this
# suite measurable: the coverage aggregator resolves a relative trace source
# against the repo root, so `scripts/version-sync.sh` is attributed to the
# real file. An absolute $SANDBOX path would only resolve while the sandbox
# still exists — and the EXIT trap deletes it long before aggregation runs.
run_vs() {
  VS_OUT="$(
    cd "$SANDBOX" &&
      DOTFILES_ALLOW_COVERAGE_WRITES="${ALLOW_W:-0}" \
        bash scripts/version-sync.sh "$@" 2>&1
  )"
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

# 8. Coverage-visible branch run: full write path, generic replacements,
# script-file sync, no-backup path, and post-write verification. Keep stderr
# visible so the xtrace coverage runner can attribute sourced and child-script
# lines; stdout is enough to discard normal command output.
build_sandbox "8.8.8" "0.0.1" "0.0.1"
test_start "version_sync_exec_branch_visible_write"
live_bento_before="$(shasum -a 256 "$REPO_ROOT/lib/dot/bento.sh" | awk '{print $1}')"
(
  cd "$SANDBOX" || exit 1
  DOTFILES_ALLOW_COVERAGE_WRITES=1 bash scripts/version-sync.sh --force --no-backup >/dev/null
)
assert_file_contains "$SANDBOX/README.md" "Version-v8.8.8" \
  "write path updates README badge"
assert_file_contains "$SANDBOX/docs/reference/FEATURES.md" "dotfiles:8.8.8" \
  "write path updates generic docs"
live_bento_after="$(shasum -a 256 "$REPO_ROOT/lib/dot/bento.sh" | awk '{print $1}')"
assert_equals "$live_bento_before" "$live_bento_after" \
  "sandboxed version sync must not mutate the live checkout"
assert_file_contains "$SANDBOX/scripts/git-hooks/pre-commit-audit.sh" "v8.8.8 standards maintained" \
  "write path updates pre-commit audit banner"

# 9. Coverage-visible fallback discovery: remove rg/jq from PATH so
# find_version_files and get_package_version take the portable sed/grep path.
build_sandbox "7.7.7" "0.0.1" "0.0.1"
test_start "version_sync_exec_branch_visible_portable_fallbacks"
(
  cd "$SANDBOX" || exit 1
  PATH="$PORTABLE_PATH" DOTFILES_ALLOW_COVERAGE_WRITES=1 \
    bash scripts/version-sync.sh --dry-run 7.7.7 >/dev/null
)
assert_file_contains "$CHEZMOIDATA" 'dotfiles_version = "0.0.1"' \
  "portable fallback dry-run leaves files untouched"

# 10. Backup enabled. The default is --backup, and every case above opted out
# with --no-backup, so the branch that actually calls create_backup had never
# been taken. The backup lands in $SANDBOX/.version-sync-backup.
build_sandbox "6.6.6" "0.0.1" "0.0.1"
test_start "version_sync_exec_backup_is_created"
ALLOW_W=1 run_vs --force
assert_equals "0" "$VS_RC" "a backed-up sync should still succeed"
assert_dir_exists "$SANDBOX/.version-sync-backup" \
  "the default --backup path should create the backup directory"

# 11. Write path with neither rg nor jq on PATH: package.json is rewritten by
# sed instead of jq, and the markdown scan uses find+grep.
build_sandbox "5.5.5" "0.0.1" "0.0.1"
test_start "version_sync_exec_portable_write_path"
(
  cd "$SANDBOX" || exit 1
  PATH="$PORTABLE_PATH" DOTFILES_ALLOW_COVERAGE_WRITES=1 \
    bash scripts/version-sync.sh --force --no-backup 5.5.4 >/dev/null
)
assert_file_contains "$SANDBOX/package.json" '"version": "5.5.4"' \
  "the sed fallback should rewrite package.json when jq is absent"
assert_file_contains "$CHEZMOIDATA" 'dotfiles_version = "5.5.4"' \
  "the portable write path should still sync chezmoidata"

# 12. Post-write verification catches a reference the rewrite could not reach.
#
# scripts/git-hooks/pre-commit-audit.sh gets a `case` arm of its own, which
# rewrites only its "vX.Y.Z standards maintained" banner. A second, differently
# shaped stamp in the same file is therefore left behind by the sync and then
# found by the verification pass — which is exactly the failure mode that pass
# exists for.
build_sandbox "4.4.4" "0.0.1" "0.0.1"
printf 'echo "(v0.0.2)"\n' >>"$SANDBOX/scripts/git-hooks/pre-commit-audit.sh"
test_start "version_sync_exec_post_write_verification_failure"
ALLOW_W=1 run_vs --force --no-backup
assert_equals "1" "$VS_RC" "a sync that leaves a stale reference must fail"
assert_contains "failed verification" "$VS_OUT" \
  "the failure should name the verification step"

# 13. A project with no version references at all exits cleanly rather than
# falling through to the rewrite machinery.
test_start "version_sync_exec_no_version_files"
EMPTY="$SANDBOX/empty"
rm -rf "$EMPTY"
mkdir -p "$EMPTY/scripts" "$EMPTY/lib"
ln -s "$VERSION_FILE" "$EMPTY/scripts/version-sync.sh"
# lib/dot only: the sibling lib/ trees carry their own READMEs, which would
# make this "empty" project not empty.
cp -R "$REPO_ROOT/lib/dot" "$EMPTY/lib/dot"
printf '{\n  "version": "3.3.3"\n}\n' >"$EMPTY/package.json"
VS_RC=0
VS_OUT="$(
  cd "$EMPTY" &&
    DOTFILES_ALLOW_COVERAGE_WRITES=0 bash scripts/version-sync.sh 2>&1
)" || VS_RC=$?
assert_equals "0" "$VS_RC" "an empty project should exit 0"
assert_contains "No files with version references" "$VS_OUT" \
  "the empty-project path should say why it did nothing"

# 14. The version is read from package.json by sed when jq is unavailable.
# Every other case either supplies a version explicitly or has jq on PATH, so
# get_package_version's portable arm had never run.
build_sandbox "2.2.2" "0.0.1" "0.0.1"
test_start "version_sync_exec_reads_package_version_without_jq"
VS_RC=0
VS_OUT="$(
  cd "$SANDBOX" &&
    PATH="$PORTABLE_PATH" DOTFILES_ALLOW_COVERAGE_WRITES=0 \
      bash scripts/version-sync.sh --dry-run 2>&1
)" || VS_RC=$?
assert_equals "0" "$VS_RC" "the sed fallback should read package.json cleanly"
assert_contains "package.json version: 2.2.2" "$VS_OUT" \
  "the version should be recovered without jq"

# 15. package.json missing entirely.
test_start "version_sync_exec_requires_package_json"
build_sandbox "1.1.1" "0.0.1" "0.0.1"
rm -f "$SANDBOX/package.json"
run_vs
assert_equals "1" "$VS_RC" "a missing package.json should exit 1"
assert_contains "package.json not found" "$VS_OUT" "the failure should say so"

# 16. package.json present but carrying no usable version.
test_start "version_sync_exec_rejects_an_unreadable_package_version"
build_sandbox "1.1.1" "0.0.1" "0.0.1"
printf '{\n  "name": "demo"\n}\n' >"$SANDBOX/package.json"
run_vs
assert_equals "1" "$VS_RC" "a package.json with no version should exit 1"
assert_contains "Could not extract version" "$VS_OUT" "the failure should say so"

# 17. --backup is also spelled -b, and asking for it explicitly is a
# different arm of the option parser from letting it default.
build_sandbox "7.1.1" "0.0.1" "0.0.1"
test_start "version_sync_exec_explicit_backup_flag"
ALLOW_W=1 run_vs -b --force
assert_equals "0" "$VS_RC" "-b should be accepted"
assert_dir_exists "$SANDBOX/.version-sync-backup" \
  "-b should create the backup directory"

printf 'RESULTS:%s:%s:%s\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
