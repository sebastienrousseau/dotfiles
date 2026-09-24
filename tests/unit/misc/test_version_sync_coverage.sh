#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behavioural coverage for scripts/version-sync.sh against throwaway trees.
#
# The script derives PROJECT_ROOT from its own location, so each fixture is
# a mktemp tree whose scripts/version-sync.sh is a SYMLINK to the real
# script: PROJECT_ROOT resolves to the fixture (never the checkout), while
# coverage still attributes the trace to the real file. lib/ is a copy, so
# nothing the script does can reach back into the repository. Writes are
# enabled explicitly (DOTFILES_ALLOW_COVERAGE_WRITES=1) because they only
# ever land in the fixture.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

VS_REAL="$REPO_ROOT/scripts/version-sync.sh"
WORK="$(mktemp -d -t vs-cov.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# A PATH with neither rg nor jq, to drive the portable fallbacks.
dot_fixture_basebin "$WORK/basebin"

# A BSD-flavoured sed: rejects --version and takes `-i ''`, translated onto
# whichever sed the host really has so the in-place edit still happens.
REAL_SED="$(command -v sed)"
mkdir -p "$WORK/bsdsed"
cat >"$WORK/bsdsed/sed" <<EOF
#!/usr/bin/env bash
[[ "\${1:-}" == "--version" ]] && exit 1
args=()
while [[ \$# -gt 0 ]]; do
  if [[ "\$1" == "-i" && "\${2-x}" == "" ]]; then
    shift 2
    if "$REAL_SED" --version >/dev/null 2>&1; then args+=(-i); else args+=(-i ''); fi
    continue
  fi
  args+=("\$1")
  shift
done
exec "$REAL_SED" "\${args[@]}"
EOF
chmod +x "$WORK/bsdsed/sed"

# new_tree <name>: bare fixture with the script symlinked and lib copied.
new_tree() {
  local t="$WORK/$1"
  mkdir -p "$t/scripts"
  cp -R "$REPO_ROOT/lib" "$t/lib"
  # Only the shell libraries are needed; drop docs so scans see the fixture only.
  find "$t/lib" -type f ! -name '*.sh' -exec rm -f {} +
  ln -s "$VS_REAL" "$t/scripts/version-sync.sh"
  printf '%s\n' "$t"
}

# populate <tree> <version>: every surface version-sync rewrites.
populate() {
  local t="$1" v="$2"
  mkdir -p "$t/defaults" "$t/docs/manual/03-reference" "$t/scripts/git-hooks" \
    "$t/bin" "$t/.well-known/mcp"
  printf 'dotfiles_version = "%s"\n' "$v" >"$t/defaults/.chezmoidata.toml"
  printf '{\n  "name": "fixture",\n  "version": "%s"\n}\n' "$v" >"$t/package.json"
  printf '[badge](https://img.shields.io/badge/Version-v%s-blue)\n' "$v" >"$t/README.md"
  printf '# Doc\n\n**Version**: v%s\n' "$v" >"$t/docs/guide.md"
  printf 'Released in v%s (MILESTONE)\n' "$v" >"$t/docs/MILESTONE_1.md"
  printf 'Audited v%s\n' "$v" >"$t/docs/GOLD-STANDARD-AUDIT.md"
  printf 'History v%s\n' "$v" >"$t/CHANGELOG.md"
  printf 'Welcome to `.dotfiles` v%s\n' "$v" >"$t/docs/manual/00-introduction.md"
  printf 'dotfiles_version = "%s"\n' "$v" >"$t/docs/manual/03-reference/02-config-files.md"
  printf 'echo "v%s standards maintained"\n' "$v" >"$t/scripts/git-hooks/pre-commit-audit.sh"
  printf 'VERSION="v%s"\n' "$v" >"$t/bin/dot"
  printf '{\n  "name": "card",\n  "version": "%s"\n}\n' "$v" >"$t/.well-known/mcp/server-card.json"
}

OUT=""
RC=0
# vs <tree> [--basebin|--bsdsed] args... : run the symlinked script inside
# the tree. --basebin drops rg/jq from PATH; --bsdsed puts a BSD-sed
# emulator first on PATH (no --version, `-i ''` suffix syntax).
vs() {
  local t="$1"
  shift
  local path="$PATH"
  if [[ "${1:-}" == "--basebin" ]]; then
    path="$WORK/basebin"
    shift
  elif [[ "${1:-}" == "--bsdsed" ]]; then
    path="$WORK/bsdsed:$PATH"
    shift
  fi
  RC=0
  # Invoked by a path relative to the fixture: the script still resolves
  # PROJECT_ROOT to the fixture, and the coverage runner maps the relative
  # trace path onto the repository's own copy of the script.
  OUT="$(cd "$t" && env -u DOTFILES_COV_TMPDIR PATH="$path" NO_COLOR=1 \
    DOTFILES_ALLOW_COVERAGE_WRITES=1 "${BASH:-bash}" scripts/version-sync.sh "$@" 2>&1)" || RC=$?
}

# ── argument and manifest errors ───────────────────────────────────────────
T="$(new_tree errs)"

test_start "version_sync_unknown_option"
vs "$T" --bogus
assert_equals 1 "$RC" "unknown option exits 1"
assert_contains "Unknown option: --bogus" "$OUT" "option named"

test_start "version_sync_missing_manifest"
vs "$T"
assert_equals 1 "$RC" "missing manifest exits 1"
assert_contains "Canonical version manifest not found" "$OUT" "missing manifest diagnosed"

test_start "version_sync_manifest_without_version"
printf 'other = "x"\n' >"$T/.chezmoidata.toml"
vs "$T"
assert_equals 1 "$RC" "versionless manifest exits 1"
assert_contains "Could not extract dotfiles_version from .chezmoidata.toml" "$OUT" \
  "legacy root manifest is read and diagnosed"

test_start "version_sync_rejects_invalid_version_argument"
vs "$T" 1.2
assert_equals 1 "$RC" "bad version exits 1"
assert_contains "Invalid version format: 1.2" "$OUT" "bad version named"

test_start "version_sync_no_version_files"
printf 'dotfiles_version = "1.0.0"\n' >"$T/.chezmoidata.toml"
vs "$T" --basebin
assert_equals 0 "$RC" "empty tree exits 0"
assert_contains "No files with version references found" "$OUT" "empty tree reported"

test_start "version_sync_requires_package_json"
printf 'v1.0.0\n' >"$T/README.md"
vs "$T" --no-backup
assert_equals 1 "$RC" "missing package.json exits 1"
assert_contains "package.json not found" "$OUT" "missing package.json diagnosed"

# ── full sync without rg or jq (portable fallbacks) ────────────────────────
T="$(new_tree fallback)"
populate "$T" 0.0.1

test_start "version_sync_dry_run_previews_only"
vs "$T" --basebin -b --dry-run 0.0.2
assert_equals 0 "$RC" "dry-run exits 0"
assert_contains "Would update: docs/guide.md" "$OUT" "markdown preview listed"
assert_contains "Would update: bin/dot" "$OUT" "script preview listed"
assert_contains "Would update: .well-known/mcp/server-card.json" "$OUT" "card preview listed"
assert_file_contains "$T/package.json" '"version": "0.0.1"' "dry-run left package.json alone"

test_start "version_sync_verify_detects_drift_without_rg"
vs "$T" --basebin --verify 0.0.2
assert_equals 1 "$RC" "drift fails verification"
assert_contains "Inconsistent version in README.md" "$OUT" "drifted file named"
assert_contains "Skipping historical file: docs/MILESTONE_1.md" "$OUT" "milestone skipped"

test_start "version_sync_writes_every_surface_without_rg_or_jq"
vs "$T" --basebin --no-backup 0.0.2
assert_equals 0 "$RC" "sync exits 0"
assert_contains "Version Sync Summary" "$OUT" "summary printed"
assert_file_contains "$T/defaults/.chezmoidata.toml" 'dotfiles_version = "0.0.2"' "manifest rewritten"
assert_file_contains "$T/package.json" '"version": "0.0.2"' "package.json rewritten by sed"
assert_file_contains "$T/README.md" "Version-v0.0.2" "badge rewritten"
assert_file_contains "$T/docs/guide.md" "v0.0.2" "doc rewritten"
assert_file_contains "$T/docs/manual/00-introduction.md" "v0.0.2" "manual intro rewritten"
assert_file_contains "$T/docs/manual/03-reference/02-config-files.md" '"0.0.2"' "config sample rewritten"
assert_file_contains "$T/scripts/git-hooks/pre-commit-audit.sh" "v0.0.2 standards" "hook banner rewritten"
assert_file_contains "$T/bin/dot" "v0.0.2" "script stamp rewritten"
assert_file_contains "$T/.well-known/mcp/server-card.json" '"version": "0.0.2"' "card rewritten"
assert_file_contains "$T/docs/MILESTONE_1.md" "v0.0.1" "milestone untouched"
assert_file_contains "$T/CHANGELOG.md" "v0.0.1" "excluded file untouched"

test_start "version_sync_second_run_is_a_noop"
vs "$T" --basebin --no-backup
assert_equals 0 "$RC" "no-op exits 0"
assert_contains "No changes needed - all versions are already synchronized" "$OUT" "no-op reported"

test_start "version_sync_force_reverifies"
vs "$T" --no-backup --force
assert_equals 0 "$RC" "forced no-op exits 0"
assert_contains "Verification:   ✅ Passed" "$OUT" "forced run verifies"

test_start "version_sync_verify_passes"
vs "$T" -v
assert_equals 0 "$RC" "consistent tree verifies"
assert_contains "All version references are consistent: v0.0.2" "$OUT" "consistency reported"

test_start "version_sync_uses_bsd_sed_syntax_when_sed_is_not_gnu"
vs "$T" --bsdsed --no-backup 0.0.3
assert_equals 0 "$RC" "BSD-sed sync exits 0"
assert_file_contains "$T/docs/guide.md" "v0.0.3" "doc rewritten through BSD syntax"
assert_file_contains "$T/defaults/.chezmoidata.toml" 'dotfiles_version = "0.0.3"' \
  "manifest rewritten through BSD syntax"

# ── with rg/jq (when installed) and a post-sync verification failure ──────
T="$(new_tree unfixable)"
populate "$T" 0.0.1
# A README line version-sync does not rewrite but the verifier flags.
printf 'Version: 0.0.1\n' >>"$T/README.md"

test_start "version_sync_fails_when_verification_fails"
vs "$T" --no-backup 0.0.2
assert_equals 1 "$RC" "unfixable drift exits 1"
assert_contains "Version synchronization failed verification" "$OUT" "verification failure reported"
assert_file_contains "$T/package.json" '"version": "0.0.2"' "package.json rewritten"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" == 0 ]]
