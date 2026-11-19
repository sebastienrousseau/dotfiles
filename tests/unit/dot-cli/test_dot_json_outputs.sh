#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1091
# `dot -V` prints one parseable line and `dot version` keeps the banner
# (D10); `dot version --json`, `dot tool list --json` and `dot config
# profile --json` print one object that validates against its versioned
# schema in schemas/cli (D9, ADR-020 N14); `dot --help` forks no `tr` and
# no `locale` (P13). Sandboxed HOME; mise is a stub.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

BASH_BIN="$(command -v bash)"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/dot-json.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/bin"
cat >"$WORK/bin/mise" <<'EOF'
#!/bin/sh
case "$*" in
  "ls --json") printf '%s\n' '{"node":[{"version":"22.1.0","requested_version":"22","source":{"type":"mise.toml","path":"/x/mise.toml"},"installed":true,"active":true}],"old":[{"version":"1.0","installed":true,"active":false}]}' ;;
esac
EOF
chmod +x "$WORK/bin/mise"

# dot ARGS...: run the CLI in a sandboxed HOME; sets RC and OUT (stdout).
dot() {
  RC=0
  OUT="$(HOME="$WORK" XDG_STATE_HOME="$WORK/state" XDG_CACHE_HOME="$WORK/cache" \
    PATH="$WORK/bin:$PATH" NO_COLOR=1 TERM=dumb "$BASH_BIN" "$REPO_ROOT/bin/dot" "$@" 2>"$WORK/err" </dev/null)" || RC=$?
}

# valid SCHEMA: OUT is one JSON object valid against schemas/cli/SCHEMA.
valid() {
  printf '%s' "$OUT" | python3 -c '
import json, sys
from jsonschema import Draft202012Validator
schema = json.load(open(sys.argv[1]))
doc = json.loads(sys.stdin.read())
errors = [e.message for e in Draft202012Validator(schema).iter_errors(doc)]
print("; ".join(errors) if errors else "valid")' "$REPO_ROOT/schemas/cli/$1" 2>&1
}

test_start "version_flag_is_one_parseable_line"
dot -V
assert_equals "0" "$RC" "dot -V exits 0"
assert_true "[[ '$OUT' =~ ^dot\ [0-9]+\.[0-9]+\.[0-9]+$ ]]" "prints only 'dot <version>'"
want="$OUT"
dot --version
assert_equals "$want" "$OUT" "--version prints the same line"
dot version
assert_contains "Dotfiles Version" "$OUT" "dot version keeps the banner"

if ! python3 -c 'import jsonschema' >/dev/null 2>&1; then
  echo "SKIP: the --json cases need python3 with jsonschema"
else
  test_start "version_json_is_version_v1"
  dot version --json
  assert_equals "0" "$RC" "exits 0"
  assert_equals "valid" "$(valid version.v1.schema.json)" "validates"

  test_start "tool_list_json_is_tool_list_v1"
  dot tool list --json
  assert_equals "0" "$RC" "exits 0"
  assert_equals "valid" "$(valid tool-list.v1.schema.json)" "validates"
  assert_contains '{"name":"node","version":"22.1.0","requested":"22","source":"/x/mise.toml","installed":true,"active":true}' "$OUT" "one entry per version"
  assert_contains '"requested":null,"source":null' "$OUT" "an orphan install has no source"

  test_start "config_profile_json_is_config_profile_v1"
  dot config profile --json
  assert_equals "0" "$RC" "exits 0"
  assert_equals "valid" "$(valid config-profile.v1.schema.json)" "validates"
  assert_contains '"features":{' "$OUT" "with the feature flags"
fi

test_start "help_overview_forks_no_tr_or_locale"
mkdir -p "$WORK/spy"
for tool in tr locale; do
  real="$(command -v "$tool" || echo /usr/bin/false)"
  printf '#!/bin/sh\necho %s >>"%s/spy/calls"\nexec %s "$@"\n' "$tool" "$WORK" "$real" >"$WORK/spy/$tool"
  chmod +x "$WORK/spy/$tool"
done
HOME="$WORK" XDG_CACHE_HOME="$WORK/cache" PATH="$WORK/spy:$PATH" LANG=en_US.UTF-8 \
  "$BASH_BIN" "$REPO_ROOT/bin/dot" --help >"$WORK/help" 2>&1 </dev/null
assert_file_contains "$WORK/help" "TRUST & HOSTS" "the overview prints its upper-case group titles"
assert_equals "" "$(cat "$WORK/spy/calls" 2>/dev/null)" "without forking tr or locale"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
