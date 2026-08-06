#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

checker="$REPO_ROOT/tools/ci/check-remote-installers.sh"

test_start "remote_installer_checker_syntax"
if bash -n "$checker"; then ((TESTS_PASSED++)) || true; else ((TESTS_FAILED++)) || true; fi

test_start "remote_installer_policy_passes"
if bash "$checker"; then ((TESTS_PASSED++)) || true; else ((TESTS_FAILED++)) || true; fi

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
