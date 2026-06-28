#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
#
# Release-signing contract. Locks the supply-chain guarantees for releases so
# they cannot silently regress:
#   1. security-release.yml — Cosign keyless (Fulcio + Rekor) signing of the
#      SBOM and a SHA256SUMS manifest over every release asset.
#   2. release-package-dot.yml — SLSA build-provenance attestation of the
#      release artefacts (tarball + zip) via OIDC.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

SEC="$REPO_ROOT/.github/workflows/security-release.yml"
PKG="$REPO_ROOT/.github/workflows/release-package-dot.yml"

# ── 1. Cosign keyless signing of SBOM + asset manifest ──────────────────────
test_start "release_signing_cosign_present"
assert_file_exists "$SEC" "security-release workflow exists"
assert_file_contains "$SEC" "sigstore/cosign-installer" "installs Cosign"
assert_file_contains "$SEC" "cosign sign-blob --yes" "keyless sign-blob (no key material)"
assert_file_contains "$SEC" "id-token: write" "OIDC token for keyless signing"

test_start "release_signing_asset_manifest"
assert_file_contains "$SEC" "ALL_SHA256SUMS" "builds a SHA256SUMS manifest over release assets"

# ── 2. SLSA build provenance for the release artefacts ──────────────────────
test_start "release_provenance_attestation"
assert_file_exists "$PKG" "release-package workflow exists"
assert_file_contains "$PKG" "actions/attest-build-provenance" "attests build provenance"
assert_file_contains "$PKG" "attestations: write" "has attestations:write permission"
assert_file_contains "$PKG" "id-token: write" "has OIDC token for keyless attestation"
assert_file_contains "$PKG" "subject-path:" "attests the built artefacts"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
