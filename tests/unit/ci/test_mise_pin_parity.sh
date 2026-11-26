#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# test-kind: structural
# shellcheck disable=SC1091
# One mise pin. Users get the mise in defaults/dot_config/dotfiles/versions.env
# (the Linux provisioner, and lib/dot/preflight.sh's fallback); CI tests the
# deployed mise config with the one in .github/actions/mise-toolchain. They
# drifted: CI ran 2026.11.6 while users got 2026.3.8, which could not parse
# the shipped config, so every tool provisioned through mise failed and CI
# never saw it (drill A1). They must name the same release and checksum.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

VERSIONS="$REPO_ROOT/defaults/dot_config/dotfiles/versions.env"
ACTION="$REPO_ROOT/.github/actions/mise-toolchain/action.yml"
PREFLIGHT="$REPO_ROOT/lib/dot/preflight.sh"

users_tag="$(sed -n 's/^MISE_TAG="v\([^"]*\)"$/\1/p' "$VERSIONS")"
users_x64="$(sed -n 's/^MISE_SHA256_X86_64="\([0-9a-f]*\)"$/\1/p' "$VERSIONS")"
ci_tag="$(sed -n 's/^ *MISE_VERSION: "\([^"]*\)"$/\1/p' "$ACTION")"
ci_x64="$(sed -n 's/^ *MISE_SHA256_LINUX_X64: \([0-9a-f]*\)$/\1/p' "$ACTION")"
fallback="$(sed -n 's/.*|| tag="v\([^"]*\)".*/\1/p' "$PREFLIGHT")"

test_start "ci_tests_the_mise_users_get"
assert_not_empty "$users_tag" "versions.env pins a mise release"
assert_equals "$users_tag" "$ci_tag" "the CI composite installs the same release"

test_start "same_linux_x64_checksum"
assert_equals "$users_x64" "$ci_x64" "and checks it against the same SHA-256"

test_start "preflight_fallback_is_the_same_pin"
assert_equals "$users_tag" "$fallback" "lib/dot/preflight.sh falls back to that release"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
