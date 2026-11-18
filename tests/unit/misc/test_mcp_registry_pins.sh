#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural
# shellcheck disable=SC1090,SC1091
# The MCP registry attests the first-party servers by version
# (github.com/<owner>/<repo>@vX.Y.Z), and mise installs them from the pins in
# conf.d/00-dotfiles.toml. The attestation went stale (corralctl v0.0.18
# attested while 0.0.54 ran; passmcp-server v0.0.7 against 0.0.10): every
# github.com package in the registry must name the version mise pins. The
# archived mcp-server-sqlite must not come back as a default server.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

REGISTRY="$REPO_ROOT/defaults/dot_config/dotfiles/mcp-registry.json"
MISE="$REPO_ROOT/defaults/dot_config/mise/conf.d/00-dotfiles.toml"

test_start "mcp_registry_github_packages_match_mise_pins"
pkgs="$(jq -r '.servers[].package // empty | select(startswith("github.com/"))' "$REGISTRY")"
assert_not_empty "$pkgs" "the registry attests github.com packages"
for pkg in $pkgs; do
  repo="${pkg#github.com/}"
  repo="${repo%@*}"
  want="$(sed -nE "s|^\"github:${repo}\" = \"([^\"]+)\".*|\\1|p" "$MISE")"
  assert_equals "v$want" "${pkg##*@}" "$repo: registry attests the pinned version"
done

test_start "archived_sqlite_server_is_not_a_default"
for f in "$REPO_ROOT/defaults/dot_config/claude/mcp_servers.json" "$REGISTRY" \
  "$REPO_ROOT/defaults/dot_config/dotfiles/mcp-lock.json"; do
  assert_false "grep -q 'mcp-server-sqlite' '$f'" "${f#"$REPO_ROOT"/} has no mcp-server-sqlite"
done

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
