#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Failure and fall-back paths of scripts/dot/commands/tools.sh.
#
# `dot tools`, `dot env` and `dot profile` all branch on what the source tree
# and the PATH happen to contain, and from the checkout those answers are
# fixed: nix/flake.nix and docs/ are always present, mise and python3 are
# always installed on a developer machine. This suite runs the module against
# a fixture source tree it controls file by file, with a PATH holding only
# the stubs each case wants found.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

cov_setup_sandbox
trap cov_teardown_sandbox EXIT

FX="$(dot_fixture_new tools-paths)"
mkdir -p "$FX/home" "$FX/stubs" "$FX/docs"
dot_fixture_basebin "$FX/basebin"
DOT_FIXTURE_HOME="$FX/home"

tools_run() {
  DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" dot_fixture_run "$FX" tools "$@"
}

# ── 1. tools install needs a flake in the source tree ──────────────────────
test_start "tools_install_requires_a_nix_flake"
dot_fixture_stub "$FX/stubs" nix 0
tools_run tools install
assert_equals "1" "$DOT_FIXTURE_RC" "install without a flake should exit 1"
assert_contains "not found in source directory" "$DOT_FIXTURE_OUT" \
  "the failure should name the flake"

# ── 2. tools docs prefers TOOLS.md, then UTILS.md ──────────────────────────
test_start "tools_docs_falls_back_to_utils_md"
printf '# Fixture utils\n' >"$FX/docs/UTILS.md"
tools_run tools docs
assert_equals "0" "$DOT_FIXTURE_RC" "docs should exit 0 when UTILS.md exists"
assert_contains "Fixture utils" "$DOT_FIXTURE_OUT" "UTILS.md should be printed"

test_start "tools_docs_prefers_tools_md"
printf '# Fixture tools\n' >"$FX/docs/TOOLS.md"
tools_run tools docs
assert_contains "Fixture tools" "$DOT_FIXTURE_OUT" \
  "TOOLS.md should win when both exist"

# ── 3. dot new pre-flights its Python dependency ───────────────────────────
#
# The check happens before any files are created, so a machine without
# python3 gets a clean error rather than a half-written project.
mkdir -p "$FX/templates/projects/node"
printf '{ "name": "__PROJECT_NAME__" }\n' >"$FX/templates/projects/node/package.json"

test_start "tools_new_accepts_python_as_a_fallback_interpreter"
dot_fixture_stub "$FX/stubs" python 0
DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" \
  dot_fixture_run "$FX" tools new node demoproject
assert_dir_exists "$FX/demoproject" \
  "plain python should satisfy the pre-flight and the project be scaffolded"
assert_file_exists "$FX/demoproject/package.json" \
  "the template contents should be copied across"

test_start "tools_new_requires_a_python_interpreter"
rm -f "$FX/stubs/python"
DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" \
  dot_fixture_run "$FX" tools new node demoproject
assert_equals "1" "$DOT_FIXTURE_RC" "no interpreter at all should exit 1"
assert_contains "python3 is required" "$DOT_FIXTURE_OUT" \
  "the failure should name the missing dependency"

test_start "tools_new_rejects_an_unknown_template"
DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" \
  dot_fixture_run "$FX" tools new node ../escape
assert_equals "1" "$DOT_FIXTURE_RC" "a traversal-shaped project name should be refused"

# ── 4. dot env needs mise ──────────────────────────────────────────────────
test_start "tools_env_requires_mise"
tools_run env
assert_equals "1" "$DOT_FIXTURE_RC" "env without mise should exit 1"
assert_contains "mise not installed" "$DOT_FIXTURE_OUT" \
  "the failure should name the missing tool"

test_start "tools_env_lists_without_jq"
dot_fixture_stub "$FX/stubs" mise 0
tools_run env list
assert_equals "0" "$DOT_FIXTURE_RC" "env list should exit 0"
assert_contains "mise ls" "$DOT_FIXTURE_OUT" \
  "with no jq on PATH the plain mise listing should be used"

# ── 5. dot profile ─────────────────────────────────────────────────────────
test_start "tools_profile_requires_chezmoidata"
tools_run profile
assert_equals "1" "$DOT_FIXTURE_RC" "profile without the data file should exit 1"
assert_contains ".chezmoidata.toml not found" "$DOT_FIXTURE_OUT" \
  "the failure should name the file"

test_start "tools_profile_set_requires_a_name"
printf 'dotfiles_version = "0.0.1"\n\n[features]\nai = true\n' \
  >"$FX/.chezmoidata.toml"
tools_run profile set
assert_equals "1" "$DOT_FIXTURE_RC" "profile set with no name should exit 1"
assert_contains "Usage: dot profile set" "$DOT_FIXTURE_OUT" "it should print usage"

test_start "tools_profile_rejects_an_unknown_subcommand"
tools_run profile nonsense
assert_equals "1" "$DOT_FIXTURE_RC" "an unknown profile subcommand should exit 1"

# A data file with no `profile` key takes the insert arm of `profile set`
# rather than the substitute arm.
#
# That arm uses sed's `1a text` one-liner, which GNU sed accepts and BSD sed
# rejects, so the outcome is genuinely platform-dependent. The invariant that
# holds on both — and the one worth asserting — is that the command never
# reports success without having written the key.
test_start "tools_profile_set_inserts_a_missing_key"
tools_run profile set demo
if grep -q 'profile = "demo"' "$FX/.chezmoidata.toml"; then
  assert_equals "0" "$DOT_FIXTURE_RC" \
    "an insert that succeeded should exit 0"
else
  assert_not_equals "0" "$DOT_FIXTURE_RC" \
    "an insert sed refused must fail loudly, not report success"
fi

test_start "tools_profile_show_reads_the_feature_table"
printf 'profile = "demo"\ndotfiles_version = "0.0.1"\n\n[features]\nai = true\n' \
  >"$FX/.chezmoidata.toml"
tools_run profile show
assert_equals "0" "$DOT_FIXTURE_RC" "profile show should exit 0"
assert_contains "ai" "$DOT_FIXTURE_OUT" "the feature flags should be listed"

test_start "tools_profile_set_substitutes_an_existing_key"
tools_run profile set other
assert_equals "0" "$DOT_FIXTURE_RC" "profile set should exit 0"
assert_file_contains "$FX/.chezmoidata.toml" 'profile = "other"' \
  "the existing profile key should be rewritten in place"

# ── 6. lint delegates to its own module ────────────────────────────────────
#
# The fixture deliberately has no lint.sh, so the delegation is observed
# without running the repo-wide linter.
test_start "tools_lint_delegates_to_the_lint_module"
rm -f "$FX/scripts/dot/commands/lint.sh"
tools_run lint
assert_not_equals "0" "$DOT_FIXTURE_RC" \
  "delegating to an absent lint module should not report success"

test_start "tools_rejects_an_unknown_subcommand"
tools_run definitely-not-a-command
assert_equals "1" "$DOT_FIXTURE_RC" "an unknown tools command should exit 1"
assert_contains "Unknown tools command" "$DOT_FIXTURE_OUT" "it should say so"

print_summary
