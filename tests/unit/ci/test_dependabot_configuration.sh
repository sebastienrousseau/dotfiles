#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

DEPENDABOT_CONFIG="$REPO_ROOT/.github/dependabot.yml"
docker_block="$(awk '
  /package-ecosystem: "docker"/ { capture = 1 }
  capture && /package-ecosystem:/ && $0 !~ /package-ecosystem: "docker"/ { exit }
  capture { print }
' "$DEPENDABOT_CONFIG")"

test_start "dependabot_docker_uses_manifest_directories"
if grep -Fqx '    directory: "/"' <<<"$docker_block"; then
  assert_equals "non-root Docker scope" "root Docker scope" \
    "Docker updates must not target the manifest-free repository root"
else
  assert_equals "non-root Docker scope" "non-root Docker scope" \
    "Docker updates avoid the manifest-free repository root"
fi

test_start "dependabot_docker_covers_devcontainer"
assert_output_contains '      - "/.devcontainer"' "printf '%s\n' \"\$docker_block\""

test_start "dependabot_devcontainer_scope_has_manifest"
assert_file_exists "$REPO_ROOT/.devcontainer/Dockerfile" \
  "the configured devcontainer scope contains a Dockerfile"

test_start "dependabot_docker_covers_fuzz_image"
assert_output_contains '      - "/fuzz/oss-fuzz"' "printf '%s\n' \"\$docker_block\""

test_start "dependabot_fuzz_scope_has_manifest"
assert_file_exists "$REPO_ROOT/fuzz/oss-fuzz/Dockerfile" \
  "the configured fuzz scope contains a Dockerfile"

test_start "dependabot_docker_covers_test_images"
assert_output_contains '      - "/tests"' "printf '%s\n' \"\$docker_block\""

test_start "dependabot_test_scope_has_manifest"
assert_file_exists "$REPO_ROOT/tests/Dockerfile.test" \
  "the configured test scope contains a Dockerfile"

test_start "dependabot_preserves_ubuntu_platform_contracts"
ubuntu_policy='      - dependency-name: "ubuntu"
        update-types:
          - "version-update:semver-major"
          - "version-update:semver-minor"'
assert_output_contains "$ubuntu_policy" "printf '%s\n' \"\$docker_block\""

test_start "sandbox_keeps_ubuntu_lts_contract"
assert_file_contains "$REPO_ROOT/tests/Dockerfile.sandbox" "FROM ubuntu:24.04@sha256:" \
  "the sandbox remains on its declared Ubuntu 24.04 LTS release"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
