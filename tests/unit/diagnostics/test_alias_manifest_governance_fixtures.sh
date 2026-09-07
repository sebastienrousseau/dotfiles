#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Behaviour tests for the alias inventory pair:
#
#   aliases-manifest.sh  — emits name/value/file/line TSV rows for every
#                          alias in a chezmoi source tree, including the
#                          `cond && alias x=y` form, and honours
#                          `.chezmoiroot`.
#   alias-governance.sh  — grades that manifest: duplicate names, risky
#                          overrides that are not gated behind a
#                          DOTFILES_* flag, and hardcoded /Users paths,
#                          under both the standard and strict policies.
#
# Every case runs against a throwaway source tree pointed at through
# CHEZMOI_SOURCE_DIR, so the assertions never depend on the aliases the
# repo itself happens to ship.
#
# AUTO-GENERATED: false (hand-written)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

# Hand children a copy of the real stderr so their xtrace still reaches
# the coverage runner even though the probes capture output with 2>&1.
exec 21>&2
export BASH_XTRACEFD=21

MANIFEST="$REPO_ROOT/scripts/diagnostics/aliases-manifest.sh"
GOVERNANCE="$REPO_ROOT/scripts/diagnostics/alias-governance.sh"
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

# _tree <name> — an empty source tree with both directories the
# manifest searches (a missing one makes ripgrep exit 2).
_tree() {
  local root="$DOTFILES_COV_TMPDIR/$1"
  mkdir -p "$root/.chezmoitemplates/aliases" "$root/.chezmoitemplates/functions"
  printf '%s\n' "$root"
}

_manifest() { # <source-dir> [args…]
  CHEZMOI_SOURCE_DIR="$1" "$BASH_BIN" "$MANIFEST" "${@:2}" 2>&1
}

_govern() { # <source-dir> [ENV=value …]
  local src="$1"
  shift
  env CHEZMOI_SOURCE_DIR="$src" CI="" "$@" "$BASH_BIN" "$GOVERNANCE" 2>&1
}

# ── aliases-manifest.sh ──────────────────────────────────────────────
test_start "manifest_help_and_unknown_option"
_root="$(_tree m-help)"
_out="$(_manifest "$_root" --help)"
assert_equals 0 "$?" "--help exits 0"
assert_contains "Usage: aliases-manifest.sh" "$_out" "usage printed"
_out="$(_manifest "$_root" --bogus)"
assert_equals 2 "$?" "unknown option exits 2"
assert_contains "Unknown option: --bogus" "$_out" "option named"

test_start "manifest_emits_name_value_file_line_rows"
_root="$(_tree m-rows)"
_af="$_root/.chezmoitemplates/aliases/base.aliases.sh"
{
  echo "alias ll='ls -l'"
  echo "# a comment"
  echo "alias gs='git status'"
} >"$_af"
_out="$(_manifest "$_root")"
_rc=$?
assert_equals 0 "$_rc" "manifest exits 0"
assert_contains "$(printf 'll\t%s\t%s\t1' "'ls -l'" "$_af")" "$_out" "first alias row is name/value/file/line"
assert_contains "$(printf 'gs\t%s\t%s\t3' "'git status'" "$_af")" "$_out" "line numbers follow the file"
assert_equals 2 "$(printf '%s\n' "$_out" | wc -l | tr -d ' ')" "comments are not rows"

test_start "manifest_catches_conditionally_defined_aliases"
_root="$(_tree m-cond)"
printf 'command -v eza >/dev/null && alias ls="eza"\n' \
  >"$_root/.chezmoitemplates/aliases/cond.aliases.sh"
_out="$(_manifest "$_root")"
assert_equals 0 "$?" "conditional alias tree exits 0"
assert_contains "ls" "$_out" "the gated alias is still inventoried"

test_start "manifest_takes_the_source_dir_as_an_argument"
_root="$(_tree m-arg)"
printf "alias p='pwd'\n" >"$_root/.chezmoitemplates/aliases/p.aliases.sh"
_out="$(CHEZMOI_SOURCE_DIR="" "$BASH_BIN" "$MANIFEST" "$_root" 2>&1)"
assert_equals 0 "$?" "explicit source dir exits 0"
assert_contains "p" "$_out" "aliases from the argument tree are listed"

test_start "manifest_descends_into_the_chezmoiroot_subdirectory"
_root="$DOTFILES_COV_TMPDIR/m-root"
mkdir -p "$_root/defaults/.chezmoitemplates/aliases" "$_root/defaults/.chezmoitemplates/functions"
printf 'defaults\n' >"$_root/.chezmoiroot"
printf "alias inner='echo inner'\n" \
  >"$_root/defaults/.chezmoitemplates/aliases/inner.aliases.sh"
