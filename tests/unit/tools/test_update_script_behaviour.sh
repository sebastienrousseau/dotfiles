#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Copyright (c) 2015-2026 Sebastien Rousseau
# shellcheck disable=SC1090,SC1091,SC2016
# defaults/dot_local/bin/executable_update (`update`) end to end. Every
# package manager it drives, and sudo, is a recording stub, so the tests
# assert what it asked for and never update anything.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
source "$SCRIPT_DIR/../../framework/assertions.sh"

UPDATE="$REPO_ROOT/defaults/dot_local/bin/executable_update"
REAL_BASH="$(command -v bash)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/stub" "$WORK/base"
cat >"$WORK/stub/tool" <<'STUB'
#!/bin/sh
n=$(basename "$0")
echo "$n $*" >>"$CALLS"
case "$n $*" in
  "pip3 list --outdated --format=json") printf '%s\n' "${PIP_JSON:-[]}" ;;
esac
[ "${FAIL:-}" = "$n" ] && { echo "$n failed" >&2; exit 1; }
exit 0
STUB
chmod +x "$WORK/stub/tool"
# Real utilities the script needs; nothing else from the host is on PATH.
for t in basename xargs python3; do ln -s "$(command -v "$t")" "$WORK/base/$t"; done
N=0

# run_update <tools> [FAIL=tool] [PIP_JSON=json] -- [args...]: run `update`
# with only <tools> (comma list) installed. Sets OUT (stdout+stderr), RC
# and CALLS_FILE.
run_update() {
  local tools="$1" fail="" pip="[]" t d
  shift
  while [[ $# -gt 0 && "$1" != "--" ]]; do
    case "$1" in FAIL=*) fail="${1#*=}" ;; PIP_JSON=*) pip="${1#*=}" ;; esac
    shift
  done
  [[ $# -gt 0 ]] && shift
  d="$WORK/c$((++N))"
  mkdir -p "$d/bin"
  for t in ${tools//,/ }; do ln -s "$WORK/stub/tool" "$d/bin/$t"; done
  CALLS_FILE="$d/calls"
  : >"$CALLS_FILE"
  OUT="$(env -i HOME="$d" PATH="$d/bin:$WORK/base" CALLS="$CALLS_FILE" FAIL="$fail" PIP_JSON="$pip" \
    "$REAL_BASH" "$UPDATE" "$@" 2>&1)"
  RC=$?
}
calls() { tr '\n' ';' <"$CALLS_FILE"; }
ALL="brew,apt,sudo,npm,cargo,cargo-install-update,rustup,pip3,chezmoi"

test_start "update_help_prints_usage_and_updates_nothing"
run_update "$ALL" -- --help
assert_equals "0:" "$RC:$(calls)" "--help exits 0 without running a package manager"
assert_contains "update --brew" "$OUT" "usage lists the options"

test_start "update_rejects_an_unknown_option"
run_update "$ALL" -- --dry-run
assert_equals "2:" "$RC:$(calls)" "an unknown option is an error, not a full update"
assert_contains "unknown option: --dry-run" "$OUT" "names the bad option"

echo "RESULTS:$TESTS_RUN:$TESTS_PASSED:$TESTS_FAILED"
