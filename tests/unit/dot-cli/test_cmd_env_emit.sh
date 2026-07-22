#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
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

_pass() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_PASSED=$((TESTS_PASSED + 1))
  printf '  ✓ %s\n' "$1"
}
_fail() {
  TESTS_RUN=$((TESTS_RUN + 1))
  TESTS_FAILED=$((TESTS_FAILED + 1))
  printf '  ✗ %s — %s\n' "$1" "$2"
}

[[ -f "$ENV_EMIT" ]] || {
  _fail "env_emit_exists" "not found"
  printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
  exit 1
}
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

tmp="${DOTFILES_COV_TMPDIR:-${TMPDIR:-/tmp}/env-emit-test.$$}"
mkdir -p "$tmp/bin" "$tmp/repo/defaults"
cat >"$tmp/repo/defaults/.chezmoidata.toml" <<'EOF_DATA'
dotfiles_version = "0.0.0-test"
EOF_DATA
cat >"$tmp/bin/mise" <<'EOF_MISE'
#!/usr/bin/env bash
if [[ -n "${DOTFILES_FAKE_MISE_FAIL:-}" ]]; then
  exit 42
fi
cat <<'JSON'
{
  "node": [
    {
      "version": "22.0.0",
      "source": {"path": "mise.toml", "type": "mise"},
      "requested_version": "22",
      "install_path": "/tmp/node",
      "active": true
    }
  ],
  "python": [
    {
      "version": "3.13.0",
      "source": {},
      "requested_version": "latest",
      "active": false
    }
  ]
}
JSON
EOF_MISE
chmod +x "$tmp/bin/mise"

deep_out="$(
  set +e
  export PATH="$tmp/bin:$PATH"
  # shellcheck disable=SC1091
  source "$REPO_ROOT/lib/dot/utils.sh"
  _DOT_SOURCE_DIR_CACHE="$tmp/repo"
  # shellcheck disable=SC1090
  source "$ENV_EMIT"
  set +e
  dot_env_emit --help
  dot_env_emit --format json --pretty
  dot_env_emit --format=json --compact
  dot_env_emit --format ndjson
  dot_env_emit --output "$tmp/env.json"
  dot_env_emit --output="$tmp/env-compact.json" --compact
  dot_env_emit --format yaml
  dot_env_emit --unknown
  PATH="/usr/bin:/bin" dot_env_emit
  DOTFILES_FAKE_MISE_FAIL=1 dot_env_emit
  true
)"
if [[ "$deep_out" == *"dot env emit"* ]] && [[ -f "$tmp/env.json" ]] && [[ -f "$tmp/env-compact.json" ]]; then
  _pass "env_emit_deep_branches"
else
  _fail "env_emit_deep_branches" "expected help output and sandbox manifest files"
fi

printf 'RESULTS:%d:%d:%d\n' "$TESTS_RUN" "$TESTS_PASSED" "$TESTS_FAILED"
exit "$TESTS_FAILED"
