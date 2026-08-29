#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Test: scripts/dot/commands/env-emit.sh (the `dot env emit` handler).
#
# Verifies the v1 manifest emitter is syntactically valid, that the
# dispatch arm in tools.sh wires it up, and that the env-emit module
# defines the expected dot_env_emit() function.
# shellcheck disable=SC1090,SC1091,SC2034

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/cmd_test_helpers.sh"

ENV_EMIT="$REPO_ROOT/scripts/dot/commands/env-emit.sh"
TOOLS="$REPO_ROOT/scripts/dot/commands/tools.sh"

if [[ -f "$ENV_EMIT" ]]; then
  _pass "env_emit_exists"
else
  _fail_named "env_emit_exists" "not found"
  _cmd_finish
  exit 1
fi

if bash -n "$ENV_EMIT" 2>/dev/null; then
  _pass "env_emit_syntax_valid"
else
  _fail_named "env_emit_syntax_valid" "bash -n failed"
fi

if grep -q '^dot_env_emit()' "$ENV_EMIT"; then
  _pass "exports_dot_env_emit_function"
else
  _fail_named "exports_dot_env_emit_function" "function not found"
fi

if grep -q '^\s*"emit"' "$TOOLS" || grep -q 'emit"' "$TOOLS"; then
  _pass "dispatched_via_tools_sh"
else
  _fail_named "dispatched_via_tools_sh" "emit case-arm not found"
fi

if [[ -f "$REPO_ROOT/docs/schema/dot-env-v1.json" ]]; then
  _pass "v1_schema_present"
else
  _fail_named "v1_schema_present" "docs/schema/dot-env-v1.json missing"
fi

if [[ -f "$REPO_ROOT/docs/operations/MANIFEST.md" ]]; then
  _pass "manifest_doc_present"
else
  _fail_named "manifest_doc_present" "docs/operations/MANIFEST.md missing"
fi

_cmd_finish
