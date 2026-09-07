#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Fixture-driven tests for scripts/qa/check-version-consistency.sh.
# The script derives REPO_ROOT from its own location, so each case
# symlinks it into a throwaway tree holding the eight version surfaces
# and then drifts one of them: missing file, missing pattern, wrong
# version (with and without --fix), unreadable canonical version.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Route child xtrace to the runner's trace stream even when a probe
# captures 2>&1 (fd 19: fd 9 is taken by lock handling elsewhere).
exec 21>&2
export BASH_XTRACEFD=21

SCRIPT_FILE="$REPO_ROOT/scripts/qa/check-version-consistency.sh"
BASH_BIN="$(command -v bash)"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

# Substring refutation on an already-captured string. The framework's
# assert_output_not_contains re-runs its arguments through `eval`, so
# feeding captured output back in breaks on any shell metacharacter the
# program happened to print.
_refute_contains() { # <needle> <haystack> <msg>
  if [[ "$2" != *"$1"* ]]; then
    ((TESTS_PASSED++)) || true
    printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST: $3"
    return 0
  fi
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $3"
  printf '%b\n' "    Should not contain: '$1'"
  return 1
}

# Build a fixture tree where every live surface carries <version>.
# Prints the fixture root; the checker runs against it through
# REPO_ROOT rather than being copied or symlinked into the tree —
# a symlinked copy also hides the run from the coverage aggregator,
# which resolves trace paths after the sandbox is gone.
_fixture() { # <name> <version>
  local root="$DOTFILES_COV_TMPDIR/fx-$1" v="$2"
  mkdir -p "$root/scripts/qa" "$root/defaults" "$root/bin" "$root/share/man/man1" "$root/lib/dot"
  printf 'dotfiles_version = "%s"\n' "$v" >"$root/defaults/.chezmoidata.toml"
  printf '{\n  "name": "dotfiles",\n  "version": "%s"\n}\n' "$v" >"$root/package.json"
  printf '#!/usr/bin/env bash\n# Dotfiles CLI Entry Point - v%s\nVERSION="%s"\n' "$v" "$v" >"$root/bin/dot"
  printf '.TH DOT 1 "2026" "dotfiles v%s" "User Commands"\n' "$v" >"$root/share/man/man1/dot.1"
  printf 'banner="D O T F I L E S [v%s]"\n' "$v" >"$root/lib/dot/bento.sh"
  printf '# Dotfiles\n\n![Version](https://img.shields.io/badge/Version-v%s-blue)\n' "$v" >"$root/README.md"
  printf 'Chezmoi-managed dotfiles. Version `%s`.\n' "$v" >"$root/CLAUDE.md"
  printf 'Chezmoi-managed dotfiles. Version `%s`.\n' "$v" >"$root/AGENTS.md"
  printf '%s\n' "$root"
}

_check() { # <fixture-root> [args]
  local root="$1"
  shift
  REPO_ROOT="$root" "$BASH_BIN" "$SCRIPT_FILE" "$@" 2>&1
}

test_start "help_and_unknown_flag"
_root="$(_fixture help 1.2.3)"
_out="$(_check "$_root" --help)"
assert_equals 0 $? "--help exits 0"
assert_contains "Verify that every" "$_out" "help text printed"
_out="$(_check "$_root" --bogus)"
assert_equals 2 $? "unknown flag exits 2"
assert_contains "unknown flag: --bogus" "$_out" "unknown flag named"

test_start "all_surfaces_match_exits_0"
_root="$(_fixture match 1.2.3)"
_out="$(_check "$_root")"
_rc=$?
assert_equals 0 "$_rc" "matching tree exits 0"
assert_contains "canonical: 1.2.3" "$_out" "canonical version logged"
assert_contains "all 8 live version surfaces match 1.2.3" "$_out" "success summary printed"

test_start "quiet_suppresses_output_but_keeps_rc"
_root="$(_fixture quiet 1.2.3)"
_out="$(_check "$_root" --quiet)"
_rc=$?
assert_equals 0 "$_rc" "--quiet exits 0"
assert_equals "" "$_out" "--quiet prints nothing"
_out="$(_check "$_root" -q)"
assert_equals 0 $? "-q exits 0"

test_start "missing_canonical_version_exits_2"
_root="$(_fixture nocanon 1.2.3)"
printf 'other = "x"\n' >"$_root/defaults/.chezmoidata.toml"
_out="$(_check "$_root")"
_rc=$?
assert_equals 2 "$_rc" "missing canonical exits 2"
assert_contains "failed to read dotfiles_version" "$_out" "canonical error printed"

test_start "missing_surface_file_is_drift"
_root="$(_fixture missing 1.2.3)"
rm -f "$_root/AGENTS.md"
_out="$(_check "$_root")"
_rc=$?
assert_equals 1 "$_rc" "missing file exits 1"
assert_contains "MISSING: AGENTS.md" "$_out" "missing file named"
assert_contains "Tip: rerun with --fix" "$_out" "fix tip printed"

test_start "missing_pattern_is_drift"
_root="$(_fixture nopattern 1.2.3)"
printf '# Dotfiles\n\nno badge here\n' >"$_root/README.md"
_out="$(_check "$_root")"
_rc=$?
assert_equals 1 "$_rc" "missing pattern exits 1"
assert_contains "PATTERN NOT FOUND: 'img.shields.io/badge/Version' in README.md" "$_out" "pattern named"

test_start "drifted_surface_reported_then_fixed"
_root="$(_fixture drift 1.2.3)"
printf '#!/usr/bin/env bash\n# Dotfiles CLI Entry Point - v1.0.0\nVERSION="1.2.3"\n' >"$_root/bin/dot"
_out="$(_check "$_root")"
_rc=$?
assert_equals 1 "$_rc" "drift exits 1"
assert_contains "DRIFT in bin/dot" "$_out" "drifted file named"
assert_contains "found:    # Dotfiles CLI Entry Point - v1.0.0" "$_out" "found line echoed"
assert_contains "expected: contains '# Dotfiles CLI Entry Point - v1.2.3'" "$_out" "expected substring echoed"
_out="$(_check "$_root" --fix)"
_rc=$?
assert_equals 1 "$_rc" "--fix run still exits 1 (verify on rerun)"
assert_contains "fixed:  bin/dot  (v1.0.0 → v1.2.3)" "$_out" "fix logged"
assert_contains "Auto-fixed where safe" "$_out" "fix summary printed"
assert_file_contains "$_root/bin/dot" "Entry Point - v1.2.3" "header rewritten"
assert_file_not_exists "$_root/bin/dot.bak" "sed backup removed"
_out="$(_check "$_root")"
assert_equals 0 $? "tree is consistent after --fix"

test_start "fix_skips_lines_without_a_vX_Y_Z_token"
_root="$(_fixture nofix 1.2.3)"
printf '#!/usr/bin/env bash\n# Dotfiles CLI Entry Point - v1.2.3\nVERSION="9.9.9"\n' >"$_root/bin/dot"
_out="$(_check "$_root" --fix)"
_rc=$?
assert_equals 1 "$_rc" "unfixable drift exits 1"
assert_contains "DRIFT in bin/dot" "$_out" "drift reported"
_refute_contains "fixed:" "$_out" "nothing is rewritten when the tree is in sync"
assert_file_contains "$_root/bin/dot" 'VERSION="9.9.9"' "unsafe line left untouched"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
