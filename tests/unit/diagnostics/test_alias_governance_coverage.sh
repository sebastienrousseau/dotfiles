#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behavioural coverage for scripts/diagnostics/alias-governance.sh.
#
# The gate reads its manifest generator, deprecation table and package.json
# relative to its own directory. Each case builds a mktemp tree whose
# scripts/diagnostics/alias-governance.sh is a symlink to the real script,
# with a stub aliases-manifest.sh that prints a canned manifest, so every
# verdict (strict/standard policy, gated/ungated overrides, hardcoded paths,
# expired deprecations, with and without ripgrep) is decided by the fixture.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

GOV_REAL="$REPO_ROOT/scripts/diagnostics/alias-governance.sh"
WORK="$(mktemp -d -t ag-cov.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# PATH without rg, for the grep fallbacks.
dot_fixture_basebin "$WORK/basebin"

# new_tree <name> <manifest-rows> : fixture tree + canned manifest.
new_tree() {
  local t="$WORK/$1"
  mkdir -p "$t/scripts/diagnostics" "$t/scripts/dot/data" \
    "$t/defaults/.chezmoitemplates/aliases/gnu"
  ln -s "$GOV_REAL" "$t/scripts/diagnostics/alias-governance.sh"
  printf '%b' "$2" >"$t/manifest.tsv"
  printf '#!/bin/sh\ncat "%s"\n' "$t/manifest.tsv" >"$t/scripts/diagnostics/aliases-manifest.sh"
  chmod +x "$t/scripts/diagnostics/aliases-manifest.sh"
  printf '%s\n' "$t"
}

OUT=""
RC=0
# gov <tree> [--basebin] [VAR=val...]
gov() {
  local t="$1"
  shift
  local path="$PATH"
  if [[ "${1:-}" == "--basebin" ]]; then
    path="$WORK/basebin"
    shift
  fi
  RC=0
  # Relative invocation: the coverage runner maps a relative trace path
  # onto the repository's copy, while SCRIPT_DIR still resolves to the tree.
  OUT="$(cd "$t" && env -u CI -u DOTFILES_ALIAS_POLICY PATH="$path" "$@" \
    "${BASH:-bash}" scripts/diagnostics/alias-governance.sh 2>&1)" || RC=$?
}

test_start "alias_governance_requires_manifest_script"
mkdir -p "$WORK/nomanifest/scripts/diagnostics"
ln -s "$GOV_REAL" "$WORK/nomanifest/scripts/diagnostics/alias-governance.sh"
RC=0
OUT="$(cd "$WORK/nomanifest" && "${BASH:-bash}" scripts/diagnostics/alias-governance.sh 2>&1)" || RC=$?
assert_equals 1 "$RC" "missing manifest generator exits 1"
assert_contains "aliases-manifest.sh not found or not executable" "$OUT" "missing generator named"

# A tree that violates every rule.
bad_rows=""
bad_rows+="ll\tls -l\tA\t1\n"
bad_rows+="ll\tls -la\tA\t2\n"
T="$(new_tree bad "$bad_rows")"
risky="$T/defaults/.chezmoitemplates/aliases/risky.aliases.sh"
printf "alias rm='rm -i'\n" >"$risky"
gnu="$T/defaults/.chezmoitemplates/aliases/gnu/gnu.aliases.sh"
printf "alias cp='gcp'\n" >"$gnu"
printf 'rm\trm -i\t%s\t1\n' "$risky" >>"$T/manifest.tsv"
printf 'cp\tgcp\t%s\t1\n' "$gnu" >>"$T/manifest.tsv"
printf 'proj\tcd /Users/someone/proj\t%s\t2\n' "$risky" >>"$T/manifest.tsv"
printf 'oldal\techo old\t%s\t3\n' "$risky" >>"$T/manifest.tsv"
printf 'oldfn() {\n  :\n}\n' >"$T/defaults/.chezmoitemplates/aliases/legacy.sh"
printf '{\n  "version": "1.2.3"\n}\n' >"$T/package.json"
printf '# alias\treplacement\tremove_in\n\noldal\tnewal\t1.0.0\noldfn\tnewfn\tv1.2.0\nfuture\tx\t9.0.0\ngone\tx\t1.0.0\nsamever\tx\t1.2.3\n' \
  >"$T/scripts/dot/data/alias-deprecations.tsv"

for mode in rg basebin; do
  test_start "alias_governance_strict_ci_fails_every_rule_$mode"
  if [[ "$mode" == "basebin" ]]; then
    gov "$T" --basebin CI=1
  else
    gov "$T" CI=1
  fi
  assert_equals 1 "$RC" "violations exit 1"
  assert_contains "Policy: strict" "$OUT" "CI selects strict policy"
  assert_contains "ERROR: duplicate alias names detected:" "$OUT" "strict dupes are errors"
  assert_contains "  - ll" "$OUT" "duplicate listed"
  assert_contains "risky override 'rm'" "$OUT" "ungated override flagged"
  if [[ "$OUT" == *"override 'cp'"* ]]; then
    assert_equals "gnu exempt" "gnu flagged" "gnu overrides are exempt"
  else
    assert_equals "gnu exempt" "gnu exempt" "gnu overrides are exempt"
  fi
  assert_contains "hardcoded /Users paths detected" "$OUT" "hardcoded path flagged"
  assert_contains "oldal (remove_in=1.0.0, replacement=newal)" "$OUT" "expired alias flagged"
  assert_contains "oldfn (remove_in=v1.2.0, replacement=newfn)" "$OUT" "expired function flagged"
  assert_contains "Alias governance checks failed: 4 issue(s)." "$OUT" "issue count summarised"
done

# A clean tree under the standard policy: duplicates only warn.
clean_rows="ll\tls -l\tA\t1\nll\tls -la\tA\t2\n"
T="$(new_tree clean "$clean_rows")"
gated="$T/defaults/.chezmoitemplates/aliases/gated.aliases.sh"
printf 'if [ "${DOTFILES_SAFE_RM:-0}" = 1 ]; then alias rm="rm -i"; fi\n' >"$gated"
printf 'rm\trm -i\t%s\t1\n' "$gated" >>"$T/manifest.tsv"
printf 'gone\tx\t0.0.1\n' >"$T/scripts/dot/data/alias-deprecations.tsv"

test_start "alias_governance_standard_policy_passes_clean_tree"
gov "$T" --basebin DOTFILES_ALIAS_POLICY=standard
assert_equals 0 "$RC" "clean tree exits 0"
assert_contains "WARN: duplicate alias names detected (review recommended):" "$OUT" "dupes only warn"
assert_contains "OK: risky overrides are gated" "$OUT" "gated override accepted"
assert_contains "OK: no hardcoded /Users paths in aliases" "$OUT" "no hardcoded paths"
assert_contains "OK: no expired deprecated aliases (repo version: v0.0.0)" "$OUT" \
  "missing package.json falls back to v0.0.0"
assert_contains "Alias governance checks passed." "$OUT" "pass summarised"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" == 0 ]]
