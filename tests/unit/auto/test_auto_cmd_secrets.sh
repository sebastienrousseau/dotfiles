#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Auto-generated function-exercise test for scripts/dot/commands/secrets.sh.
# AUTO-GENERATED: true

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/scripts/dot/commands/secrets.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/dot/commands/secrets.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "secrets_deep_branches_execute"
secrets_tmp="$DOTFILES_COV_TMPDIR/secrets-deep"
mkdir -p "$secrets_tmp/repo/defaults" "$secrets_tmp/bin" "$secrets_tmp/home"
cat >"$secrets_tmp/repo/defaults/.chezmoidata.toml" <<'EOF_DATA'
[secrets.policy]
provider = "pass"
auto_load = true

[secrets.buckets]
ai = ["OPENAI_API_KEY", "ANTHROPIC_API_KEY"]
ops = ["OPS_TOKEN"]
EOF_DATA
cat >"$secrets_tmp/bin/chezmoi" <<'EOF_CHEZMOI'
#!/usr/bin/env bash
case "${1:-}" in
  source-path) printf '%s\n' "$DOTFILES_FAKE_SOURCE/defaults" ;;
  edit) exit 0 ;;
  *) exit 1 ;;
esac
EOF_CHEZMOI
cat >"$secrets_tmp/bin/pass" <<'EOF_PASS'
#!/usr/bin/env bash
case "${1:-}" in
  insert)
    shift
    while [[ "${1:-}" == -* ]]; do shift; done
    key="${1#dotfiles/}"
    mkdir -p "$DOTFILES_FAKE_PASS_STORE"
    cat >"$DOTFILES_FAKE_PASS_STORE/$key"
    ;;
  show)
    key="${2#dotfiles/}"
    if [[ -f "$DOTFILES_FAKE_PASS_STORE/$key" ]]; then
      cat "$DOTFILES_FAKE_PASS_STORE/$key"
    else
      printf 'value-for-%s\n' "$key"
    fi
    ;;
  *) exit 1 ;;
esac
EOF_PASS
chmod +x "$secrets_tmp/bin/chezmoi" "$secrets_tmp/bin/pass"
(
  set +e
  export HOME="$secrets_tmp/home"
  export DOTFILES_FAKE_SOURCE="$secrets_tmp/repo"
  export DOTFILES_FAKE_PASS_STORE="$secrets_tmp/pass-store"
  export DOT_SECRETS_HOME="$secrets_tmp/secrets"
  export DOTFILES_SECRETS_PROVIDER="pass"
  export PATH="$secrets_tmp/bin:$PATH"
  bash "$SCRIPT_FILE" --help
  bash "$SCRIPT_FILE"
  bash "$SCRIPT_FILE" secrets provider
  bash "$SCRIPT_FILE" secrets set OPENAI_API_KEY sk-test
  bash "$SCRIPT_FILE" secrets get OPENAI_API_KEY
  bash "$SCRIPT_FILE" secrets get OPENAI_API_KEY --raw
  bash "$SCRIPT_FILE" secrets list
  bash "$SCRIPT_FILE" secrets load ai
  bash "$SCRIPT_FILE" secrets load ai --shell fish
  bash "$SCRIPT_FILE" secrets load ai --shell nu
  bash "$SCRIPT_FILE" env load ops
  bash "$SCRIPT_FILE" secrets get MISSING_KEY
  bash "$SCRIPT_FILE" secrets load missing
  bash "$SCRIPT_FILE" secrets load ai --shell unknown
  bash "$SCRIPT_FILE" secrets unknown
  bash "$SCRIPT_FILE" env unknown
  bash "$SCRIPT_FILE" unknown-command
) >/dev/null || true
assert_file_contains "$secrets_tmp/secrets/index.txt" \
  "OPENAI_API_KEY" "secrets deep branches indexed stored key"

cov_exercise_functions_file "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
