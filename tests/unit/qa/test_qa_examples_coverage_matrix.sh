#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural tests for scripts/qa/examples-coverage.sh — the contract that
# every feature domain and every public `dot` command ships a runnable
# example.
#
# The script takes REPO_ROOT from the environment, so each case points it at
# a synthetic tree: a stub bin/dot carrying a _dot_help_specs block and an
# examples/ directory the test fills in. Nothing reads the real repository.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT_REAL="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

SCRIPT_FILE="$REPO_ROOT_REAL/scripts/qa/examples-coverage.sh"
REAL_BASH="${BASH:-$(command -v bash)}"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox
WORK="$DOTFILES_COV_TMPDIR/work"
mkdir -p "$WORK"

test_start "script_exists"
assert_file_exists "$SCRIPT_FILE" "scripts/qa/examples-coverage.sh must exist"

_pass() {
  ((TESTS_PASSED++)) || true
  printf '%b\n' "  ${GREEN}✓${NC} $CURRENT_TEST"
}
_fail() {
  ((TESTS_FAILED++)) || true
  printf '%b\n' "  ${RED}✗${NC} $CURRENT_TEST: $1"
}

# The domains the contract requires, mirrored from the script's own list.
REQUIRED_AREAS=(
  ai-patterns cli-utilities coverage-gate diagnostics dot-commands functions
  fleet git-hooks install-uninstall ops platform-contract qa secrets security
  test-suite testing-framework theme
)

# make_tree <name> <public-command…> — a synthetic repo with a bin/dot whose
# help specs name the given commands, and an empty examples/ directory.
make_tree() {
  local name="$1"
  shift
  TREE="$WORK/$name"
  rm -rf "$TREE"
  mkdir -p "$TREE/bin" "$TREE/examples"
  {
    printf '#!/usr/bin/env bash\n_dot_help_specs() {\n'
    printf "  cat <<'EOF'\n"
    local cmd
    for cmd in "$@"; do printf 'Group|%s|Description|Notes\n' "$cmd"; done
    printf 'EOF\n}\n'
  } >"$TREE/bin/dot"
  chmod +x "$TREE/bin/dot"
}
add_domain_examples() {
  local area
  for area in "${REQUIRED_AREAS[@]}"; do
    printf '#!/usr/bin/env bash\n# example\n' >"$TREE/examples/example-$area.sh"
  done
}

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"
# coverage — run the gate against $TREE. Stdout is captured; stderr is
# replayed so the coverage runner keeps its xtrace records.
coverage() {
  local rc=0
  REPO_ROOT="$TREE" "$REAL_BASH" "$SCRIPT_FILE" \
    </dev/null >"$OUT" 2>"$ERR" || rc=$?
  cat "$ERR" >&2
  printf '%s' "$rc"
}

test_start "an_empty_examples_directory_fails_the_contract"
make_tree empty dot-help
rc="$(coverage)"
assert_equals "1" "$rc" "no examples fails"
assert_file_contains "$OUT" "Examples coverage: 0/" "the score starts at zero"
assert_file_contains "$ERR" "FAIL" "the failure is announced on stderr"
assert_file_contains "$ERR" "Missing coverage for" "the missing domains are listed"
assert_file_contains "$ERR" "domain:theme" "each missing domain is named"

test_start "a_complete_matrix_passes"
make_tree complete apply doctor
add_domain_examples
printf 'dot apply\ndot doctor\n' >"$TREE/examples/example-dot-commands.sh"
rc="$(coverage)"
assert_equals "0" "$rc" "a complete matrix passes"
assert_file_contains "$OUT" "(100.00%)" "the score is 100%"
assert_file_contains "$OUT" "PASS" "the pass line is printed"

test_start "a_command_without_an_example_is_reported"
make_tree partial apply doctor fleet
add_domain_examples
printf 'dot apply\ndot doctor\n' >"$TREE/examples/example-dot-commands.sh"
rc="$(coverage)"
assert_equals "1" "$rc" "a missing command fails the contract"
assert_file_contains "$ERR" "cmd:fleet" "the uncovered command is named"
assert_file_contains "$ERR" "FAIL" "the failure is announced on stderr"

test_start "command_matching_does_not_confuse_prefixes"
# `dot ai` must not be considered covered by a reference to `dot ai-query`.
make_tree prefix ai
add_domain_examples
printf 'dot ai-query "how do I?"\n' >"$TREE/examples/example-ai-patterns.sh"
rc="$(coverage)"
assert_equals "1" "$rc" "a prefix match does not count as coverage"
assert_file_contains "$ERR" "cmd:ai" "the command is still reported missing"
printf 'dot ai\n' >>"$TREE/examples/example-ai-patterns.sh"
rc="$(coverage)"
assert_equals "0" "$rc" "an exact reference does count"

test_start "the_threshold_can_be_lowered"
make_tree threshold apply missingcmd
add_domain_examples
printf 'dot apply\n' >"$TREE/examples/example-dot-commands.sh"
rc="$(coverage)"
assert_equals "1" "$rc" "the default 100% threshold fails"
rc=0
REPO_ROOT="$TREE" MIN_EXAMPLES_COVERAGE=50 "$REAL_BASH" "$SCRIPT_FILE" \
  </dev/null >"$OUT" 2>"$ERR" || rc=$?
cat "$ERR" >&2
assert_equals "0" "$rc" "a lower threshold passes"
assert_file_contains "$OUT" "Threshold: 50%" "the configured threshold is reported"

test_start "a_bin_dot_without_help_specs_only_checks_domains"
make_tree nospecs
printf '#!/usr/bin/env bash\necho hi\n' >"$TREE/bin/dot"
add_domain_examples
rc="$(coverage)"
assert_equals "0" "$rc" "domains alone can satisfy the contract"
assert_file_contains "$OUT" "(100.00%)" "the score covers just the domains"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
