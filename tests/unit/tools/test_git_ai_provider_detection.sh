#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Provider auto-detection in git-ai-commit and git-ai-diff.
#
# Both scripts pick a provider with a five-deep `elif command -v …` chain, and
# both existing suites always pass --provider or set GIT_AI_PROVIDER, so only
# the first arm ever ran. An `elif` chain is only exercised by hiding the arms
# above the one under test, which means running each case with a PATH that
# carries exactly one provider — and, for the last arm, none at all.
#
# The same PATH discipline reaches the other two unrun branches: a provider
# that returns nothing, so the "could not generate / could not analyze"
# failure is watched firing.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

COMMIT_BIN="$REPO_ROOT/defaults/dot_local/bin/executable_git-ai-commit"
DIFF_BIN="$REPO_ROOT/defaults/dot_local/bin/executable_git-ai-diff"

WORK="$(mktemp -d -t gitai.XXXXXX)"
cov_setup_sandbox
trap 'rm -rf "$WORK"; cov_teardown_sandbox' EXIT

mkdir -p "$WORK/base" "$WORK/repo"
dot_fixture_basebin "$WORK/base"

# A git shim with canned answers. Neither script may reach a real repository:
# `git commit` here records what it was asked to do and nothing else.
cat >"$WORK/base/git" <<'STUB'
#!/bin/sh
case "$*" in
  "diff --cached --quiet") exit 1 ;;
  "diff --cached --stat" | *"--stat") printf ' file.txt | 2 +-\n' ;;
  "diff --cached" | diff*) printf 'diff --git a/file.txt b/file.txt\n+new\n-old\n' ;;
  commit*) printf 'committed\n' ;;
  *) : ;;
esac
exit 0
STUB
chmod +x "$WORK/base/git"

# ga_provider <dir> <name> <output> — a provider stub that swallows any
# prompt on stdin and prints <output>.
ga_provider() {
  local dir="$1" name="$2" out="$3"
  mkdir -p "$dir"
  {
    printf '#!/bin/sh\n'
    printf 'cat >/dev/null 2>&1 || true\n'
    printf 'printf "%%s\\n" "%s"\n' "$out"
    printf 'exit 0\n'
  } >"$dir/$name"
  chmod +x "$dir/$name"
}

GA_OUT=""
GA_RC=0
# ga_run <script> <provider-dir> [args...] — run with a PATH holding only the
# base tools and whatever <provider-dir> contains.
ga_run() {
  local script="$1" pdir="$2"
  shift 2
  GA_RC=0
  GA_OUT="$(
    cd "$WORK/repo" &&
      PATH="$pdir:$WORK/base" GIT_AI_PROVIDER="" \
        "${BASH:-bash}" "$script" "$@" <<<"n" 2>&1
  )" || GA_RC=$?
}

# ── 1. git-ai-commit walks the provider chain ──────────────────────────────
for provider in aider agy sgpt ollama; do
  pdir="$WORK/only-$provider"
  ga_provider "$pdir" "$provider" "fix(test): message from $provider"
  test_start "git_ai_commit_detects_$provider"
  ga_run "$COMMIT_BIN" "$pdir"
  assert_contains "using $provider" "$GA_OUT" \
    "with only $provider installed it should be the one chosen"
done

test_start "git_ai_commit_reports_no_provider"
mkdir -p "$WORK/none"
ga_run "$COMMIT_BIN" "$WORK/none"
assert_equals "1" "$GA_RC" "no provider at all should exit 1"
assert_contains "No AI provider found" "$GA_OUT" "the failure should say so"

test_start "git_ai_commit_reports_an_empty_generation"
ga_provider "$WORK/silent" "sgpt" ""
ga_run "$COMMIT_BIN" "$WORK/silent"
assert_equals "1" "$GA_RC" "a provider that says nothing should exit 1"
assert_contains "Failed to generate commit message" "$GA_OUT" \
  "the failure should name the step that produced nothing"

# ── 2. git-ai-diff walks the same chain ────────────────────────────────────
for provider in aider agy sgpt ollama; do
  pdir="$WORK/only-$provider"
  test_start "git_ai_diff_detects_$provider"
  ga_run "$DIFF_BIN" "$pdir"
  assert_contains "using $provider" "$GA_OUT" \
    "with only $provider installed it should be the one chosen"
done

test_start "git_ai_diff_reports_no_provider"
ga_run "$DIFF_BIN" "$WORK/none"
assert_equals "1" "$GA_RC" "no provider at all should exit 1"
assert_contains "No AI provider found" "$GA_OUT" "the failure should say so"

test_start "git_ai_diff_reports_an_empty_analysis"
ga_run "$DIFF_BIN" "$WORK/silent"
assert_equals "1" "$GA_RC" "a provider that says nothing should exit 1"
assert_contains "Failed to analyze diff" "$GA_OUT" \
  "the failure should name the step that produced nothing"

print_summary