_out="$(_manifest "$_root")"
_rc=$?
assert_equals 0 "$_rc" "chezmoiroot tree exits 0"
assert_contains "inner" "$_out" "aliases below .chezmoiroot are found"
assert_contains "/defaults/.chezmoitemplates/aliases/inner.aliases.sh" "$_out" "row points at the real file"

# ── alias-governance.sh ──────────────────────────────────────────────
test_start "governance_passes_a_clean_tree"
_root="$(_tree g-clean)"
printf "alias ll='ls -l'\nalias gs='git status'\n" \
  >"$_root/.chezmoitemplates/aliases/base.aliases.sh"
_out="$(_govern "$_root")"
_rc=$?
assert_equals 0 "$_rc" "clean tree exits 0"
assert_contains "Policy: standard" "$_out" "default policy reported"
assert_contains "OK: no duplicate alias names" "$_out" "duplicate check passed"
assert_contains "OK: risky overrides are gated" "$_out" "override check passed"
assert_contains "OK: no hardcoded /Users paths in aliases" "$_out" "path check passed"
assert_contains "Alias governance checks passed." "$_out" "summary line printed"

test_start "governance_warns_about_duplicates_under_the_standard_policy"
_root="$(_tree g-dup)"
printf "alias ll='ls -l'\n" >"$_root/.chezmoitemplates/aliases/a.aliases.sh"
printf "alias ll='ls -lah'\n" >"$_root/.chezmoitemplates/aliases/b.aliases.sh"
_out="$(_govern "$_root")"
_rc=$?
assert_equals 0 "$_rc" "a duplicate is only a warning by default"
assert_contains "WARN: duplicate alias names detected" "$_out" "warning printed"
assert_contains "- ll" "$_out" "the duplicate name is listed"

test_start "governance_fails_on_duplicates_under_the_strict_policy"
_out="$(_govern "$_root" DOTFILES_ALIAS_POLICY=strict)"
_rc=$?
assert_equals 1 "$_rc" "strict policy exits 1"
assert_contains "Policy: strict" "$_out" "strict policy reported"
assert_contains "ERROR: duplicate alias names detected" "$_out" "duplicates are an error"
assert_contains "Alias governance checks failed: 1 issue(s)." "$_out" "failure summary counts the issue"

test_start "governance_defaults_to_strict_in_ci"
_out="$(env CHEZMOI_SOURCE_DIR="$_root" CI=true "$BASH_BIN" "$GOVERNANCE" 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "CI without an explicit policy exits 1"
assert_contains "Policy: strict" "$_out" "CI implies the strict policy"

test_start "governance_rejects_an_ungated_risky_override"
_root="$(_tree g-risky)"
printf "alias cd='pushd'\n" >"$_root/.chezmoitemplates/aliases/risky.aliases.sh"
_out="$(_govern "$_root")"
_rc=$?
assert_equals 1 "$_rc" "ungated override exits 1"
assert_contains "ERROR: risky override 'cd'" "$_out" "the override is named"
assert_contains "is not gated by a DOTFILES_* flag" "$_out" "the requirement is explained"

test_start "governance_accepts_a_gated_risky_override"
_root="$(_tree g-gated)"
# The manifest's conditional-alias pattern only matches a gate with no
# quote characters before the `&&`, so the fixture uses that form.
{
  echo "# Enable with DOTFILES_ENABLE_CD=1"
  echo '[ -n ${DOTFILES_ENABLE_CD:-} ] && alias cd=pushd'
} >"$_root/.chezmoitemplates/aliases/gated.aliases.sh"
_out="$(_govern "$_root")"
_rc=$?
assert_equals 0 "$_rc" "gated override exits 0"
assert_contains "OK: risky overrides are gated" "$_out" "override check passes"

test_start "governance_flags_an_expired_deprecated_alias"
# scripts/dot/data/alias-deprecations.tsv lists dlogsf as removable
# since v0.2.487; the repo is past that, so a tree that still defines
# the alias must fail the deprecation window.
_root="$(_tree g-deprecated)"
printf "alias dlogsf='docker logs -f'\n" \
  >"$_root/.chezmoitemplates/aliases/deprecated.aliases.sh"
_out="$(_govern "$_root")"
_rc=$?
assert_equals 1 "$_rc" "an expired deprecated alias exits 1"
assert_contains "ERROR: expired deprecated aliases still present" "$_out" "the expired window is reported"
assert_contains "dlogsf (remove_in=v0.2.487, replacement=dklf)" "$_out" "the replacement is suggested"

test_start "governance_reports_a_clean_deprecation_window"
_root="$(_tree g-notdeprecated)"
printf "alias dkl='docker logs'\n" >"$_root/.chezmoitemplates/aliases/ok.aliases.sh"
_out="$(_govern "$_root")"
assert_equals 0 "$?" "no expired aliases exits 0"
assert_contains "OK: no expired deprecated aliases" "$_out" "the window check is reported as passing"

