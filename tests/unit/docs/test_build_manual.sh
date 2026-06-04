#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT/tools/docs/build-manual.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "build-manual.sh must exist"

test_start "script_valid_syntax"
if bash -n "$SCRIPT_FILE" 2>/dev/null; then
  ((TESTS_PASSED++))
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
else
  ((TESTS_FAILED++))
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST"
fi

test_start "script_uses_pandoc"
assert_file_contains "$SCRIPT_FILE" "pandoc" "must invoke pandoc for format conversion"

test_start "produces_9_formats"
for keyword in dotfiles.html dotfiles.epub dotfiles.txt dotfiles-md.tar.gz SHA256SUMS; do
  assert_file_contains "$SCRIPT_FILE" "$keyword" "must produce $keyword"
done

# Slice 2: drive line coverage. build-manual.sh's no-arg + unknown-flag
# paths both fall through to a full `pandoc` build that writes
# docs/manual/{command,concept}-index.md back to the real repo
# (the script resolves $REPO_ROOT via BASH_SOURCE, bypassing the
# sandbox cwd). Limit ourselves to the --help mode here.
cov_exercise_script_help_only "$SCRIPT_FILE"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
