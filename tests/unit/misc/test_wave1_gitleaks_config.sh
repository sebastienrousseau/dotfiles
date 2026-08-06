#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Unit tests for Wave 1: gitleaks configuration
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

GITLEAKS_CONF="$REPO_ROOT/config/gitleaks.toml"
GITLEAKS_ENTRYPOINT="$REPO_ROOT/.gitleaks.toml"
GITLEAKS_IGNORE="$REPO_ROOT/.gitleaksignore"

echo "Testing Wave 1: gitleaks configuration..."

test_start "gitleaks_config_exists"
assert_file_exists "$GITLEAKS_CONF" ".gitleaks.toml should exist"

test_start "gitleaks_root_entrypoint_exists"
assert_file_exists "$GITLEAKS_ENTRYPOINT" "hosted scanners should discover a root .gitleaks.toml"

test_start "gitleaks_root_entrypoint_is_canonical"
assert_equals "config/gitleaks.toml" "$(readlink "$GITLEAKS_ENTRYPOINT")" \
  "root .gitleaks.toml should resolve to the canonical config"

test_start "gitleaks_history_exception_is_exact"
assert_file_contains "$GITLEAKS_IGNORE" \
  "5d64f60abe98b2df3a0550c5d8a74b28cd01731e:install/provision/run_onchange_10-linux-packages.sh.tmpl:generic-api-key:90" \
  "historical checksum exception should be scoped to one finding"

test_start "gitleaks_extends_default"
assert_file_contains "$GITLEAKS_CONF" "useDefault = true" "should extend default gitleaks config"

test_start "gitleaks_has_allowlist"
assert_file_contains "$GITLEAKS_CONF" "[allowlist]" "should have allowlist section"

test_start "gitleaks_allows_gpg_key"
assert_file_contains "$GITLEAKS_CONF" "CHEZMOI_GPG_KEY=" "should allowlist GPG key variable"

test_start "gitleaks_has_path_ignores"
assert_file_contains "$GITLEAKS_CONF" "paths = [" "should have path-based ignores"

test_start "gitleaks_ignores_docs"
assert_file_contains "$GITLEAKS_CONF" "docs/" "should ignore docs directory"

test_start "gitleaks_has_commit_allowlist"
assert_file_contains "$GITLEAKS_CONF" "commits = [" "should have commit allowlist"

test_start "gitleaks_has_stopwords"
assert_file_contains "$GITLEAKS_CONF" "stopwords = [" "should have stopwords list"

test_start "gitleaks_has_custom_rules"
assert_file_contains "$GITLEAKS_CONF" "[[rules]]" "should define custom detection rules"

test_start "gitleaks_aws_rule"
assert_file_contains "$GITLEAKS_CONF" "aws-session-token" "should detect AWS session tokens"

test_start "gitleaks_gcp_rule"
assert_file_contains "$GITLEAKS_CONF" "gcp-api-key" "should detect GCP API keys"

test_start "gitleaks_azure_rule"
assert_file_contains "$GITLEAKS_CONF" "azure-connection-string" "should detect Azure connection strings"

echo ""
echo "Wave 1 gitleaks configuration tests completed."
print_summary
