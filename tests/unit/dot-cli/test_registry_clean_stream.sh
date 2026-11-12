#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# test-kind: structural
# _registry_clean_stream, the scrub dot cli install pipes every archive
# listing and diff through before printing them. It runs as a pipeline
# element, in a forked subshell. Homebrew's bash 5.3 links GNU libintl, and
# a locale assignment that bash makes itself there, with no LANG set,
# reaches CoreFoundation in the forked child, which crashes now and then
# (SIGSEGV in reset_locale_vars -> libintl_setlocale -> CFPreferences): 13
# of 200 install previews under env -i. The locale is therefore set by env
# for tr, never by bash; the crash is a race no short test reproduces, so
# the structural check pins that.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$REPO_ROOT/lib/dot/ui.sh"
source "$REPO_ROOT/plugins/cli/libexec/registry/registry-trust.sh"
set +e

test_start "control_characters_become_question_marks"
assert_equals $'a?b\tc\nd?e' "$(printf 'a\033b\tc\nd\001e' | _registry_clean_stream)" "C0 and ESC replaced; tab and newline kept"

test_start "bash_sets_no_locale_in_the_forked_subshell"
body="$(declare -f _registry_clean_stream)"
assert_equals "" "$(grep -E '^[[:space:]]*(LC_[A-Z]+|LANG)=' <<<"$body")" "no bash-made locale assignment before tr"
assert_contains "env LC_ALL=C tr" "$body" "env sets the C locale for tr alone"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
