#!/usr/bin/env bash
# Copyright (c) 2015-2026 Dotfiles. All rights reserved.
## Package tracked governance artifacts into a release bundle.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../.." && pwd)}"

OUTPUT_DIR="${OUTPUT_DIR:-$REPO_ROOT/dist/policy-bundles}"
BUNDLE_VERSION="${BUNDLE_VERSION:-$(jq -r '.schemaVersion' "$REPO_ROOT/dot_config/dotfiles/policy-bundles.json")}"
JSON_MODE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --output-dir | -o)
      OUTPUT_DIR="${2:-}"
      shift 2
      ;;
    --version | -v)
      BUNDLE_VERSION="${2:-}"
      shift 2
      ;;
    --json | -j)
      JSON_MODE=1
      shift
      ;;
    *)
      shift
      ;;
  esac
done

command -v jq >/dev/null 2>&1 || {
  echo "jq is required for policy bundle packaging." >&2
  exit 1
}

bundle_root="$OUTPUT_DIR/policy-bundles-$BUNDLE_VERSION"
archive_file="$OUTPUT_DIR/policy-bundles-$BUNDLE_VERSION.tar.gz"
checksum_file="$OUTPUT_DIR/policy-bundles-$BUNDLE_VERSION.sha256"

rm -rf "$bundle_root"
mkdir -p "$bundle_root/dot_config/dotfiles" "$bundle_root/.well-known" "$bundle_root/docs/security" "$bundle_root/docs/operations" "$bundle_root/docs/interop"

files=(
  "dot_config/dotfiles/policy-bundles.json"
  "dot_config/dotfiles/model-registry.json"
  "dot_config/dotfiles/prompt-registry.json"
  "dot_config/dotfiles/agent-profiles.json"
  "dot_config/dotfiles/agent-card.json"
  "dot_config/dotfiles/mcp-policy.json"
  "dot_config/dotfiles/mcp-registry.json"
  "dot_config/dotfiles/mcp-lock.json"
  ".well-known/agent.json"
  ".well-known/agent-card.json"
  ".well-known/mcp/server-card.json"
  "docs/security/MCP_POLICY.md"
  "docs/operations/TRUSTED_AGENT_WORKSTATION.md"
  "docs/interop/A2A.md"
)

for file in "${files[@]}"; do
  [[ -f "$REPO_ROOT/$file" ]] || {
    echo "Missing required policy bundle artifact: $file" >&2
    exit 1
  }
  mkdir -p "$bundle_root/$(dirname "$file")"
  cp "$REPO_ROOT/$file" "$bundle_root/$file"
done

jq empty "$bundle_root/dot_config/dotfiles/policy-bundles.json" >/dev/null
jq empty "$bundle_root/dot_config/dotfiles/model-registry.json" >/dev/null
jq empty "$bundle_root/dot_config/dotfiles/prompt-registry.json" >/dev/null
jq empty "$bundle_root/dot_config/dotfiles/agent-profiles.json" >/dev/null
jq empty "$bundle_root/dot_config/dotfiles/agent-card.json" >/dev/null
jq empty "$bundle_root/dot_config/dotfiles/mcp-policy.json" >/dev/null
jq empty "$bundle_root/dot_config/dotfiles/mcp-registry.json" >/dev/null
jq empty "$bundle_root/dot_config/dotfiles/mcp-lock.json" >/dev/null
jq empty "$bundle_root/.well-known/agent.json" >/dev/null

tar -C "$OUTPUT_DIR" -czf "$archive_file" "policy-bundles-$BUNDLE_VERSION"
sha256sum "$archive_file" >"$checksum_file"

# Generate CycloneDX SBOM
sbom_file="$bundle_root/sbom.cyclonedx.json"
if command -v syft >/dev/null 2>&1; then
  syft dir:"$bundle_root" -o cyclonedx-json >"$sbom_file" 2>/dev/null
else
  # Minimal CycloneDX manifest via jq
  jq -n \
    --arg version "$BUNDLE_VERSION" \
    --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    '{
      bomFormat: "CycloneDX",
      specVersion: "1.5",
      version: 1,
      metadata: {
        timestamp: $timestamp,
        component: {
          type: "application",
          name: "dotfiles-policy-bundles",
          version: $version
        }
      },
      components: []
    }' >"$sbom_file"
fi

# Re-create archive with SBOM included
tar -C "$OUTPUT_DIR" -czf "$archive_file" "policy-bundles-$BUNDLE_VERSION"
sha256sum "$archive_file" >"$checksum_file"

if [[ "$JSON_MODE" -eq 1 ]]; then
  jq -n \
    --arg version "$BUNDLE_VERSION" \
    --arg output_dir "$OUTPUT_DIR" \
    --arg archive "$archive_file" \
    --arg checksum "$checksum_file" \
    --arg sbom "$sbom_file" \
    '{version: $version, output_dir: $output_dir, archive: $archive, checksum: $checksum, sbom: $sbom}'
else
  printf 'Policy bundle archive: %s\n' "$archive_file"
  printf 'Policy bundle checksum: %s\n' "$checksum_file"
fi
