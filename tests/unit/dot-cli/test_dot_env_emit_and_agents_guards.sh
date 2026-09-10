#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Two argument/precondition guards that a healthy checkout hides.
#
# `dot env emit --output` with nothing after it must be rejected, and
# `dot agents render` must refuse when CLAUDE.md is not where it expects. The
# second is unreachable from the checkout, which always has that file — so it
# runs against a fixture source tree that does not.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"
source "$SCRIPT_DIR/../../framework/module_fixture.sh"

cov_setup_sandbox
trap cov_teardown_sandbox EXIT

FX="$(dot_fixture_new env-agents)"
mkdir -p "$FX/home" "$FX/stubs"
dot_fixture_basebin "$FX/basebin"
dot_fixture_stub "$FX/stubs" mise 0
DOT_FIXTURE_HOME="$FX/home"

fx_run() {
  DOT_FIXTURE_PATH="$FX/stubs:$FX/basebin" dot_fixture_run "$FX" "$@"
}

# ── 1. --output needs a value ──────────────────────────────────────────────
test_start "env_emit_rejects_output_without_a_value"
fx_run tools env emit --output
assert_not_equals "0" "$DOT_FIXTURE_RC" \
  "--output with nothing after it must not be accepted"
assert_contains "--output needs a value" "$DOT_FIXTURE_OUT" \
  "the failure should name the option"

test_start "env_emit_rejects_format_without_a_value"
fx_run tools env emit --format
assert_not_equals "0" "$DOT_FIXTURE_RC" \
  "--format with nothing after it must not be accepted"

# ── 2. agents render needs its canonical document ──────────────────────────
#
# agents.sh is a library — it defines cmd_agents and leaves the dispatch to
# bin/dot — so it is sourced by its relative path from inside the fixture and
# called directly. The fixture carries the .chezmoidata.toml that
# _agents_repo_root insists on, but no CLAUDE.md.
printf 'dotfiles_version = "0.0.1"\n' >"$FX/.chezmoidata.toml"
mkdir -p "$FX/defaults"
printf 'dotfiles_version = "0.0.1"\n' >"$FX/defaults/.chezmoidata.toml"

test_start "agents_render_requires_claude_md"
AG_RC=0
AG_OUT="$(
  cd "$FX" &&
    HOME="$FX/home" PATH="$FX/stubs:$FX/basebin" NO_COLOR=1 DOTFILES_SHOW_LOGO=0 \
      "${BASH:-bash}" -c '
        source scripts/dot/commands/agents.sh
        rc=0
        cmd_agents render || rc=$?
        printf "AGENTS_RC=%s\\n" "$rc"
      ' 2>&1 </dev/null
)" || AG_RC=$?
assert_contains "AGENTS_RC=2" "$AG_OUT" "a missing CLAUDE.md should return 2"
assert_contains "not found at" "$AG_OUT" \
  "the failure should name the path it looked in"

print_summary
