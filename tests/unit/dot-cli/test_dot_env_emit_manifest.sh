#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2034
# Behavioural coverage for scripts/dot/commands/env-emit.sh (`dot env emit`):
# flag parsing, format validation, dependency checks, the v1 JSON manifest,
# the NDJSON variant and atomic --output writing.
#
# The file only *defines* dot_env_emit, so the suite sources it and calls the
# function. `mise` is a sandbox stub returning a fixed `mise ls --json`
# payload, so the manifest is deterministic and no real toolchain is read.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"
source "$SCRIPT_DIR/../../framework/coverage_helpers.sh"

EMIT="$REPO_ROOT/scripts/dot/commands/env-emit.sh"

trap cov_teardown_sandbox EXIT
cov_setup_sandbox

BIN="$DOTFILES_COV_TMPDIR/bin"
OUTF="$DOTFILES_COV_TMPDIR/emit-out.txt"
ERRF="$DOTFILES_COV_TMPDIR/emit-err.txt"

cat >"$BIN/mise" <<'STUB'
#!/usr/bin/env bash
if [[ "${1:-}" == "ls" ]]; then
  cat "$MISE_LS_FIXTURE"
  exit "${MISE_LS_RC:-0}"
fi
exit 0
STUB
chmod +x "$BIN/mise"
export MISE_LS_FIXTURE="$DOTFILES_COV_TMPDIR/mise-ls.json"
cat >"$MISE_LS_FIXTURE" <<'JSON'
{
  "node": [
    {"version":"24.15.0","requested_version":"24","install_path":"/opt/node/24.15.0","active":true,
     "source":{"type":"tool-versions","path":"/home/u/.tool-versions"}}
  ],
  "rust": [
    {"version":"1.95.0"}
  ]
}
JSON

# emit <args…> — call dot_env_emit in a subshell, report to $OUTF.
emit() {
  (
    source "$EMIT"
    dot_env_emit "$@"
  ) >"$OUTF" 2>"$ERRF" </dev/null
  RC=$?
  # stderr goes to a file and is replayed to ours: redirecting it away would
  # take the child's xtrace with it, losing the coverage of every line the
  # failing path executed.
  [[ "${DOTFILES_COV_ECHO_STDERR:-0}" == "1" ]] && cat "$ERRF" >&2
  return 0
}
out_has() { assert_file_contains "$OUTF" "$1" "${2:-output contains $1}"; }
err_has() { assert_file_contains "$ERRF" "$1" "${2:-stderr contains $1}"; }

test_start "script_exists_and_parses"
assert_file_exists "$EMIT" "env-emit.sh must exist"
assert_true "bash -n '$EMIT'" "valid bash syntax"

test_start "help_documents_the_formats_and_returns_0"
emit --help
assert_equals 0 "$RC" "rc"
out_has "Usage: dot env emit" "usage"
out_has "ndjson" "ndjson documented"

test_start "short_help_flag_works_too"
emit -h
assert_equals 0 "$RC" "rc"
out_has "Usage: dot env emit" "usage"

test_start "unknown_flag_is_rejected"
emit --nope
assert_equals 1 "$RC" "rc"
out_has "unknown flag: --nope" "error"

test_start "unsupported_format_is_rejected"
emit --format yaml
assert_equals 1 "$RC" "rc"
out_has "unsupported format: yaml" "error"

test_start "default_manifest_matches_the_v1_schema_shape"
emit
assert_equals 0 "$RC" "rc"
assert_equals "1.0.0" "$(jq -r .manifest_version <"$OUTF")" "manifest_version"
assert_equals "dot env emit" "$(jq -r .emitter.name <"$OUTF")" "emitter name"
assert_equals "2" "$(jq -r '.tools | length' <"$OUTF")" "one record per installed version"
assert_equals "node" "$(jq -r '.tools[0].name' <"$OUTF")" "tool name"
assert_equals "24.15.0" "$(jq -r '.tools[0].version' <"$OUTF")" "tool version"
assert_equals "/home/u/.tool-versions" "$(jq -r '.tools[0].source' <"$OUTF")" "source path"
assert_equals "orphan" "$(jq -r '.tools[1].source' <"$OUTF")" "sourceless tool is an orphan"
assert_equals "false" "$(jq -r '.tools[1].active' <"$OUTF")" "active defaults to false"
assert_true "[[ -n \$(jq -r .host.hostname <'$OUTF') ]]" "host recorded"

test_start "compact_output_is_one_line"
emit --compact
assert_equals 0 "$RC" "rc"
assert_equals "1" "$(wc -l <"$OUTF" | tr -d ' ')" "single line"
assert_equals "node" "$(jq -r '.tools[0].name' <"$OUTF")" "still valid JSON"

test_start "pretty_is_the_default_and_can_be_asked_for"
emit --pretty
assert_equals 0 "$RC" "rc"
assert_true "[[ \$(wc -l <'$OUTF') -gt 10 ]]" "multi-line"

test_start "ndjson_puts_the_header_first_and_one_tool_per_line"
emit --format ndjson
assert_equals 0 "$RC" "rc"
assert_equals "3" "$(wc -l <"$OUTF" | tr -d ' ')" "header + two tools"
assert_equals "1.0.0" "$(head -1 "$OUTF" | jq -r .manifest_version)" "header line"
assert_equals "node" "$(sed -n 2p "$OUTF" | jq -r .name)" "first tool line"

test_start "format_can_be_given_with_an_equals_sign"
emit --format=ndjson
assert_equals 0 "$RC" "rc"
assert_equals "3" "$(wc -l <"$OUTF" | tr -d ' ')" "same as the spaced form"

test_start "output_flag_writes_the_manifest_atomically"
TARGET="$DOTFILES_COV_TMPDIR/env.json"
emit --output "$TARGET"
assert_equals 0 "$RC" "rc"
assert_file_exists "$TARGET" "manifest written"
assert_equals "2" "$(jq -r '.tools | length' <"$TARGET")" "content is the manifest"
out_has "wrote 2 tools" "summary names the count"
assert_true "! ls '$DOTFILES_COV_TMPDIR'/env.json.?????? >/dev/null 2>&1" "no temp file left behind"

test_start "output_flag_accepts_the_short_and_equals_forms"
emit -o "$TARGET.short"
assert_equals 0 "$RC" "rc"
assert_file_exists "$TARGET.short" "short form"
emit --output="$TARGET.eq"
assert_equals 0 "$RC" "rc"
assert_file_exists "$TARGET.eq" "equals form"

test_start "a_failing_mise_is_reported_as_exit_3"
MISE_LS_RC=1 emit
assert_equals 3 "$RC" "rc"
out_has "mise ls --json failed" "error"

test_start "missing_dependencies_are_reported_as_exit_2"
NODEP="$DOTFILES_COV_TMPDIR/nodep"
mkdir -p "$NODEP"
ln -sf "$(command -v bash)" "$NODEP/bash"
for c in sed grep cat date uname mktemp mv tr cut awk dirname basename printf tty locale realpath readlink head; do
  p="$(command -v "$c" 2>/dev/null)" && ln -sf "$p" "$NODEP/$c"
done
ln -sf "$BIN/mise" "$NODEP/mise"
PATH="$NODEP" emit
assert_equals 2 "$RC" "rc without jq"
out_has "jq required" "error names jq"
rm -f "$NODEP/mise"
ln -sf "$(command -v jq)" "$NODEP/jq"
PATH="$NODEP" emit
assert_equals 2 "$RC" "rc without mise"
out_has "mise required" "error names mise"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
