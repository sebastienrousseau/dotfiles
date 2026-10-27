#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091
# Runs tools.sh for three behaviours the core mutation run found untested:
# the feature-flag list ends at the next [table] header (and only there), a
# new project always gets the security workflow, and a bare call is a usage
# error.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

TOOLS="$REPO_ROOT/scripts/dot/commands/tools.sh"
TOOL="$REPO_ROOT/plugins/tool/libexec/tool.sh"
WORK="$(mktemp -d -t dot-tools-pnu.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

# tools.sh resolves its source tree from its own directory, so a fixture tree
# with a copied lib/ and linked scripts reads the fixture's .chezmoidata.toml.
FIX="$WORK/src"
mkdir -p "$FIX/scripts/dot/commands"
cp -R "$REPO_ROOT/lib" "$FIX/lib"
ln -s "$TOOLS" "$FIX/scripts/dot/commands/tools.sh"
ln -s "$REPO_ROOT/scripts/dot/commands/aliases.sh" "$FIX/scripts/dot/commands/aliases.sh"
cat >"$FIX/.chezmoidata.toml" <<'TOML'
profile = "work"

[features]
zellij = true # [beta]
nvim = false

[other]
stray = 1
TOML

test_start "profile_show_lists_flags_past_a_bracket_in_a_value"
out="$(NO_COLOR=1 bash "$FIX/scripts/dot/commands/tools.sh" profile show 2>&1)"
assert_contains "nvim" "$out" "a '[' inside a line is not the next table header"

test_start "profile_show_stops_at_the_next_table"
assert_output_not_contains "stray" 'printf "%s" "$out"'

test_start "new_project_gets_the_security_workflow"
mkdir -p "$WORK/projects"
(cd "$WORK/projects" && NO_COLOR=1 bash "$TOOL" new packer demo >/dev/null 2>&1)
assert_file_contains "$WORK/projects/demo/.github/workflows/security.yml" \
  "name: Security Baseline" "dot tool new writes the security workflow"

test_start "bare_call_is_a_usage_error"
rc=0
out="$(bash "$TOOLS" 2>&1)" || rc=$?
assert_equals "1" "$rc" "tools.sh with no command exits 1"
assert_contains "Usage: tools.sh <command>" "$out" "and prints its usage"

test_summary
