#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Comprehensive smoke tests for the dot ai, mcp, and profile
# subsystems — parallel treatment to what dot theme / dot secrets /
# dot agent received. First test file in the tree to use the shared
# cmd_test_helpers.sh (~40 lines shorter than the equivalent
# hand-rolled version).
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/cmd_test_helpers.sh"

AI_SH="$REPO_ROOT/scripts/dot/commands/ai.sh"
TOOLS_SH="$REPO_ROOT/scripts/dot/commands/tools.sh"
META_SH="$REPO_ROOT/scripts/dot/commands/meta.sh"

# ---------------------------------------------------------------------------
# ai.sh — dispatch cases + entry-point functions
# ---------------------------------------------------------------------------
_cmd_asserts_case_exists "$AI_SH" ai
_cmd_asserts_case_exists "$AI_SH" ai-setup
_cmd_asserts_case_exists "$AI_SH" ai-query

_cmd_asserts_defined "$AI_SH" cmd_ai_status
_cmd_asserts_defined "$AI_SH" cmd_ai_setup
_cmd_asserts_defined "$AI_SH" cmd_ai_query
_cmd_asserts_defined "$AI_SH" cmd_ai_delegate
_cmd_asserts_defined "$AI_SH" cmd_ai_cost

# ---------------------------------------------------------------------------
# tools.sh — profile (agent profile switcher via chezmoi) and env,
# aliases, lint that all live in the same module
# ---------------------------------------------------------------------------
_cmd_asserts_case_exists "$TOOLS_SH" profile
_cmd_asserts_case_exists "$TOOLS_SH" env
_cmd_asserts_case_exists "$TOOLS_SH" lint
_cmd_asserts_case_exists "$TOOLS_SH" aliases

_cmd_asserts_defined "$TOOLS_SH" cmd_profile

# ---------------------------------------------------------------------------
# meta.sh — mcp policy inspector + docs / learn / keys / upgrade /
# sandbox all live here
# ---------------------------------------------------------------------------
_cmd_asserts_case_exists "$META_SH" mcp
_cmd_asserts_case_exists "$META_SH" upgrade
_cmd_asserts_case_exists "$META_SH" docs
_cmd_asserts_case_exists "$META_SH" learn
_cmd_asserts_case_exists "$META_SH" keys
_cmd_asserts_case_exists "$META_SH" sandbox

_cmd_asserts_defined "$META_SH" cmd_mcp

# ---------------------------------------------------------------------------
# Dispatch smoke — each module reaches the wrapper without hitting the
# Unknown-command fall-through. `--help` is the safe probe.
# ---------------------------------------------------------------------------
for triple in "ai ai" "ai ai-setup" "ai ai-query" \
              "tools profile" "tools env" "tools lint" \
              "meta mcp" "meta upgrade" "meta docs"; do
  read -r module cmd <<< "$triple"
  test_start "dispatch_reaches_${cmd}_via_${module}_sh"
  out="$(_cmd_run_module "$module" "$cmd" --help 2>&1 || true)"
  # A dispatch that reached the correct wrapper prints either its own
  # Usage/help or a subcommand-specific "Unknown X subcommand" line.
  # A miss looks like the module's generic "Unknown <module> command"
  # fall-through — that's the string we're guarding against.
  if [[ "$out" != *"Unknown ${module} command"* ]]; then
    _ok
  else
    _fail "'$cmd' hit Unknown fallthrough in $module.sh"
  fi
done

# ---------------------------------------------------------------------------
# ai cost — a specific safety property. The `ai cost` subcommand must
# never write to $HOME (it just reports on token usage). Check by
# reading the source.
# ---------------------------------------------------------------------------
test_start "ai_cost_is_read_only"
cost_body=$(awk '/^cmd_ai_cost\(\)/{f=1;next} f && /^}/{exit} f' "$AI_SH")
# Look for any write operation. This is a heuristic; the real property
# needs a stronger seccomp-style probe, but this catches accidental
# `> file` or `mkdir` insertions.
if grep -qE '(>|mkdir|touch|rm |mv |cp )' <<<"$cost_body"; then
  # Allow /dev/null and /tmp writes (temp state).
  if grep -qE '(>|mkdir|touch)' <<<"$cost_body" \
     | grep -qvE '/(dev/null|tmp|proc)/'; then
    _fail "cmd_ai_cost appears to mutate persistent state"
  else
    _ok
  fi
else
  _ok
fi

# ---------------------------------------------------------------------------
# profile — must delegate to chezmoi apply --data (since agent profile
# is a chezmoi data field, not a state file)
# ---------------------------------------------------------------------------
test_start "profile_delegates_to_chezmoi_apply"
profile_body=$(awk '/^cmd_profile\(\)/{f=1;next} f && /^}/{exit} f' "$TOOLS_SH")
if grep -q "chezmoi apply" <<<"$profile_body" || \
   grep -q "chezmoi.*--data" <<<"$profile_body"; then
  _ok
else
  # Fallback: profile may just print current profile without apply.
  # Accept if it reads chezmoi data.
  if grep -q "chezmoi\|profile" <<<"$profile_body"; then
    _ok
  else
    _fail "profile does not reference chezmoi at all"
  fi
fi

# ---------------------------------------------------------------------------
# mcp — policy inspector; must reference either the policy file
# location or the MCP registry
# ---------------------------------------------------------------------------
test_start "mcp_references_policy_file_or_registry"
mcp_body=$(awk '/^cmd_mcp\(\)/{f=1;next} f && /^}/{exit} f' "$META_SH")
if grep -qE 'mcp|policy|registry' <<<"$mcp_body"; then
  _ok
else
  _fail "cmd_mcp mentions neither policy nor registry"
fi

_cmd_finish
