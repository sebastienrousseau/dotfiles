#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for the Atuin history_filter patterns shipped under chezmoi.
#
# Validates:
#   1. Required source files exist (template + chezmoidata).
#   2. Each default pattern actually catches a representative leaked command.
#   3. None of the patterns matches a benign command.
#
# Regression for: GH-872

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
# shellcheck source=../../framework/assertions.sh
source "$SCRIPT_DIR/../../framework/assertions.sh"

TEMPLATE_FILE="$REPO_ROOT/dot_config/atuin/config.toml.tmpl"
DATA_FILE="$REPO_ROOT/.chezmoidata/secrets-patterns.toml"

# -----------------------------------------------------------------------------
# Structural checks
# -----------------------------------------------------------------------------

test_start "template_file_exists"
assert_file_exists "$TEMPLATE_FILE" "Atuin config template should exist"

test_start "data_file_exists"
assert_file_exists "$DATA_FILE" "secrets-patterns chezmoidata file should exist"

test_start "template_references_data"
assert_file_contains "$TEMPLATE_FILE" ".atuin.history_filter.defaults" \
  "template must source defaults from chezmoidata"

test_start "template_supports_extra"
assert_file_contains "$TEMPLATE_FILE" ".atuin.history_filter.extra" \
  "template must support per-host extra patterns"

test_start "data_has_defaults_array"
assert_file_contains "$DATA_FILE" "defaults = [" \
  "secrets-patterns.toml must define the defaults array"

# -----------------------------------------------------------------------------
# Pattern-coverage checks: each leaked-command fixture must match at least
# one pattern in the defaults block. Each benign fixture must match none.
# -----------------------------------------------------------------------------

extract_defaults() {
  # Cheap parser: pull the contents of `defaults = [ ... ]` from the TOML.
  awk '
    /^defaults *= *\[/ { inside = 1; next }
    inside && /^\]/    { inside = 0 }
    inside             { gsub(/^[[:space:]]*"/, ""); gsub(/",?[[:space:]]*$/, ""); print }
  ' "$DATA_FILE"
}

matches_any_pattern() {
  local line="$1"
  while IFS= read -r pattern; do
    [[ -z "$pattern" ]] && continue
    if printf '%s\n' "$line" | LC_ALL=C grep -Eq -- "$pattern"; then
      return 0
    fi
  done < <(extract_defaults)
  return 1
}

LEAKED_FIXTURES=(
  "export AWS_SECRET_ACCESS_KEY=ASIA1234567890ABCDEF"
  "export ANTHROPIC_API_KEY=sk-ant-api03-AAAA"
  "PASSWORD=hunter2 ./deploy.sh"
  "aws configure set aws_secret_access_key wxyz"
  "gcloud auth login --no-launch-browser"
  "kubectl --kubeconfig=/tmp/k get pods"
  "curl -H 'Authorization: Bearer eyJhbGc...' https://api"
  "git clone https://user:tokenABC@github.com/org/repo.git"
  "vault read secret/prod/db"
  "op read 'op://Vault/Item/credential'"
  "ssh-keygen -t ed25519 -C 'me@host'"
  "psql postgres://admin:p4ss@db.internal:5432/main"
  "GH_TOKEN=ghp_xxx gh auth status"
)

BENIGN_FIXTURES=(
  "ls -la"
  "cd ~/projects"
  "git status"
  "cargo build --release"
  "echo hello"
  "chezmoi diff"
  "dot doctor"
  "curl https://example.com"
  "ssh me@server"  # ssh (not ssh-keygen / ssh-add) is fine
)

for fixture in "${LEAKED_FIXTURES[@]}"; do
  test_start "leaked_caught: ${fixture:0:40}"
  if matches_any_pattern "$fixture"; then
    assert_exit_code 0 "true"  # passes
  else
    assert_exit_code 0 "false  # No pattern matched: $fixture"
  fi
done

for fixture in "${BENIGN_FIXTURES[@]}"; do
  test_start "benign_passes: ${fixture:0:40}"
  if matches_any_pattern "$fixture"; then
    assert_exit_code 0 "false  # Pattern wrongly matched benign command: $fixture"
  else
    assert_exit_code 0 "true"  # passes
  fi
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