test_start "manifest_falls_back_to_grep_without_ripgrep"
_root="$(_tree m-nogrep)"
printf "alias gg='git grep'\n" >"$_root/.chezmoitemplates/aliases/g.aliases.sh"
_nogrep="$DOTFILES_COV_TMPDIR/nogrep"
mkdir -p "$_nogrep"
for _t in bash grep sed head tr cat printf echo dirname basename; do
  _p="$(command -v "$_t" 2>/dev/null || true)"
  [[ -n "$_p" ]] && ln -sf "$_p" "$_nogrep/$_t"
done
_out="$(CHEZMOI_SOURCE_DIR="$_root" PATH="$_nogrep" "$BASH_BIN" "$MANIFEST" 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "the grep fallback exits 0"
assert_contains "gg" "$_out" "aliases are still inventoried without ripgrep"

test_start "manifest_resolves_the_default_chezmoi_checkout"
# No CHEZMOI_SOURCE_DIR and no ~/.dotfiles: the manifest falls back to
# ~/.local/share/chezmoi.
_home="$DOTFILES_COV_TMPDIR/xdg-home"
mkdir -p "$_home/.local/share/chezmoi/.chezmoitemplates/aliases" \
  "$_home/.local/share/chezmoi/.chezmoitemplates/functions"
printf "alias xdg='echo xdg'\n" \
  >"$_home/.local/share/chezmoi/.chezmoitemplates/aliases/x.aliases.sh"
_out="$(env -u CHEZMOI_SOURCE_DIR HOME="$_home" "$BASH_BIN" "$MANIFEST" 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "the default checkout is used"
assert_contains "xdg" "$_out" "its aliases are inventoried"
assert_contains "$_home/.local/share/chezmoi" "$_out" "rows point into that checkout"

test_start "governance_reaches_the_same_verdict_without_ripgrep"
# The CI runners have no ripgrep. Before alias-governance.sh grew a grep
# fallback, `rg` exiting 127 read as "no match" and every gated override
# was reported as ungated — the repo's own governance run failed with
# eight phantom errors on Linux.
_norg="$DOTFILES_COV_TMPDIR/norg"
mkdir -p "$_norg"
for _t in bash grep sed awk sort uniq head tail cut wc tr cat printf echo \
  mktemp rm dirname basename jq; do
  _p="$("$BASH_BIN" -c "command -v $_t" 2>/dev/null || true)"
  [[ -n "$_p" ]] && ln -sf "$_p" "$_norg/$_t"
done

_root="$(_tree g-gated-norg)"
{
  echo "# Enable with DOTFILES_ENABLE_CD=1"
  echo '[ -n ${DOTFILES_ENABLE_CD:-} ] && alias cd=pushd'
} >"$_root/.chezmoitemplates/aliases/gated.aliases.sh"
_out="$(env CHEZMOI_SOURCE_DIR="$_root" CI="" PATH="$_norg" "$BASH_BIN" "$GOVERNANCE" 2>&1)"
_rc=$?
assert_equals 0 "$_rc" "a gated override still passes without ripgrep"
assert_contains "OK: risky overrides are gated" "$_out" "the gate is evaluated, not skipped"
_refute_contains "command not found" "$_out" "no tool is missing from the fallback path"

_root="$(_tree g-risky-norg)"
printf "alias cd='pushd'\n" >"$_root/.chezmoitemplates/aliases/risky.aliases.sh"
_out="$(env CHEZMOI_SOURCE_DIR="$_root" CI="" PATH="$_norg" "$BASH_BIN" "$GOVERNANCE" 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "an ungated override still fails without ripgrep"
assert_contains "ERROR: risky override 'cd'" "$_out" "the same error is produced"

# The deprecation window also searches the tree with ripgrep; exercise
# its grep fallback (recursive + --include globs) too.
_root="$(_tree g-deprecated-norg)"
printf "alias dlogsf='docker logs -f'\n" \
  >"$_root/.chezmoitemplates/aliases/deprecated.aliases.sh"
_out="$(env CHEZMOI_SOURCE_DIR="$_root" CI="" PATH="$_norg" "$BASH_BIN" "$GOVERNANCE" 2>&1)"
_rc=$?
assert_equals 1 "$_rc" "an expired deprecation still fails without ripgrep"
assert_contains "expired deprecated aliases still present" "$_out" "the same verdict is reached"

test_start "governance_rejects_hardcoded_user_paths"
_root="$(_tree g-paths)"
printf "alias proj='cd /Users/someone/code'\n" \
  >"$_root/.chezmoitemplates/aliases/paths.aliases.sh"
_out="$(_govern "$_root")"
_rc=$?
assert_equals 1 "$_rc" "hardcoded path exits 1"
assert_contains "ERROR: hardcoded /Users paths detected in aliases" "$_out" "error printed"
assert_contains "proj" "$_out" "the offending alias is named"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
