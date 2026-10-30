#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# tools/ci/check-plugin-imports.py, the P2.2 import gate, run against
# fixture plugin trees: a plugin may source the SDK through $DOT_SDK and its
# own files; any other import is an edge, allowed only while baselined.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

GATE="$REPO_ROOT/tools/ci/check-plugin-imports.py"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-plugin-imports.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

# tree NAME LINE...: a fixture root whose one plugin sources each LINE.
tree() {
  local root="$WORK/$1"
  shift
  mkdir -p "$root/plugins/demo/libexec" "$root/tools/ci"
  printf '#!/usr/bin/env bash\n' >"$root/plugins/demo/libexec/demo.sh"
  printf '%s\n' "$@" >>"$root/plugins/demo/libexec/demo.sh"
  printf '%s\n' "$root"
}

# gate ROOT [ARGS]: the gate's output; RC is its exit status.
gate() {
  RC=0
  OUT="$(python3 "$GATE" --root "$@" 2>&1)" || RC=$?
}

test_start "sdk_and_local_imports_pass"
root="$(tree ok 'source "${DOT_SDK:-$SCRIPT_DIR/../../../lib/dot}/sdk.sh"' \
  'source "$DOT_SDK/log.sh"' 'source "$SCRIPT_DIR/demo/part.sh"')"
gate "$root"
assert_equals "0" "$RC" "SDK files through DOT_SDK and the plugin's own files are allowed"
assert_contains "0 edge(s) outside the SDK" "$OUT" "and counted as none"

test_start "a_host_library_is_a_new_edge"
root="$(tree host 'source "$SCRIPT_DIR/../../../lib/dot/ai-roster.sh"')"
gate "$root"
assert_equals "1" "$RC" "sourcing a host library outside the SDK fails"
assert_contains "new edge: plugins/demo/libexec/demo.sh lib/dot/ai-roster.sh" "$OUT" "the edge is named"

test_start "a_non_sdk_file_through_dot_sdk_is_an_edge"
root="$(tree notsdk 'source "${DOT_SDK:-x}/utils.sh"')"
gate "$root"
assert_equals "1" "$RC" "utils.sh is host code, not SDK, even through DOT_SDK"
assert_contains "sdk:utils.sh" "$OUT" "and is named as such"

test_start "a_baselined_edge_passes_and_ratchets"
root="$(tree base 'source "$SCRIPT_DIR/../../../lib/dot/ai-roster.sh"')"
python3 "$GATE" --root "$root" --write-baseline >/dev/null
gate "$root"
assert_equals "0" "$RC" "an edge in the baseline is allowed"
printf '#!/usr/bin/env bash\n' >"$root/plugins/demo/libexec/demo.sh"
gate "$root"
assert_equals "0" "$RC" "removing it still passes"
assert_contains "baselined edge(s) gone: run --write-baseline" "$OUT" "and asks for the ratchet"

test_start "the_repository_has_no_new_edges"
gate "$REPO_ROOT"
assert_equals "0" "$RC" "every plugin import on the tree is SDK, local or baselined"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
