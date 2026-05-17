#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# Test: scripts/dot/commands/env-emit.sh (the `dot env emit` handler).
#
# Verifies the v1 manifest emitter is syntactically valid, that the
# dispatch arm in tools.sh wires it up, and that the env-emit module
# defines the expected dot_env_emit() function.

set -euo pipefail

REPO_ROOT="${REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
ENV_EMIT="$REPO_ROOT/scripts/dot/commands/env-emit.sh"
TOOLS="$REPO_ROOT/scripts/dot/commands/tools.sh"

TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

_pass() { TESTS_RUN=$((TESTS_RUN + 1)); TESTS_PASSED=$((TESTS_PASSED + 1)); printf '  ✓ %s\n' "$1"; }
_fail() { TESTS_RUN=$((TESTS_RUN + 1)); TESTS_FAILED=$((TESTS_FAILED + 1)); printf '  ✗ %s — %s\n' "$1" "$2"; }

[[ -f "$ENV_EMIT" ]] || { _fail "env_emit_exists" "not found"; printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"; exit 1; }
_pass "env_emit_exists"

if bash -n "$ENV_EMIT" 2>/dev/null; then
  _pass "env_emit_syntax_valid"
else
  _fail "env_emit_syntax_valid" "bash -n failed"
fi

if grep -q '^dot_env_emit()' "$ENV_EMIT"; then
  _pass "exports_dot_env_emit_function"
else
  _fail "exports_dot_env_emit_function" "function not found"
fi

if grep -q '^\s*"emit"' "$TOOLS" || grep -q 'emit"' "$TOOLS"; then
  _pass "dispatched_via_tools_sh"
else
  _fail "dispatched_via_tools_sh" "emit case-arm not found"
fi

if [[ -f "$REPO_ROOT/docs/schema/dot-env-v1.json" ]]; then
  _pass "v1_schema_present"
else
  _fail "v1_schema_present" "docs/schema/dot-env-v1.json missing"
fi

if [[ -f "$REPO_ROOT/docs/operations/MANIFEST.md" ]]; then
  _pass "manifest_doc_present"
else
  _fail "manifest_doc_present" "docs/operations/MANIFEST.md missing"
fi

printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
